/*
 * Human-readable tables for the balance lab.
 * Reads test-results/balance-lab-summary.json (written by balance-lab.cjs).
 *
 *   node tests/playtest/balance-report.cjs [path-to-summary.json]
 */
const fs = require('node:fs');
const path = require('node:path');

const file = process.argv[2] || path.join(__dirname, '..', '..', 'test-results', 'balance-lab-summary.json');
const { summary, static: stat } = JSON.parse(fs.readFileSync(file, 'utf8'));
const ctl = summary.find(r => r.arm === 'balanced');

const wilson = (p, n) => {
  if (!n) return [0, 0];
  const z = 1.96, ph = p / 100, q = 1 - ph, den = 1 + z * z / n;
  const c = (ph + z * z / (2 * n)) / den;
  const m = z * Math.sqrt(ph * q / n + z * z / (4 * n * n)) / den;
  return [Math.max(0, Math.round(100 * (c - m))), Math.min(100, Math.round(100 * (c + m)))];
};
const ci = r => { const [a, b] = wilson(r.winRate, r.runs); return '[' + a + '-' + b + ']'; };
const d = (v, digits = 1) => (v > 0 ? '+' : '') + v.toFixed(digits);
const pad = (v, n) => String(v).padEnd(n);

function table(rows, cols) {
  const head = cols.map(c => pad(c.label, c.width)).join(' ');
  console.log(head);
  for (const r of rows) console.log(cols.map(c => pad(c.get(r), c.width)).join(' '));
}

const common = [
  { label: 'arm', width: 18, get: r => r.arm },
  { label: 'win%', width: 6, get: r => r.winRate + '%' },
  { label: 'CI', width: 9, get: ci },
  { label: 'blinds', width: 7, get: r => r.avgBlinds },
  { label: 'hp', width: 6, get: r => r.avgHp },
  { label: 'hpDeath', width: 8, get: r => r.maybe.hpDeath + '%' },
  { label: 'turnDeath', width: 10, get: r => r.maybe.turnDeath + '%' },
  { label: 'jokers', width: 7, get: r => r.avgJokers },
  { label: 'upg', width: 5, get: r => r.avgUpgrades },
  { label: 'money', width: 6, get: r => r.avgMoney },
];

for (const group of ['policies', 'decks', 'stakes', 'upgrades', 'wild']) {
  const rows = summary.filter(r => r.group === group);
  if (!rows.length) continue;
  console.log('\n### ' + group + ' (n=' + rows[0].runs + ')');
  table(rows, common);
}

const jokers = summary.filter(r => r.group === 'jokers');
if (jokers.length) {
  const byId = new Map(stat.jokers.map(j => [j.id, j]));
  const rows = jokers.map(r => ({ ...r, id: r.arm.slice(6) }))
    .sort((a, b) => b.avgBlinds - a.avgBlinds);
  console.log('\n### jokers (n=' + jokers[0].runs + ', control ' + ctl.avgBlinds + ' blinds / ' + ctl.winRate + '% wins)');
  table(rows, [
    { label: 'joker', width: 12, get: r => r.id },
    { label: 'win%', width: 6, get: r => r.winRate + '%' },
    { label: 'CI', width: 9, get: ci },
    { label: 'blinds', width: 7, get: r => r.avgBlinds },
    { label: 'dBlinds', width: 8, get: r => d(r.avgBlinds - ctl.avgBlinds) },
    { label: 'dWin', width: 6, get: r => d(r.winRate - ctl.winRate, 0) },
    { label: 'hpDeath', width: 8, get: r => r.maybe.hpDeath + '%' },
    { label: 'turnDeath', width: 10, get: r => r.maybe.turnDeath + '%' },
    { label: 'upg', width: 5, get: r => r.avgUpgrades },
    { label: 'money', width: 6, get: r => r.avgMoney },
    { label: 'price', width: 5, get: r => byId.get(r.id)?.price ?? '' },
    { label: 'static', width: 7, get: r => byId.get(r.id)?.blended ?? '' },
  ]);

  // Spearman rank correlation: static blended vs live blinds gain.
  const xs = rows.map(r => byId.get(r.id)?.blended || 0);
  const ys = rows.map(r => r.avgBlinds);
  const rank = a => { const idx = a.map((v, i) => [v, i]).sort((p, q) => p[0] - q[0]); const out = []; idx.forEach(([, i], k) => out[i] = k + 1); return out; };
  const rx = rank(xs), ry = rank(ys);
  const mx = rx.reduce((a, n) => a + n, 0) / rx.length, my = ry.reduce((a, n) => a + n, 0) / ry.length;
  let num = 0, dx = 0, dy = 0;
  for (let i = 0; i < rx.length; i++) { num += (rx[i] - mx) * (ry[i] - my); dx += (rx[i] - mx) ** 2; dy += (ry[i] - my) ** 2; }
  console.log('\nSpearman(static, live blinds) = ' + (num / Math.sqrt(dx * dy)).toFixed(2));

  console.log('\nStatic vs live mismatches');
  const misses = rows.map(r => ({ id: r.id, static: byId.get(r.id)?.blended || 0, gain: +(r.avgBlinds - ctl.avgBlinds).toFixed(1) }))
    .sort((a, b) => (b.static - a.static) || (a.gain - b.gain));
  console.log('highest static, weak live:');
  for (const m of misses.slice(0, 6)) console.log('  ' + pad(m.id, 12) + ' static=' + pad(m.static, 5) + ' live=' + d(m.gain));
  console.log('lowest static (0), strong live:');
  for (const m of misses.filter(m => m.static === 0).sort((a, b) => b.gain - a.gain).slice(0, 6)) console.log('  ' + pad(m.id, 12) + ' static=0     live=' + d(m.gain));
}

if (ctl) {
  console.log('\n### death causes');
  for (const name of ['balanced', 'no-shop', 'jokers-only', 'upgrades-only', 'fourth-table', 'deck-short', 'deck-glass', 'mod-wild', 'stake-platinum']) {
    const r = summary.find(x => x.arm === name);
    if (!r) continue;
    const reasons = Object.entries(r.reasons).sort((a, b) => b[1] - a[1]).map(([k, v]) => k + '=' + v);
    console.log(pad(name, 18) + reasons.join(' | '));
  }

  console.log('\n### reached ante (survivors per stage)');
  const names = ['balanced', 'no-shop', 'jokers-only', 'upgrades-only', 'fourth-table', 'deck-short', 'deck-glass', 'mod-wild', 'wild-1', 'wild-3', 'stake-platinum'];
  console.log(pad('arm', 18) + '  A1  A2  A3  A4  A5  A6  A7  A8');
  for (const name of names) {
    const r = summary.find(x => x.arm === name);
    if (!r) continue;
    console.log(pad(name, 18) + Array.from({ length: 8 }, (_, i) => String(r.reached[i + 1] || 0).padStart(3) + ' ').join('').trimEnd());
  }
}
