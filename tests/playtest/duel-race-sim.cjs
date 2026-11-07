'use strict';
/*
 * Headless simulation for the real-time shared-deck duel ("race" mode).
 * It models: one open card, first-grab-wins, arbitration window, reveal guard,
 * grab cooldown, two discards per round, tarot timeout, ownerless tarot backs,
 * armor from unused discards, 15s-style round timer and bot reaction times.
 *
 * Run: node tests/playtest/duel-race-sim.cjs
 */

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------- rng
function mulberry32(a) {
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function gauss(rng) {
  let u = 0;
  let v = 0;
  while (u === 0) u = rng();
  while (v === 0) v = rng();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}
function lognormal(rng, median, sigma) {
  return Math.exp(Math.log(median) + sigma * gauss(rng));
}
function pick(rng, arr) {
  return arr[Math.floor(rng() * arr.length)];
}
function shuffle(rng, arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    const t = arr[i];
    arr[i] = arr[j];
    arr[j] = t;
  }
  return arr;
}
function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
}
function round(v) {
  return Math.round(v);
}

// ---------------------------------------------------------------- cards
const RANKS = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
const SUITS = ['\u2660', '\u2665', '\u2666', '\u2663']; // spade heart diamond club

function rankValue(rank) {
  if (rank === 'A') return 11;
  if (rank === 'J' || rank === 'Q' || rank === 'K') return 10;
  return parseInt(rank, 10);
}

function makeNormals() {
  const out = [];
  for (let si = 0; si < 4; si++) {
    for (let ri = 0; ri < 13; ri++) {
      const rank = RANKS[ri];
      out.push({
        id: 'n' + si + '_' + ri,
        kind: 'normal',
        rank,
        suit: SUITS[si],
        value: rankValue(rank),
        red: si === 1 || si === 2,
      });
    }
  }
  return out;
}

// tarot effects (numbers are deliberately simple; information/tempo cards are approximated)
const GOOD_TAROT = [
  { id: 'rose', name: 'Rose', value: 5, apply: (p, z, t, s) => { p.hp = Math.min(p.maxHp, p.hp + 10); s.tarotHp += 10; } },
  { id: 'guardian', name: 'Guardian', value: 5, apply: (p) => { p.roundArmor += 6; } },
  { id: 'sun', name: 'Sun', value: 6, apply: (p, z) => { z.dmgMult *= 1.6; } },
  { id: 'moon', name: 'Moon', value: 5, apply: (p) => { p.incomingMult *= 0.65; } },
  { id: 'scales', name: 'Scales', value: 5, apply: (p, z) => { z.scales = true; } },
  { id: 'clock', name: 'Clock', value: 4, apply: (p, z) => { z.pull = 2; } },
  { id: 'focus', name: 'Focus', value: 3, apply: (p) => { p.discardsLeft += 1; } },
  { id: 'wheel', name: 'Wheel', value: 4, apply: (p) => { p.winTies = true; } },
  { id: 'justice', name: 'Justice', value: 4, apply: (p) => { p.cancelBad = true; } },
  { id: 'candle', name: 'Candle', value: 3, apply: (p) => { p.peek = 3; } },
];
const BAD_TAROT = [
  { id: 'poison', name: 'Poison', value: 5, apply: (p, z, t, s) => { p.hp = Math.max(0, p.hp - 5); s.tarotHp -= 5; } },
  { id: 'rust', name: 'Rust', value: 4, apply: (p, z) => { z.dmgMult *= 0.75; } },
  { id: 'chain', name: 'Chain', value: 4, apply: (p, z) => { z.zero = true; } },
  { id: 'load', name: 'Load', value: 3, apply: (p, z) => { z.bonusSum += 4; } },
  { id: 'tower', name: 'Tower', value: 5, apply: (p, z, t, s) => { const kept = z.cards.filter((c) => c.kind === 'tarot'); for (const c of z.cards) if (c.kind === 'normal') s.discard.push(c); z.cards = kept; z.bonusSum = 0; } },
  { id: 'death', name: 'Death', value: 5, apply: (p, z) => { z.zero = true; } },
  { id: 'thief', name: 'Thief', value: 3, apply: (p) => { p.discardsLeft = Math.max(0, p.discardsLeft - 1); } },
  { id: 'hanged', name: 'Hanged', value: 3, apply: (p, z, t) => { p.stunUntil = Math.max(p.stunUntil, t + 1.5); } },
  { id: 'darkening', name: 'Darkening', value: 3, apply: (p, z, t, s) => { s.hidden += 3; } },
  { id: 'jester', name: 'Jester', value: 3, apply: (p, z, t, s) => { s.forceOpponentNext = p.id; } },
];

