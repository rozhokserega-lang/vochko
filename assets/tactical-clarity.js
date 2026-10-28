/* Counterfactual previews use copied state and never draw cards or consume RNG. */
function copySeat(s) {
  return {...s, tables:s.tables.map(t=>({...t, cards:t.cards.slice(), adj:{...t.adj}}))};
}
function withGameState(game, calculate) {
  const previous = G;
  try { G = game; return calculate(); } finally { G = previous; }
}
function previewConsumable(s, index, ti, ci, destination) {
  const item = G.cons[index], table = s?.tables[ti];
  if (!item || !table || s.locked || table.blocked || !table.cards.length || bossIs('nocons') || (bossIs('thin') && s.used)) return null;
  const kind = item.kind;
  if (!['remove','move'].includes(kind) && (table.dead || table.locked)) return null;
  if (kind === 'plus' && bossIs('noplus')) return null;
  const next = copySeat(s), t = next.tables[ti];
  if (kind === 'minus') t.adj.dv -= consPower(item);
  else if (kind === 'plus') {t.adj.dv += consPower(item); t.adj.dc += consPower(item);}
  else if (kind === 'pct') t.adj.dv -= Math.ceil(Math.max(0,evalPlay(t.cards,t.adj).sum)*item.n);
  else if (kind === 'freeze') {if(t.adj.fz)return null;t.adj.fz=t.cards.length;}
  else if (kind === 'remove' || kind === 'move') {
    if (!t.cards[ci]) return null;
    const to = next.tables[destination];
    if (kind === 'move' && (!to || destination===ti || to.blocked || to.cards.length>=maxPlay())) return null;
    t.adj = removedCardAdj(t.adj,ci,t.cards.length);
    const card = t.cards.splice(ci,1)[0];
    t.dead=t.locked=t.stood=false;
    if(kind==='move'){to.cards.push(card);to.dead=to.locked=to.stood=false;}
  } else if (kind === 'swap') {
    if (t.adj.fz && t.cards.length<=t.adj.fz) return null;
    // Hidden draw order must never be leaked by a preview.
    if (!(s.peek || s.peek3 || hasJoker('xray')) || !G.deck.length) return {unknown:true};
    t.cards[t.cards.length-1] = G.deck[G.deck.length-1];
  } else return null;
  next.used=true;next.sel=null;
  const before = evalSeat(s), beforeHit = attackPreview(before).hp;
  const calculate = cons => withGameState({...G,seat:next,cons},()=>{
    refreshTables(next);
    const result=evalSeat(next), forecast=combatForecast(result);
    return {result,forecast};
  });
  const spent=G.cons.filter((_,i)=>i!==index), after=calculate(spent);
  const retained=hasJoker('alchemist') ? calculate(G.cons) : null;
  return {before, beforeHit, after:after.result, hit:after.forecast.hit.hp, forecast:after.forecast,
    sums:after.result.tables.map(r=>r.empty?'—':r.sum), retainedHit:retained?.forecast.hit.hp,
    retainedPlayerHp:retained?.forecast.playerHp, kind};
}
function previewText(p, ti, destination) {
  if (!p) return '';
  if (p.unknown) return 'Новая карта неизвестна — точный прогноз недоступен';
  const sum = i => 'Стол '+(i+1)+': '+(p.before.tables[i].empty?'—':p.before.tables[i].sum)+' → '+p.sums[i];
  const range = p.retainedHit===undefined || p.retainedHit===p.hit ? fmt(p.hit) : fmt(Math.min(p.hit,p.retainedHit))+'–'+fmt(Math.max(p.hit,p.retainedHit));
  return sum(ti)+(destination===undefined?'':' · '+sum(destination))+' · Урон: '+fmt(p.beforeHit)+' → '+range+
    (p.kind==='freeze'?' · сумма зафиксируется':'')+(p.retainedHit!==undefined?' · зависит от Алхимика':'');
}
function consumableTablePreview(s, ti) {
  if(s.sel===null || s.sel===undefined)return '';
  const p=previewConsumable(s,s.sel,ti);
  return p ? '<div class="cons-preview">'+previewText(p,ti)+'</div>' : '';
}
function chipBonusSources(cards) {
  const live=cards.filter(c=>c.mod!=='curse'&&!(bossIs('odd')&&['3','5','7','9'].includes(c.rank)));
  const sources=[['six',c=>c.val>=2&&c.val<=6],['ace',c=>c.rank==='A'],['lucky7',c=>c.rank==='7'],['redblack',c=>c.color==='black'],['face',c=>['J','Q','K'].includes(c.rank)],['hearts',c=>c.suit==='♥']];
  const names=sources.filter(([id,test])=>hasJoker(id)&&live.some(test)).map(([id])=>JOKERS.find(j=>j.id===id).name+' · бонус к чипам');
  if(hasRelic('anvil')&&live.length)names.push(RELICS.anvil.name+' · бонус к чипам');
  if(live.some(c=>c.mod==='heavy'))names.push('Тяжёлые карты · чипы ×2');
  if(bossIs('dark')&&live.some(c=>c.color==='red'))names.push('Чёрная ночь · чипы красных карт вдвое меньше');
  return names;
}
function damageBreakdown(result) {
  const hit=attackPreview(result);
  return {goal:limitNow(),tables:result.tables.map(r=>({...r,tags:(r.tags||[]).slice()})),tags:result.tags.slice(),
    chipSources:G.seat.tables.map(t=>chipBonusSources(t.cards)),
    total:result.total,tableTotal:result.tables.reduce((n,r)=>n+(r.score||0),0),hit,
    weak:G.player.effects.find(e=>e.id==='weak')?.power||0};
}
function damageBreakdownHTML(d) {
  return '<div class="damage-breakdown">'+(d.goal!==undefined?'<p>Цель этого хода: <b>'+d.goal+'</b></p>':'')+d.tables.map((r,i)=>'<section><b>Стол '+(i+1)+' · '+(r.empty?'пусто':r.bust?'перебор':r.sum)+'</b><p>'+(r.empty?'0 очков':r.bust?'0 очков: сумма выше цели':fmt(r.chips)+' чипов × '+fmtMult(r.mult)+' множитель стола → '+fmt(r.score)+' очков с эффектами')+'</p>'+((d.chipSources?.[i]||[]).length?'<small>'+d.chipSources[i].join(' · ')+'</small>':'')+(r.tags.length?'<small>'+r.tags.join(' · ')+'</small>':'')+'</section>').join('')+
    '<p>Сумма очков столов: <b>'+fmt(d.tableTotal)+'</b></p>'+
    (d.tags.length?'<p>Эффекты столов и комбинаций: '+d.tags.join(' · ')+'</p>':'')+
    '<p>После комбинаций: <b>'+fmt(d.total)+'</b></p>'+
    (d.hit.steps||[]).map(step=>'<p>'+step.name+': '+(step.mult?'+'+Math.round(step.mult*100)+'% атаки':'')+(step.shieldBonus?'+'+Math.round(step.shieldBonus*100)+'% щиту':'')+'</p>').join('')+'<p>Атака с боевыми бонусами'+(d.weak?' и ослаблением':'')+': <b>'+fmt(d.hit.attack)+'</b></p>'+
    '<p>Снято щита: <b>'+fmt(d.hit.absorbed)+'</b> · броня: <b>'+Math.round(d.hit.armor*100)+'%</b></p><p>Потеря HP врага: <b>'+fmt(d.hit.hp)+'</b> (не больше оставшегося HP)</p></div>';
}
function showDamageBreakdown() {
  if(G.phase!=='play'||!G.seat||G.seat.locked||G.battle.resolving)return;
  showOverlay('<div class="kicker">Текущий ход</div><h2>Откуда берётся урон</h2>'+damageBreakdownHTML(damageBreakdown(evalSeat(G.seat)))+'<div class="row-btns"><button class="primary" id="damage-close">К столам</button></div>');
  $('#damage-close').onclick=()=>{hideOverlay();render()};
}
function recordTurnStart(result) {
  G.lastTurn={...damageBreakdown(result),busts:result.bust,enemyHpBefore:G.enemy.hp,playerHpBefore:G.player.hp,
    consumables:G.cons.map(c=>c.name),bustChips:result.tables.filter(r=>r.bust).reduce((n,r)=>n+r.chips,0)};
  const summary=G.battleSummary||(G.battleSummary={turns:0,busts:0,bustChips:0,damage:0});
  summary.turns++;summary.busts+=result.bust;summary.bustChips+=G.lastTurn.bustChips;
}
function recordTurnEnd() {
  if(!G.lastTurn)return;
  G.lastTurn.damage=G.battle.lastHit?.hp||0;
  G.lastTurn.received=G.battle.lastReceived||0;
  G.lastTurn.enemyHpAfter=G.enemy.hp;
  G.lastTurn.playerHpAfter=G.player.hp;
  G.battleSummary.damage+=G.lastTurn.damage;
}
function lossReviewHTML() {
  const last=G.lastTurn, stats=G.battleSummary;
  if(!last||!stats)return '';
  const remaining=G.cons.map(c=>c.name);
  const tip=last.busts && remaining.some(name=>/Срез|Убрать|Перенос/.test(name))
    ? 'Остались предметы для изменения карт. Перед завершением хода сравнивай их прогноз на перебравших столах; ограничения босса могут мешать применению.'
    : last.busts ? 'В последнем ходе были переборы. Перед добором сравнивай текущий урон с риском потерять очки стола.'
    : G.seatsLeft<=0 ? 'Ходы закончились. В следующем забеге сравнивай вклад джокеров через разбор урона и усиливай сборку между боями.'
    : 'Здоровье закончилось. Перед ходом смотри прогноз ответного урона; красные столы из трёх и более карт лечат без перебора.';
  return '<section class="loss-review"><h3>Разбор поражения</h3><p>У врага осталось <b>'+fmt(G.enemy.hp)+' HP</b>. Последний ход нанёс <b>'+fmt(last.damage)+' урона</b>, получено <b>'+last.received+' урона</b>.</p><p>Переборы: <b>'+last.busts+'</b> в последнем ходе, <b>'+stats.busts+'</b> за бой. На перебравших столах за бой было <b>'+fmt(stats.bustChips)+' чипов</b>, давших 0 очков. Это не оценка упущенного урона.</p><p>Остались расходники: '+(remaining.join(', ')||'нет')+'.</p><p class="review-tip">'+tip+'</p><details><summary>Разбор последнего хода</summary>'+damageBreakdownHTML(last)+'</details></section>';
}
