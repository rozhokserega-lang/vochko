/* Static valuation for the balance lab. Pure scoring: no runs, no gameplay RNG. */
window.Lab = (() => {
  const RANK_VAL = Object.fromEntries(RANKS);
  let seq = 0;
  const C = (rank, suit) => ({
    id: ++seq, rank, suit, color: suit === '♥' || suit === '♦' ? 'red' : 'black',
    val: RANK_VAL[rank], up: 0, dv: 0, dc: 0,
  });
  const S = pairs => pairs.map(([rank, suit]) => C(rank, suit));

  // Representative tables: exact, near, ladder, tandem, bust, full, colour bonuses.
  const sets = () => [
    { name: 'exact', tables: [S([['7', '♦'], ['7', '♣'], ['7', '♥']]), S([['A', '♠'], ['5', '♣'], ['5', '♦']]), S([['K', '♥'], ['Q', '♦'], ['A', '♣']])] },
    { name: 'near', tables: [S([['K', '♠'], ['J', '♥']]), S([['10', '♣'], ['9', '♦']]), S([['8', '♦'], ['7', '♣'], ['5', '♠']])] },
    { name: 'ladder', tables: [S([['10', '♣'], ['9', '♦']]), S([['10', '♦'], ['10', '♠']]), S([['A', '♥'], ['5', '♦'], ['5', '♠']])] },
    { name: 'tandem', tables: [S([['10', '♣'], ['9', '♦']]), S([['10', '♦'], ['9', '♥']]), S([['8', '♠'], ['7', '♥']])] },
    { name: 'bust', tables: [S([['K', '♠'], ['Q', '♥'], ['J', '♦']]), S([['7', '♦'], ['7', '♣'], ['7', '♥']]), S([['10', '♣'], ['9', '♦']])] },
    { name: 'full', tables: [S([['2', '♠'], ['3', '♥'], ['4', '♦'], ['5', '♣']]), S([['3', '♠'], ['4', '♥'], ['5', '♦'], ['6', '♣']]), S([['4', '♠'], ['5', '♥'], ['6', '♦'], ['7', '♣']])] },
    { name: 'colors', tables: [S([['8', '♥'], ['9', '♥'], ['4', '♥']]), S([['9', '♠'], ['8', '♣'], ['4', '♠']]), S([['2', '♦'], ['3', '♠'], ['4', '♥']])] },
  ];

  const seat = tables => ({ ...newTable(), tables: tables.map(cards => ({ ...newTable(), cards })), goal: 21 });
  const neutral = () => ({ ...G, seat: null, jokers: [], boss: null, boss2: null, contract: null, stake: 0, limit: 21, battle: { ...(G.battle || {}), turn: 0 } });

  const setScores = jokers => withGameState({ ...neutral(), jokers }, () =>
    sets().map(set => evalSeat(seat(set.tables)).total));
  const avgScore = jokers => {
    const scores = setScores(jokers);
    return scores.reduce((a, n) => a + n, 0) / scores.length;
  };

  let lcg = 20261028;
  const rand = () => { lcg = (lcg * 1664525 + 1013904223) >>> 0; return lcg / 4294967296; };

  const drawSeats = (n = 400) => {
    const saved = lcg;
    lcg = 20261028;
    const deck = makeDeck();
    const seats = [];
    for (let i = 0; i < n; i++) {
      const pool = deck.slice();
      const tables = [[], [], []];
      for (let k = 0; k < 9; k++) tables[k % 3].push(pool.splice(Math.floor(rand() * pool.length), 1)[0]);
      seats.push(tables);
    }
    lcg = saved;
    return seats;
  };
  const seats = drawSeats();
  const randomScore = jokers => withGameState({ ...neutral(), jokers }, () =>
    seats.reduce((sum, tables) => sum + evalSeat(seat(tables)).total, 0) / seats.length);

  const jokers = () => {
    const base = avgScore([]);
    const randomBase = randomScore([]);
    return JOKERS.map(j => {
      const scores = setScores([j]);
      const gain = avgScore([j]) - base;
      const randomGain = randomScore([j]) - randomBase;
      return {
        id: j.id, name: j.name, price: j.price, rarity: j.rarity,
        gain: +gain.toFixed(0), gainPct: +(100 * gain / base).toFixed(1), perDollar: +(((gain + randomGain) / 2) / j.price).toFixed(1),
        randomGain: +randomGain.toFixed(0), randomPct: +(100 * randomGain / randomBase).toFixed(1),
        blended: +((gain + randomGain) / 2).toFixed(0),
        perSet: scores.map(s => +(s - base).toFixed(0)),
      };
    }).sort((a, b) => b.blended - a.blended);
  };

  const pairs = () => {
    const base = avgScore([]);
    const solo = new Map(JOKERS.map(j => [j.id, avgScore([j]) - base]));
    const out = [];
    for (let i = 0; i < JOKERS.length; i++) {
      for (let k = i + 1; k < JOKERS.length; k++) {
        const a = JOKERS[i], b = JOKERS[k];
        const gain = avgScore([a, b]) - base;
        out.push({
          a: a.id, b: b.id, gain: +gain.toFixed(0),
          synergy: +(gain - solo.get(a.id) - solo.get(b.id)).toFixed(0),
        });
      }
    }
    return out.sort((x, y) => y.synergy - x.synergy);
  };

  const sampleHands = (mutate = () => {}, handMod = null, n = 500) => {
    const before = lcg;
    lcg = 20261028;
    const deck = makeDeck();
    mutate(deck);
    let total = 0, busts = 0;
    for (let i = 0; i < n; i++) {
      const pool = deck.slice();
      const hand = [];
      for (let k = 0; k < 3; k++) hand.push(pool.splice(Math.floor(rand() * pool.length), 1)[0]);
      if (handMod) hand[0] = { ...hand[0], mod: handMod };
      const r = withGameState({ ...neutral(), jokers: [] }, () => evalPlay(hand));
      total += r.score;
      if (r.bust) busts++;
    }
    lcg = before;
    return { avg: +(total / n).toFixed(0), bust: +(100 * busts / n).toFixed(1) };
  };

  const upgrades = () => {
    const base = sampleHands();
    const cats = [
      { key: 'rank-2', label: 'Все «2» +1', mutate: deck => deck.forEach(c => { if (c.rank === '2') c.up = 1; }) },
      { key: 'rank-3', label: 'Все «3» +1', mutate: deck => deck.forEach(c => { if (c.rank === '3') c.up = 1; }) },
      { key: 'rank-4', label: 'Все «4» +1', mutate: deck => deck.forEach(c => { if (c.rank === '4') c.up = 1; }) },
      { key: 'rank-5', label: 'Все «5» +1', mutate: deck => deck.forEach(c => { if (c.rank === '5') c.up = 1; }) },
      { key: 'rank-6', label: 'Все «6» +1', mutate: deck => deck.forEach(c => { if (c.rank === '6') c.up = 1; }) },
      { key: 'rank-7', label: 'Все «7» +1', mutate: deck => deck.forEach(c => { if (c.rank === '7') c.up = 1; }) },
      { key: 'rank-8', label: 'Все «8» +1', mutate: deck => deck.forEach(c => { if (c.rank === '8') c.up = 1; }) },
      { key: 'rank-9', label: 'Все «9» +1', mutate: deck => deck.forEach(c => { if (c.rank === '9') c.up = 1; }) },
      { key: 'rank-10', label: 'Все «10» +1', mutate: deck => deck.forEach(c => { if (c.rank === '10') c.up = 1; }) },
      { key: 'all-1', label: 'Вся колода +1', mutate: deck => deck.forEach(c => { c.up = 1; }) },
      { key: 'all-2', label: 'Вся колода +2', mutate: deck => deck.forEach(c => { c.up = 2; }) },
      { key: 'all-3', label: 'Вся колода +3', mutate: deck => deck.forEach(c => { c.up = 3; }) },
      { key: 'mod-gold', label: 'Золотая карта в руке', mutate: () => {}, mod: 'gold' },
      { key: 'mod-glass', label: 'Стеклянная карта в руке', mutate: () => {}, mod: 'glass' },
      { key: 'mod-heavy', label: 'Тяжёлая карта в руке', mutate: () => {}, mod: 'heavy' },
      { key: 'mod-wild', label: 'Дикая карта в руке', mutate: () => {}, mod: 'wild' },
      { key: 'mod-curse', label: 'Проклятая карта в руке', mutate: () => {}, mod: 'curse' },
    ];
    return {
      base,
      rows: cats.map(c => {
        const r = sampleHands(c.mutate, c.mod || null);
        return { ...c, mutate: undefined, avg: r.avg, bust: r.bust, delta: r.avg - base.avg, deltaPct: +(100 * (r.avg - base.avg) / base.avg).toFixed(1) };
      }),
    };
  };

  return {
    analyse() {
      VochkoBot.reset(0, 'classic', 0);
      return { sets: sets().map(s => s.name), base: { combo: +avgScore([]).toFixed(0), random: +randomScore([]).toFixed(0) }, jokers: jokers(), pairs: pairs(), upgrades: upgrades() };
    },
  };
})();