function buildDeck(cfg, rng) {
  const normals = makeNormals();
  const good = shuffle(rng, GOOD_TAROT.slice()).slice(0, cfg.goodPerPlayer * 2);
  const bad = shuffle(rng, BAD_TAROT.slice()).slice(0, cfg.badPerPlayer * 2);
  const tarot = [];
  for (const d of good) tarot.push({ id: 't_' + d.id, kind: 'tarot', tarot: d, value: 0, rank: d.name, suit: '', red: false });
  for (const d of bad) tarot.push({ id: 't_' + d.id, kind: 'tarot', tarot: d, value: 0, rank: d.name, suit: '', red: false });
  return { deck: shuffle(rng, normals.concat(tarot)), tarotCount: tarot.length };
}

// ---------------------------------------------------------------- zones
function emptyZone() {
  return { cards: [], stood: false, bonusSum: 0, dmgMult: 1, zero: false, pull: 0, scales: false };
}

function evalZone(zone, target) {
  const normals = zone.cards.filter((c) => c.kind === 'normal');
  if (normals.length === 0) {
    return { sum: 0, damage: 0, exact: false, bust: false, heal: 0, colorBonus: 0, critical: false, regular: 0, black: false, red: false };
  }
  let raw = zone.bonusSum;
  let aces = 0;
  let kings = 0;
  let allRed = true;
  let allBlack = true;
  for (const c of normals) {
    raw += c.value;
    if (c.rank === 'A') aces++;
    if (c.rank === 'K') kings++;
    if (!c.red) allRed = false;
    if (c.red) allBlack = false;
  }
  let best = null;
  for (let low = 0; low <= aces; low++) {
    let sum = raw - 10 * low;
    if (zone.pull && Math.abs(sum - target) <= zone.pull) sum = target;
    const bust = sum > target && kings < 3;
    const dist = Math.abs(target - sum);
    const cand = { sum, bust, dist };
    if (!best) best = cand;
    else {
      const better = (!bust && best.bust) ||
        (bust === best.bust && ((!bust && dist < best.dist) || (bust && sum < best.sum)));
      if (better) best = cand;
    }
  }
  const regular = normals.length;
  const exact = !best.bust && best.sum === target;
  const critical = aces >= 3;
  let colorBonus = 0;
  if (!best.bust && regular >= 3 && allBlack) colorBonus = regular >= 4 ? 15 : 10;
  const heal = !best.bust && regular >= 3 && allRed ? (regular >= 4 ? 15 : 10) : 0;
  return {
    sum: best.sum, damage: 0, exact, bust: best.bust, heal, colorBonus, critical, regular,
    black: allBlack && regular > 0, red: allRed && regular > 0,
  };
}

function duelDamage(zone, target) {
  if (zone.zero) return 0;
  const r = evalZone(zone, target);
  if (r.regular === 0 || r.bust) return 0;
  const d = Math.abs(target - r.sum);
  let dmg = d === 0 ? 8 : d === 1 ? 6 : d === 2 ? 5 : d === 3 ? 4 : d <= 5 ? 3 : d <= 9 ? 2 : 1;
  if (r.critical) dmg *= 2;
  if (r.colorBonus > 0) dmg = round(dmg * (1 + r.colorBonus / 100));
  return dmg;
}

function activeZone(player, target, slots) {
  for (let i = 0; i < player.zones.length; i++) {
    const z = player.zones[i];
    if (z.stood || z.zero) continue;
    if (z.cards.length >= slots) continue;
    const r = evalZone(z, target);
    if (r.bust || r.exact) continue;
    return i;
  }
  return -1;
}

function zoneFits(player, target, slots, card, zi) {
  const z = player.zones[zi];
  if (!z || z.stood || z.zero) return false;
  if (z.cards.length >= slots) return false;
  const r = evalZone(z, target);
  if (r.bust || r.exact) return false;
  if (card.kind === 'tarot') return true;
  const trial = { ...z, cards: z.cards.concat([card]) };
  const after = evalZone(trial, target);
  return !after.bust;
}

// ---------------------------------------------------------------- players
function newPlayer(id, bot) {
  return {
    id,
    hp: 0,
    maxHp: 0,
    bot,
    loadout: { class: 'sharp', jokers: [] },
    zones: [emptyZone(), emptyZone(), emptyZone()],
    discardsLeft: 0,
    discardsUsed: 0,
    discardReadyAt: 0,
    grabReadyAt: 0,
    stunUntil: 0,
    incomingMult: 1,
    roundArmor: 0,
    winTies: false,
    cancelBad: false,
    peek: 0,
    round: null,
  };
}

function newRoundStats() {
  return { cards: 0, tarot: 0, good: 0, bad: 0, discards: 0, armor: 0, busts: 0, zones2: 0, scored: 0, fills: 0, timeouts: 0 };
}

// ---------------------------------------------------------------- decisions
function reactionTime(rng, player, card, state) {
  let r = lognormal(rng, player.bot.reaction, player.bot.sigma);
  if (card && card.kind === 'tarot') r += 0.1;
  if (state.hidden > 0) r += 0.2;
  if (player.peek > 0) r -= 0.08;
  return clamp(r, 0.1, 2.2);
}

