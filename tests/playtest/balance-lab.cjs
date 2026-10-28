/*
 * Balance lab: controlled arms for decks, stakes, shop strategies, jokers and upgrades.
 * Deterministic: every arm replays the same seeds; the first seed of each arm is replayed twice.
 *
 * LAB_SEEDS=40 LAB_ONLY=policies npm run test:balance:lab
 * LAB_RAW=1 keeps per-run traces in balance-lab.json (large).
 */
const assert = require('node:assert/strict');
const path = require('node:path');
const { launch, load, writeReport } = require('./runtime.cjs');

const SEEDS = Number(process.env.LAB_SEEDS || 40);
const ONLY = (process.env.LAB_ONLY || '').split(',').map(s => s.trim()).filter(Boolean);

const base = { threshold: 18, deck: 'classic', stake: 0, tactical: true, style: 'balanced' };
const arms = [
  { group: 'policies', name: 'balanced', ...base },
  { group: 'policies', name: 'cautious', ...base, threshold: 16 },
  { group: 'policies', name: 'risky', ...base, threshold: 20 },
  { group: 'policies', name: 'no-tactics', ...base, tactical: false },
  { group: 'policies', name: 'no-shop', ...base, style: 'none' },
  { group: 'policies', name: 'jokers-only', ...base, style: 'jokers' },
  { group: 'policies', name: 'upgrades-only', ...base, style: 'upgrades' },
  { group: 'policies', name: 'consumables-only', ...base, style: 'consumables' },
  { group: 'policies', name: 'fourth-table', ...base, style: 'table', saving: true },

  { group: 'decks', name: 'deck-classic', ...base },
  { group: 'decks', name: 'deck-short', ...base, deck: 'short' },
  { group: 'decks', name: 'deck-gold', ...base, deck: 'gold' },
  { group: 'decks', name: 'deck-glass', ...base, deck: 'glass' },
  { group: 'decks', name: 'deck-alchemy', ...base, deck: 'alchemy' },

  { group: 'stakes', name: 'stake-white', ...base },
  { group: 'stakes', name: 'stake-bronze', ...base, stake: 1 },
  { group: 'stakes', name: 'stake-silver', ...base, stake: 2 },
  { group: 'stakes', name: 'stake-gold', ...base, stake: 3 },
  { group: 'stakes', name: 'stake-platinum', ...base, stake: 4 },
  { group: 'stakes', name: 'stake-diamond', ...base, stake: 5 },

  { group: 'upgrades', name: 'mod-gold', ...base, mods: [{ mod: 'gold', count: 6 }] },
  { group: 'upgrades', name: 'mod-glass', ...base, mods: [{ mod: 'glass', count: 6 }] },
  { group: 'upgrades', name: 'mod-heavy', ...base, mods: [{ mod: 'heavy', count: 6 }] },
  { group: 'upgrades', name: 'mod-wild', ...base, mods: [{ mod: 'wild', count: 6 }] },
  { group: 'upgrades', name: 'mod-curse', ...base, mods: [{ mod: 'curse', count: 6 }] },
  { group: 'upgrades', name: 'all-cards-plus1', ...base, ups: [{ levels: 1 }] },
  { group: 'upgrades', name: 'all-cards-plus2', ...base, ups: [{ levels: 2 }] },
  { group: 'upgrades', name: 'sevens-plus1', ...base, ups: [{ rank: '7', levels: 1 }] },
  { group: 'upgrades', name: 'aces-plus1', ...base, ups: [{ rank: 'A', levels: 1 }] },

  // Wild-card scaling: checks whether the +6 arm is a smooth advantage or a broken mechanic.
  ...[1, 2, 3, 4, 6].map(n => ({ group: 'wild', name: 'wild-' + n, ...base, mods: [{ mod: 'wild', count: n }] })),
];

// One joker granted at run start, balanced shop afterwards.
const jokerArms = [
  'ace', 'six', 'lucky7', 'redblack', 'tips', 'counter', 'cushion', 'gambler', 'miser', 'insurer',
  'face', 'streak', 'hearts', 'triple', 'precision', 'suits', 'risk', 'refund', 'sync', 'tandem',
  'ladder', 'relay', 'balance', 'crimson', 'blot', 'banker', 'alchemist', 'adrenaline', 'surgeon', 'ice',
  'diplomat', 'allin', 'phoenix', 'pair', 'wide', 'xray', 'execution', 'bullseye', 'revenge', 'breaker',
  'desperate', 'slayer', 'encore',
].map(id => ({ group: 'jokers', name: 'joker:' + id, ...base, jokers: [id] }));

const all = arms.concat(jokerArms).filter(a => !ONLY.length || ONLY.includes(a.group) || ONLY.includes(a.name));