function tarotEV(player, state, zone, cfg) {
  const b = state.belief;
  const total = b.good + b.bad;
  const pGood = total > 0 ? b.good / total : 0.5;
  const goodAvg = 4.8;
  const badAvg = 3.6;
  const ordinary = zone ? zone.cards.filter((c) => c.kind === 'normal').length : 0;
  const slotCost = ordinary >= 3 ? 0.5 : ordinary >= 2 ? 1.5 : 2.8;
  let ev = pGood * goodAvg - (1 - pGood) * badAvg - slotCost;
  if (player.cancelBad) ev += (1 - pGood) * badAvg * 0.8;
  return ev;
}

function decideAction(state, player, opponent, card, revealTime, now, cfg, rng) {
  const target = state.target;
  const slots = cfg.slots;
  const zi = activeZone(player, target, slots);
  const zone = zi >= 0 ? player.zones[zi] : null;
  const timeLeft = cfg.roundSeconds - now;
  const elapsed = now - revealTime;
  const urgent = timeLeft < 3;
  const actions = [];

  // pass is always available and worth zero
  actions.push({ type: 'pass', value: 0, time: Infinity });

  // take, only into the active zone
  let takeValue = -Infinity;
  if (zone) {
    if (card.kind === 'tarot') {
      takeValue = tarotEV(player, state, zone, cfg);
      if (urgent) takeValue += 0.8;
      if (elapsed > 1.5) takeValue += 1.5; // do not let a closed tarot stall the whole round
    } else {
      const before = duelDamage(zone, target);
      const trial = { ...zone, cards: zone.cards.concat([card]) };
      const r = evalZone(trial, target);
      if (r.bust) takeValue = -10;
      else {
        const after = duelDamage(trial, target);
        takeValue = after - before;
        if (zone.cards.filter((c) => c.kind === 'normal').length === 0) takeValue += 1.5;
        takeValue += round(r.heal * 0.2) * 0.2;
        if (urgent && zone.cards.length < 2) takeValue += 1.2;
        // a card that nobody takes becomes more attractive with age
        if (elapsed > 1.2) takeValue += 2.5;
        if (elapsed > 2.2) takeValue += 2.5;
      }
    }
    takeValue += gauss(rng) * (1 - player.bot.quality) * 2.5;
    const base = Math.max(revealTime, player.grabReadyAt, player.stunUntil);
    actions.push({ type: 'take', value: takeValue, time: base + reactionTime(rng, player, card, state) });
  }

  // stand: lock a decent zone when this card is bad, or move to a zone that fits the card
  if (zone && zone.cards.length > 0) {
    const normals = zone.cards.filter((c) => c.kind === 'normal').length;
    const currentDamage = duelDamage(zone, target);
    let standValue = -Infinity;
    if (normals >= 2 && currentDamage >= 4 && takeValue < 0) {
      standValue = 1.0 + (urgent ? 0.8 : 0);
    }
    // never abandon a one-card zone: it still has room, wait for a card that fits
    if (normals >= 2 && currentDamage >= 3) {
      let bestOther = -Infinity;
      for (let i = 0; i < player.zones.length; i++) {
        if (i === zi) continue;
        if (!zoneFits(player, target, slots, card, i)) continue;
        const z = player.zones[i];
        if (card.kind === 'tarot') {
          bestOther = Math.max(bestOther, tarotEV(player, state, z, cfg));
        } else {
          const before = duelDamage(z, target);
          const trial = { ...z, cards: z.cards.concat([card]) };
          bestOther = Math.max(bestOther, duelDamage(trial, target) - before);
        }
      }
      if (bestOther > -Infinity) standValue = Math.max(standValue, bestOther - Math.max(0, takeValue) + 0.4);
    }
    if (standValue > 0.3) {
      actions.push({ type: 'stand', value: standValue, time: Math.max(revealTime, player.stunUntil) + 0.12 });
    }
  }

  // discard: denial or skipping a card we do not want
  if (player.discardsLeft > 0 && revealTime >= cfg.guard && revealTime >= player.discardReadyAt && player.stunUntil <= revealTime) {
    let discardValue = -Infinity;
    if (card.kind === 'tarot') {
      discardValue = -takeValue - 0.8 + (urgent ? 0.8 : 0);
    } else {
      let oppGain = 0;
      const oi = activeZone(opponent, target, slots);
      if (oi >= 0) {
        const oz = opponent.zones[oi];
        const before = duelDamage(oz, target);
        const trial = { ...oz, cards: oz.cards.concat([card]) };
        const after = duelDamage(trial, target);
        if (!evalZone(trial, target).bust) oppGain = Math.max(0, after - before);
      }
      const armorCost = cfg.armorPerDiscard;
      if (takeValue < 1) discardValue = oppGain * 0.8 - armorCost - 0.4;
      if (opponent.grabReadyAt > revealTime && urgent) discardValue += 0.5;
    }
    if (discardValue > 0.2) {
      const base = Math.max(revealTime + cfg.guard, player.discardReadyAt, player.stunUntil);
      actions.push({ type: 'discard', value: discardValue, time: base + reactionTime(rng, player, card, state) * 0.85 });
    }
  }

  // weak bots sometimes pick a random feasible action
  if (rng() < (1 - player.bot.quality) * 0.18) {
    const feasible = actions.filter((a) => a.type !== 'pass');
    if (feasible.length > 0) {
      const chosen = pick(rng, feasible);
      return { ...chosen, value: chosen.value + 100 };
    }
  }
  actions.sort((a, b) => b.value - a.value);
  return actions[0];
}

// ---------------------------------------------------------------- round
function drawCard(state) {
  if (state.deck.length === 0) {
    state.deck = shuffle(state.rng, state.discard);
    state.discard = [];
  }
  if (state.deck.length === 0) return null;
  const card = state.deck.pop();
  if (card.kind === 'tarot') state.totals.tarotSeen++;
  return card;
}

function playRound(state, cfg) {
  const target = state.target;
  const players = state.players;
  for (const p of players) {
    p.zones = [emptyZone(), emptyZone(), emptyZone()];
    p.discardsLeft = cfg.discards;
    p.discardsUsed = 0;
    p.discardReadyAt = 0;
    p.grabReadyAt = 0;
    p.stunUntil = 0;
    p.incomingMult = 1;
    p.roundArmor = 0;
    p.winTies = false;
    p.cancelBad = false;
    p.peek = 0;
    p.round = newRoundStats();
  }
  state.hidden = 0;
  state.forceOpponentNext = null;

  let t = 0;
  let revealTime = 0;
  let card = drawCard(state);
  if (!card) return;
  state.revealAt = 0;
  let guard = 0;

  while (t < cfg.roundSeconds && guard++ < 4000) {
    if (activeZone(players[0], target, cfg.slots) < 0 && activeZone(players[1], target, cfg.slots) < 0) break;
    if (!card) break;

    // tarot timeout: unclaimed closed tarot goes to discard face down
    if (card.kind === 'tarot' && t >= revealTime + cfg.tarotTimeout) {
      state.discard.push(card);
      state.totals.tarotTimeout++;
      t += cfg.revealDelay;
      card = drawCard(state);
      revealTime = t;
      continue;
    }

    // jester: next card is auto-taken by the chosen opponent
    if (state.forceOpponentNext && t >= revealTime + 0.25) {
      const victim = players.find((p) => p.id !== state.forceOpponentNext);
      const zi = activeZone(victim, target, cfg.slots);
      state.forceOpponentNext = null;
      if (zi >= 0) {
        applyTake(state, victim, zi, card, t, cfg);
      } else {
        state.discard.push(card);
      }
      t += cfg.revealDelay;
      card = drawCard(state);
      revealTime = t;
      continue;
    }

    const acts = [];
    for (let i = 0; i < 2; i++) {
      const p = players[i];
      const a = decideAction(state, p, players[1 - i], card, revealTime, t, cfg, state.rng);
      acts.push({ player: i, ...a });
    }
    const takes = acts.filter((a) => a.type === 'take');
    const discards = acts.filter((a) => a.type === 'discard');
    const stands = acts.filter((a) => a.type === 'stand');

    // earliest take/discard
    const contest = takes.concat(discards).sort((a, b) => a.time - b.time)[0];
    if (!contest) {
      // both passed
      if (card.kind === 'tarot') {
        t = Math.min(revealTime + cfg.tarotTimeout, cfg.roundSeconds);
        continue;
      }
      // normal card: give the bots time to lower their threshold, then
      // discard it unclaimed so the deck keeps moving (no discard spent)
      if (t < revealTime + 1.2) {
        t = Math.min(revealTime + 1.2, cfg.roundSeconds);
        continue;
      }
      if (t < revealTime + 2.2) {
        t = Math.min(revealTime + 2.2, cfg.roundSeconds);
        continue;
      }
      state.discard.push(card);
      if (card.kind === 'tarot') state.totals.tarotDiscarded++;
      t += cfg.revealDelay;
      card = drawCard(state);
      revealTime = t;
      continue;
    }

    // a tarot that nobody reaches before its timeout is destroyed unread
    if (card.kind === 'tarot' && contest.time > revealTime + cfg.tarotTimeout) {
      state.discard.push(card);
      state.totals.tarotTimeout++;
      t = revealTime + cfg.tarotTimeout + cfg.revealDelay;
      card = drawCard(state);
      revealTime = t;
      continue;
    }

    // stands happen independently before the contest if they are earlier
    const earlyStands = stands.filter((s) => s.time <= contest.time);
    let stood = false;
    for (const s of earlyStands) {
      const standZi = activeZone(players[s.player], target, cfg.slots);
      if (standZi >= 0) {
        players[s.player].zones[standZi].stood = true;
        t = Math.max(t, s.time);
        stood = true;
      }
    }
    if (stood) continue;

    if (contest.type === 'take') {
      // both taking: arbitration window, random winner unless one has Wheel
      let winner;
      if (takes.length === 2) {
        const diff = Math.abs(takes[0].time - takes[1].time);
        if (diff <= cfg.arbWindow) {
          const p0 = players[takes[0].player];
          const p1 = players[takes[1].player];
          if (p0.winTies && !p1.winTies) winner = takes[0].player;
          else if (p1.winTies && !p0.winTies) winner = takes[1].player;
          else winner = state.rng() < 0.5 ? takes[0].player : takes[1].player;
        } else {
          winner = takes[0].time < takes[1].time ? takes[0].player : takes[1].player;
        }
        t = Math.max(t, Math.min(takes[0].time, takes[1].time));
      } else {
        winner = takes[0].player;
        t = Math.max(t, takes[0].time);
      }
      const zi = activeZone(players[winner], target, cfg.slots);
      if (zi >= 0) applyTake(state, players[winner], zi, card, t, cfg);
      else {
        state.discard.push(card);
        if (card.kind === 'tarot') state.totals.tarotDiscarded++;
      }
      t += cfg.revealDelay;
      card = drawCard(state);
      revealTime = t;
      continue;
    }

    // discard wins the race
    const who = players[contest.player];
    who.discardsLeft = Math.max(0, who.discardsLeft - 1);
    who.discardsUsed++;
    who.round.discards++;
    who.discardReadyAt = Math.max(t, contest.time) + cfg.discardCooldown;
    state.discard.push(card); // face down; identity is not revealed
    if (card.kind === 'tarot') state.totals.tarotDiscarded++;
    t = Math.max(t, contest.time) + cfg.revealDelay;
    card = drawCard(state);
    revealTime = t;
  }

  if (card) state.discard.push(card);
  state.roundTime = Math.min(t, cfg.roundSeconds);
}