(async () => {
  const browser = await launch();
  try {
    const page = await browser.newPage();
    await load(page);
    await page.addScriptTag({ path: path.join(__dirname, 'bot.js') });
    await page.addScriptTag({ path: path.join(__dirname, 'lab-static.js') });
    await page.evaluate(() => {
      render = () => {}; renderShop = () => {}; saveRun = () => {}; showBlindIntro = () => {};
      showScoreBurst = () => {}; tgHaptic = () => {}; flashHint = () => {}; metaSave = () => {};
      purchaseFeedback = () => {}; toast = () => {}; showOverlay = () => {}; showRelicChoice = () => {};
      window.setTimeout = () => 0; autoFinish = () => {};
      stand = () => { if (G.phase === 'play' && G.seat) finishSeat(evalSeat(G.seat)); };
      const originalFinish = finishSeat;
      finishSeat = function (res, animated) {
        const enemyBefore = G.enemy ? G.enemy.hp : 0, playerBefore = G.player.hp;
        window.__lab.turns++;
        const out = originalFinish(res, animated);
        window.__lab.damage += Math.max(0, enemyBefore - (G.enemy ? G.enemy.hp : 0));
        window.__lab.received += Math.max(0, playerBefore - G.player.hp);
        return out;
      };
    });

    const results = [];
    for (const cfg of all) {
      for (let seed = 0; seed < SEEDS; seed++) {
        const run = await page.evaluate(c => VochkoBot.run(c), { ...cfg, seed });
        results.push({ arm: cfg.name, group: cfg.group, seed, ...run });
        if (seed === 0) {
          const repeat = await page.evaluate(c => VochkoBot.run(c), { ...cfg, seed });
          assert.deepEqual(repeat, run, 'Seed must reproduce exactly: ' + cfg.name);
        }
      }
      console.log(cfg.name + ': ' + SEEDS + ' runs');
    }

    const staticLab = await page.evaluate(() => Lab.analyse());
    const summary = buildSummary(results, all);
    const meta = { seeds: SEEDS, arms: all.length, runs: results.length, groups: [...new Set(all.map(a => a.group))] };
    const payload = { meta, summary, static: staticLab };
    if (process.env.LAB_RAW === '1') payload.runs = results;
    writeReport('balance-lab.json', payload);
    writeReport('balance-lab-summary.json', { summary, static: staticLab });
    console.log('\nSTATIC JOKERS');
    console.log(JSON.stringify(staticLab.jokers, null, 2));
    console.log('\nSUMMARY');
    console.log(JSON.stringify(summary, null, 2));
    if (results.some(x => x.error || !['over', 'won'].includes(x.phase))) process.exitCode = 1;
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exitCode = 1; });

function mean(list) { return list.length ? list.reduce((a, n) => a + n, 0) / list.length : 0; }
function pct(part, total) { return total ? Math.round(1000 * part / total) / 10 : 0; }

function buildSummary(results, cfgList) {
  return cfgList.map(cfg => {
    const runs = results.filter(r => r.arm === cfg.name);
    const wins = runs.filter(r => r.phase === 'won');
    const reasons = {};
    for (const r of runs) if (r.reason) reasons[r.reason] = (reasons[r.reason] || 0) + 1;
    const bought = {}, used = {};
    for (const r of runs) {
      for (const b of r.bought) bought[b] = (bought[b] || 0) + 1;
      for (const [k, n] of Object.entries(r.used)) used[k] = (used[k] || 0) + n;
    }
    const stages = {};
    for (const r of runs) {
      const reached = Math.min(8, Math.max(1, Math.ceil((r.blinds + 1) / 3)));
      for (let s = 1; s <= reached; s++) stages[s] = (stages[s] || 0) + 1;
    }
    return {
      arm: cfg.name, group: cfg.group, config: cfg,
      runs: runs.length, wins: wins.length, winRate: pct(wins.length, runs.length),
      avgBlinds: +mean(runs.map(r => r.blinds)).toFixed(2),
      avgTurns: +mean(runs.map(r => r.turns)).toFixed(1),
      avgHp: +mean(runs.map(r => r.hp)).toFixed(1),
      avgMoney: +mean(runs.map(r => r.money)).toFixed(1),
      avgJokers: +mean(runs.map(r => r.jokerCount)).toFixed(2),
      avgRelics: +mean(runs.map(r => r.relicCount)).toFixed(2),
      avgUpgrades: +mean(runs.map(r => r.upgrades)).toFixed(2),
      avgDamage: Math.round(mean(runs.map(r => r.damage))),
      avgReceived: +mean(runs.map(r => r.received)).toFixed(1),
      maybe: {
        hpDeath: pct(runs.filter(r => /Здоровье/.test(r.reason || '')).length, runs.length),
        turnDeath: pct(runs.filter(r => /Ходы/.test(r.reason || '')).length, runs.length),
      },
      fourthTable: pct(runs.filter(r => r.fourthTable).length, runs.length),
      errors: runs.filter(r => r.error).length,
      reasons, bought, used,
      reached: stages,
      seeds: runs.map(r => ({ seed: r.seed, phase: r.phase, blinds: r.blinds, stage: r.stage, hp: r.hp, reason: r.reason })),
    };
  });
}