function applyTake(state, player, zi, card, t, cfg) {
  const zone = player.zones[zi];
  zone.cards.push(card);
  player.grabReadyAt = t + cfg.grabCooldown;
  player.round.cards++;
  if (card.kind === 'tarot') {
    player.round.tarot++;
    state.totals.tarotTaken++;
    const isGood = GOOD_TAROT.includes(card.tarot);
    if (isGood) {
      if (state.belief.good > 0) state.belief.good--;
      player.round.good++;
    } else {
      if (state.belief.bad > 0) state.belief.bad--;
      player.round.bad++;
    }
    if (player.cancelBad && !isGood) {
      player.cancelBad = false;
    } else {
      card.tarot.apply(player, zone, t, state);
    }
  }
}

// ---------------------------------------------------------------- resolve
function evaluatePlayer(player, target, cfg) {
  let damage = 0;
  let heal = 0;
  let armor = 0;
  let busts = 0;
  let redZones = 0;
  let blackZones = 0;
  let cards = 0;
  const sums = [];
  const valid = [];
  for (const z of player.zones) {
    const r = evalZone(z, target);
    let dmg = duelDamage(z, target);
    if (!r.bust && r.regular > 0) {
      if (player.loadout.class === 'sharp' && r.exact) dmg += 1;
      if (player.loadout.jokers.includes('triple') && r.regular === 3) dmg += 1;
      if (player.loadout.jokers.includes('blot') && r.black) dmg += 1;
      if (z.scales && r.exact) dmg = round(dmg * 1.5);
      dmg = round(dmg * z.dmgMult);
    } else if (r.bust) {
      dmg = 0;
    } else {
      dmg = 0;
    }
    if (r.bust) busts++;
    damage += Math.max(0, dmg);
    if (r.red) redZones++;
    if (r.black) blackZones++;
    if (!r.bust && r.regular > 0) {
      sums.push(r.sum);
      valid.push(r.sum);
    }
    cards += z.cards.length;
    heal += round(r.heal * cfg.healScale);
  }
  if (player.loadout.class === 'healer') heal += Math.min(3, redZones);
  if (player.loadout.jokers.includes('crimson')) heal += Math.min(3, redZones);
  if (player.loadout.class === 'guardian' && busts === 0 && cards > 0) armor += 2;

  let bonus = 0;
  if (player.loadout.jokers.includes('tandem')) {
    const counts = {};
    for (const s of sums) counts[s] = (counts[s] || 0) + 1;
    if (Object.values(counts).some((v) => v >= 2)) bonus += 2;
  }
  if (player.loadout.jokers.includes('ladder') && valid.length >= 3) {
    const uniq = [...new Set(valid)].sort((a, b) => a - b);
    for (let i = 0; i + 2 < uniq.length; i++) {
      if (uniq[i + 1] === uniq[i] + 1 && uniq[i + 2] === uniq[i + 1] + 1) {
        bonus += 3;
        break;
      }
    }
  }
  damage += bonus;
  return { damage, heal, armor, busts, redZones, blackZones, cards, sums, valid };
}

function resolveRound(state, cfg) {
  const players = state.players;
  const evals = players.map((p) => evaluatePlayer(p, state.target, cfg));
  const sudden = state.round >= cfg.suddenDeathRound ? cfg.suddenDeathMult : 1;
  const preHp = players.map((p) => p.hp);

  // armor: unused discards + tarot guardian + class guardian
  const armors = players.map((p, i) => {
    const discardArmor = Math.min(cfg.armorCap, Math.max(0, p.discardsLeft) * cfg.armorPerDiscard);
    return Math.min(12, discardArmor + p.roundArmor + evals[i].armor);
  });

  const damages = players.map((p, i) => {
    const incoming = round(evals[1 - i].damage * p.incomingMult * sudden);
    return incoming;
  });

  const newHp = [0, 0];
  for (let i = 0; i < 2; i++) {
    const p = players[i];
    const heal = evals[i].heal + 0; // rose is applied immediately, this is red/healer/crimson
    const incoming = damages[i];
    const absorbed = Math.min(incoming, armors[i]);
    const hpAfterHeal = Math.min(p.maxHp, p.hp + heal);
    newHp[i] = Math.max(0, hpAfterHeal - (incoming - absorbed));

    // metrics
    p.round.armor = armors[i];
    p.round.busts = evals[i].busts;
    p.round.zones2 = p.zones.filter((z) => z.cards.filter((c) => c.kind === 'normal').length >= 2).length;
    p.round.fills = p.zones.filter((z) => z.cards.filter((c) => c.kind === 'normal').length >= 3).length;
    p.round.scored = p.zones.filter((z) => duelDamage(z, state.target) > 0).length;
    p.lastDamage = evals[i].damage;
    p.lastHeal = heal;
    p.lastIncoming = incoming;
    state.totals.damage += evals[i].damage;
    state.totals.heal += heal;
    state.totals.armor += absorbed;
  }
  for (let i = 0; i < 2; i++) players[i].hp = newHp[i];

  // simultaneous knockout: the player who entered the round with more HP wins
  if (newHp[0] <= 0 && newHp[1] <= 0 && cfg.tiebreak !== false) {
    if (preHp[0] > preHp[1]) state.winnerOverride = 0;
    else if (preHp[1] > preHp[0]) state.winnerOverride = 1;
    else state.winnerOverride = -1;
  }
  state.totals.roundTime += state.roundTime || 0;
  state.totals.rounds++;
  if (players.some((p) => p.round.zones2 < 2)) state.totals.lowRounds++;
  for (const p of players) {
    state.totals.cards += p.round.cards;
    state.totals.tarot += p.round.tarot;
    state.totals.good += p.round.good;
    state.totals.bad += p.round.bad;
    state.totals.discards += p.round.discards;
    state.totals.timeouts += p.round.timeouts;
    state.totals.zones2 += p.round.zones2;
    state.totals.scored += p.round.scored;
    state.totals.busts += p.round.busts;
  }
}

// ---------------------------------------------------------------- game
function simulateGame(cfg, botA, botB, seed) {
  const rng = mulberry32(seed);
  const { deck } = buildDeck(cfg, rng);
  const state = {
    cfg, rng, deck, discard: [],
    belief: { good: cfg.goodPerPlayer * 2, bad: cfg.badPerPlayer * 2 },
    hidden: 0, forceOpponentNext: null,
    round: 1, target: cfg.targetBase,
    winnerOverride: null,
    players: [newPlayer('A', botA), newPlayer('B', botB)],
    totals: { cards: 0, tarot: 0, good: 0, bad: 0, discards: 0, armor: 0, timeouts: 0, zones2: 0, scored: 0, busts: 0, damage: 0, heal: 0, roundTime: 0, rounds: 0, lowRounds: 0, tarotSeen: 0, tarotTaken: 0, tarotDiscarded: 0, tarotTimeout: 0 },
    tarotHp: 0,
  };
  state.players[0].hp = cfg.hp;
  state.players[0].maxHp = cfg.hp;
  state.players[1].hp = cfg.hp;
  state.players[1].maxHp = cfg.hp;

  // mirrored loadouts keep the skill test clean
  const classes = ['sharp', 'healer', 'guardian'];
  const jokerPool = ['crimson', 'blot', 'triple', 'tandem', 'ladder'];
  const cls = pick(rng, classes);
  const jokers = shuffle(rng, jokerPool.slice()).slice(0, 2);
  for (const p of state.players) p.loadout = { class: cls, jokers };

  let round = 0;
  while (round < cfg.maxRounds) {
    round++;
    state.round = round;
    state.target = Math.min(cfg.targetCap, cfg.targetBase + round - 1);
    playRound(state, cfg);
    resolveRound(state, cfg);
    if (state.players[0].hp <= 0 || state.players[1].hp <= 0) break;
    if (round >= cfg.maxRounds) break;
    for (const p of state.players) {
      for (const z of p.zones) {
        state.discard.push(...z.cards);
        z.cards = [];
      }
    }
  }

  let result = 'draw';
  if (state.winnerOverride === 0) result = 'A';
  else if (state.winnerOverride === 1) result = 'B';
  else if (state.winnerOverride === -1) result = 'draw';
  else if (state.players[0].hp > state.players[1].hp) result = 'A';
  else if (state.players[1].hp > state.players[0].hp) result = 'B';
  return { result, rounds: round, hp: [state.players[0].hp, state.players[1].hp], totals: state.totals, tarotHp: state.tarotHp };
}

// ---------------------------------------------------------------- batch
function runBatch(cfg, botA, botB, games, seed0) {
  const agg = {
    games, winsA: 0, winsB: 0, draws: 0,
    rounds: 0, cards: 0, tarot: 0, good: 0, bad: 0, discards: 0, timeouts: 0,
    tarotSeen: 0, tarotTaken: 0, tarotDiscarded: 0, tarotTimeout: 0,
    zones2: 0, scored: 0, busts: 0, armor: 0, damage: 0, heal: 0, roundTime: 0, roundsSeen: 0,
    lowRounds: 0,
    hpDiff: 0,
  };
  for (let g = 0; g < games; g++) {
    const r = simulateGame(cfg, botA, botB, seed0 + g * 7919);
    if (r.result === 'A') agg.winsA++;
    else if (r.result === 'B') agg.winsB++;
    else agg.draws++;
    agg.rounds += r.rounds;
    agg.hpDiff += r.hp[0] - r.hp[1];
    const t = r.totals;
    agg.cards += t.cards;
    agg.tarot += t.tarot;
    agg.good += t.good;
    agg.bad += t.bad;
    agg.discards += t.discards;
    agg.timeouts += t.timeouts;
    agg.tarotSeen += t.tarotSeen;
    agg.tarotTaken += t.tarotTaken;
    agg.tarotDiscarded += t.tarotDiscarded;
    agg.tarotTimeout += t.tarotTimeout;
    agg.zones2 += t.zones2;
    agg.scored += t.scored;
    agg.busts += t.busts;
    agg.armor += t.armor;
    agg.damage += t.damage;
    agg.heal += t.heal;
    agg.roundTime += t.roundTime;
    agg.roundsSeen += t.rounds;
    agg.lowRounds += t.lowRounds;
  }
  const roundsSeen = agg.roundsSeen || 1;
  const gamesSeen = games || 1;
  return {
    games,
    winrateA: agg.winsA / games,
    winrateB: agg.winsB / games,
    draws: agg.draws / games,
    avgRounds: agg.rounds / gamesSeen,
    avgCardsPerRound: agg.cards / roundsSeen / 2,
    avgZones2: agg.zones2 / roundsSeen,
    avgScored: agg.scored / roundsSeen,
    lowRoundShare: agg.lowRounds / roundsSeen,
    avgTarotPerRound: agg.tarot / roundsSeen / 2,
    tarotTakeRate: agg.tarotSeen > 0 ? agg.tarotTaken / agg.tarotSeen : 0,
    tarotDiscardRate: agg.tarotSeen > 0 ? agg.tarotDiscarded / agg.tarotSeen : 0,
    tarotTimeoutRate: agg.tarotSeen > 0 ? agg.tarotTimeout / agg.tarotSeen : 0,
    tarotGoodShare: agg.tarot > 0 ? agg.good / agg.tarot : 0,
    avgDiscardsPerRound: agg.discards / roundsSeen / 2,
    avgTimeoutsPerRound: agg.tarotTimeout / roundsSeen,
    avgArmorPerRound: agg.armor / roundsSeen,
    avgDamagePerRound: agg.damage / roundsSeen / 2,
    avgHealPerRound: agg.heal / roundsSeen / 2,
    avgRoundTime: agg.roundTime / roundsSeen,
    avgBustsPerPlayerRound: agg.busts / roundsSeen / 2,
    avgHpDiff: agg.hpDiff / gamesSeen,
    agg,
  };
}

// ---------------------------------------------------------------- bots
const STRONG = { name: 'strong', reaction: 0.42, sigma: 0.25, quality: 0.90 };
const WEAK = { name: 'weak', reaction: 0.50, sigma: 0.30, quality: 0.50 };
const MID = { name: 'mid', reaction: 0.46, sigma: 0.28, quality: 0.72 };

const BASE = {
  roundSeconds: 20,
  slots: 4,
  zones: 3,
  targetBase: 21,
  targetStep: 1,
  targetCap: 30,
  hp: 100,
  guard: 0.4,
  arbWindow: 0.18,
  grabCooldown: 0.6,
  discards: 2,
  discardCooldown: 0.8,
  tarotTimeout: 1.5,
  armorPerDiscard: 2,
  armorCap: 4,
  suddenDeathRound: 8,
  suddenDeathMult: 1.5,
  tiebreak: true,
  goodPerPlayer: 2,
  badPerPlayer: 2,
  healScale: 0.2,
  revealDelay: 0.15,
  maxRounds: 24,
};

function fmt(x, d = 2) {
  return Number(x).toFixed(d);
}

function printRow(label, r) {
  const pct = (v) => (v * 100).toFixed(1) + '%';
  console.log(
    [
      label.padEnd(28),
      ('WR ' + pct(r.winrateA)).padEnd(12),
      ('rounds ' + fmt(r.avgRounds, 1)).padEnd(14),
      ('z2 ' + fmt(r.avgZones2, 2)).padEnd(10),
      ('low ' + pct(r.lowRoundShare)).padEnd(12),
      ('cards ' + fmt(r.avgCardsPerRound, 1)).padEnd(13),
      ('hpDiff ' + fmt(r.avgHpDiff, 1)),
    ].join(' ')
  );
  console.log(
    [
      ''.padEnd(28),
      ('tarot ' + r.agg.tarotTaken + '/' + r.agg.tarotSeen).padEnd(16),
      ('T ' + pct(r.tarotTakeRate) + ' D ' + pct(r.tarotDiscardRate) + ' X ' + pct(r.tarotTimeoutRate)).padEnd(34),
      ('disc ' + fmt(r.avgDiscardsPerRound, 2)).padEnd(11),
      ('armor ' + fmt(r.avgArmorPerRound, 1)).padEnd(13),
      ('time ' + fmt(r.avgRoundTime, 1) + 's'),
    ].join(' ')
  );
}

function sweepRoundSeconds(games = 1600) {
  console.log('\n=== round length sweep (strong vs weak, 2+2 tarot, 1.5s timeout, 0.6s grab cd, armor 2, hp 100) ===');
  const rows = [];
  for (const seconds of [15, 16, 18, 20, 22, 25]) {
    const cfg = { ...BASE, roundSeconds: seconds };
    const r = runBatch(cfg, STRONG, WEAK, games, 1000);
    rows.push({ seconds, ...r });
    printRow(seconds + 's', r);
  }
  return rows;
}

function sweepArmor(games = 1400) {
  console.log('\n=== armor per unused discard (20s) ===');
  const rows = [];
  for (const armor of [1, 2, 3, 4]) {
    const cfg = { ...BASE, armorPerDiscard: armor };
    const r = runBatch(cfg, STRONG, WEAK, games, 2000);
    rows.push({ armor, ...r });
    printRow('armor ' + armor, r);
  }
  return rows;
}

function sweepTarot(games = 1400) {
  console.log('\n=== tarot count (20s) ===');
  const rows = [];
  for (const n of [1, 2, 3]) {
    const cfg = { ...BASE, goodPerPlayer: n, badPerPlayer: n };
    const r = runBatch(cfg, STRONG, WEAK, games, 3000);
    rows.push({ n, ...r });
    printRow(n + '+' + n, r);
  }
  return rows;
}

function sweepTimeout(games = 1400) {
  console.log('\n=== tarot timeout (20s) ===');
  const rows = [];
  for (const timeout of [1.0, 1.5, 2.0, 4.0]) {
    const cfg = { ...BASE, tarotTimeout: timeout };
    const r = runBatch(cfg, STRONG, WEAK, games, 4000);
    rows.push({ timeout, ...r });
    printRow(timeout + 's', r);
  }
  return rows;
}

function sweepGrabCooldown(games = 1400) {
  console.log('\n=== grab cooldown (20s) ===');
  const rows = [];
  for (const cd of [0, 0.3, 0.6, 0.9, 1.2]) {
    const cfg = { ...BASE, grabCooldown: cd };
    const r = runBatch(cfg, STRONG, WEAK, games, 5000);
    rows.push({ cd, ...r });
    printRow('cd ' + cd + 's', r);
  }
  return rows;
}

function sanity(games = 1400) {
  console.log('\n=== sanity: mirror matches (20s) ===');
  const rows = [];
  const cfg = { ...BASE };
  const pairs = [
    ['strong vs strong', STRONG, STRONG],
    ['weak vs weak', WEAK, WEAK],
    ['strong vs mid', STRONG, MID],
    ['mid vs weak', MID, WEAK],
  ];
  for (const [label, a, b] of pairs) {
    const r = runBatch(cfg, a, b, games, 6000);
    rows.push({ label, ...r });
    printRow(label, r);
  }
  return rows;
}

function main() {
  const out = {
    base: BASE,
    roundSeconds: sweepRoundSeconds(1600),
    armor: sweepArmor(1400),
    tarot: sweepTarot(1400),
    timeout: sweepTimeout(1400),
    grabCooldown: sweepGrabCooldown(1400),
    sanity: sanity(1400),
  };
  const file = path.join(__dirname, 'duel-race-sim-results.json');
  fs.writeFileSync(file, JSON.stringify(out, null, 2));
  console.log('\nSaved ' + file);
}

if (require.main === module) main();
module.exports = { simulateGame, runBatch, BASE, STRONG, WEAK, MID };
