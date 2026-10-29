/* Run persistence and tactical UI. Game definitions live in the main HTML. */
const RUN_SAVE_KEY = 'vochko.run.v1';
let restoringRun = false;

function consKey(item) {
  return Object.keys(CONS).find(key => CONS[key] === item || (CONS[key].kind === item.kind && CONS[key].n === item.n && CONS[key].name === item.name));
}
function readSavedRun() {
  try {
    const saved = JSON.parse(localStorage.getItem(RUN_SAVE_KEY) || 'null');
    const game = saved && saved.game;
    if (saved?.version !== 1 || !game?.started || !['intro','play','shop','path'].includes(game.phase) || !Array.isArray(game.runDeck) || !Array.isArray(game.jokers) || !Array.isArray(saved.consKeys) || !game.player || !Number.isFinite(game.money)) return null;
    if (game.phase === 'play' && (!game.seat?.tables || !game.enemy || !game.battle)) return null;
    if (saved.consKeys.some(key => !CONS[key]) || game.jokers.some(j => !JOKERS.some(def => def.id === j.id))) return null;
    return saved;
  } catch (_) { return null; }
}
function saveRun() {
  if (restoringRun || !G?.started || G.pending === 'setup') return;
  try {
    if (G.phase === 'over' || G.phase === 'won') { localStorage.removeItem(RUN_SAVE_KEY); return; }
    // Keep the preceding stable checkpoint during the score animation.
    if (G.seat?.locked || G.battle?.resolving) return;
    const game = {...G, seat:G.seat ? {...G.seat, sel:null} : null};
    localStorage.setItem(RUN_SAVE_KEY, JSON.stringify({version:1, savedAt:Date.now(), game, consKeys:G.cons.map(consKey), cardSeq, lastBoss, rngState:Number.isFinite(Math.random.state) ? Math.random.state : null}));
  } catch (_) { /* Storage can be disabled or full; keep the current game playable. */ }
}
function resumeRun() {
  const saved = readSavedRun();
  if (!saved) { toast('Сохранённый забег недоступен'); return; }
  restoringRun = true;
  G = saved.game;
  G.cons = saved.consKeys.map(key => CONS[key]);
  G.jokers = G.jokers.map(j => ({...j, ...JOKERS.find(def => def.id === j.id), ...(j.charges !== undefined ? {charges:j.charges} : {})}));
  const bindOffer = item => {
    if (item.joker) item.joker = JOKERS.find(j => j.id === item.joker.id);
    if (item.card) item.card = G.runDeck.find(c => c.id === item.card.id);
    return item;
  };
  if (G.shop) G.shop.items = G.shop.items.map(bindOffer);
  if (G.reservedItem) G.reservedItem = bindOffer(G.reservedItem);
  if (G.event) G.event = EVENTS.find(event => event.title === G.event.title);
  if (G.legendChoice) G.legendChoice = JOKERS.find(j => j.id === G.legendChoice.id);
  cardSeq = Math.max(saved.cardSeq || 0, ...G.runDeck.map(c => c.id));
  lastBoss = saved.lastBoss;
  Math.random = G.daily && saved.rngState !== null ? mulberry32(saved.rngState) : RNG0;
  BattleUI.prev = null; BattleUI.game = null;
  hideOverlay(); render(); tgClosingConfirmation(true);
  if (G.phase === 'intro') showBlindIntro();
  else if (G.phase === 'shop') {
    if (G.evolutionChoice) showGrowthChoice(G.evolutionChoice);
    else if (G.relicChoice?.length) showRelicChoice();
    else if (G.shop) renderShop();
    else if ((G.blind === 2 && (G.ante < CONFIG.maxAnte || G.endless)) || G.elite) openRelicChoice();
    else openShop();
  } else if (G.phase === 'path') {
    if (G.pending === 'event') openEvent(true);
    else if (G.pending === 'contract') openContract(true);
    else if (G.pending === 'forge') { const mode = G.forgeMode,id=G.forgeSelection; openCampfire(); if (mode) {forgeAction(mode);if(id)forgeConfirm(id);} }
    else if (G.pending === 'rest') openRest();
    else if (G.pending === 'bargains') { const id=G.bargainSelection;openBargains();if(id)confirmBargain(id); }
    else if (G.nodeResult) nodeResult(G.nodeResult.title, G.nodeResult.msg, G.nodeResult.pendingTag);
    else openPath(true);
  }
  restoringRun = false; saveRun();
}

function enemyTrait(enemy = G.enemy) {
  return ({
    collector:'Откуп: $3 отменяют следующую атаку. Штраф за перебор остаётся.',
    brawler:'Раз в 3 хода — тяжёлый удар. Стол из 4+ карт без перебора ослабляет его на 40%.',
    sentinel:'Точный стол снимает 2% брони до конца боя.',
    usurer:'Два точных стола отменяют объявленное лечение.'
  })[enemy?.id] || '';
}
function attackPreview(result, healApplied = false) {
  const enemy = G.enemy, player = G.player;
  const ctx = Effects.run('attack', {result, mult:1, shieldBonus:0, playerHp:Math.min(player.maxHp,player.hp + (healApplied ? 0 : result.heal || 0))});
  const weak = player.effects.find(effect => effect.id === 'weak')?.power || 0;
  const armor = enemy.id === 'sentinel' ? Math.max(0, enemy.armor - .02 * result.exact) : enemy.armor;
  const hit = Combat.damage(result.total * ctx.mult * (1 - weak), enemy.shield, armor, ctx.shieldBonus);
  return {...hit, hp:Math.min(enemy.hp, hit.hp), armor, steps:ctx.steps||[]};
}
function enemyResponse(result, intent = G.enemy.intent) {
  if (!intent) return {raw:0,kind:'none',amount:0};
  let amount = intent.amount;
  const longTable = result.tables.some((table,index) => !table.empty && !table.bust && G.seat.tables[index].cards.length >= 4);
  if (G.enemy.id === 'brawler' && intent.kind === 'heavy' && longTable) amount = Math.floor(amount * .6);
  if (G.enemy.id === 'usurer' && intent.kind === 'heal' && result.exact >= 2) amount = 0;
  if(hasBargain('fury')&&['attack','heavy','hex'].includes(intent.kind))amount+=2;
  const paid = G.enemy.id === 'collector' && G.battle.bribed;
  return {raw:['attack','heavy','hex'].includes(intent.kind) && !paid ? amount : 0, kind:intent.kind, amount, paid};
}
function combatForecast(result) {
  const hit = attackPreview(result), enemy = G.enemy, player = G.player;
  const healed = Math.min(result.heal || 0, player.maxHp - player.hp);
  const response = enemyResponse(result);
  const win = hit.hp >= enemy.hp;
  const reduction = Effects.run('incoming', {reduction:0}).reduction;
  let hp = player.hp + healed, shield = player.shield + (result.growthShield||0), incoming = 0, revive = false;
  let revived = player.revived;
  const receive = raw => {
    const damage = Combat.damage(raw,shield,reduction);
    shield -= damage.absorbed;
    const actual = Math.min(hp,damage.hp); hp -= actual; incoming += actual;
    if (hp <= 0 && hasRelic('revive') && !revived) { revived = true; revive = true; hp = Math.min(player.maxHp,COMBAT.items.revive); }
  };
  if (!win) {
    receive(response.raw);
    if (hp > 0 && result.bust) receive(result.bust * bustPenalty());
  } else if (hasRelic('mend')) hp = Math.min(player.maxHp,hp + COMBAT.items.mend);
  const healEnemy = !win && response.kind === 'heal' ? Math.min(response.amount,enemy.maxHp - (enemy.hp - hit.hp)) : 0;
  const extraLife = hasJoker('phoenix') && !G.phoenixUsed && result.total === 0 && result.bust;
  const outOfSeats = !win && G.seatsLeft <= 1 && !extraLife;
  return {hit,win,incoming,healed,playerHp:hp,playerShield:shield,revive,enemyHeal:healEnemy,response,outOfSeats};
}
function forecastText(forecast) {
  const f = forecast;
  return 'HP врага −' + fmt(f.hit.hp) + (f.hit.absorbed ? ' · щит −' + fmt(f.hit.absorbed) : '') +
    (f.win ? ' · победа' : ' · тебе −' + f.incoming + ' HP' + (f.enemyHeal ? ' · враг лечится +' + fmt(f.enemyHeal) : '')) +
    (f.healed ? ' · лечение +' + f.healed : '') + (f.revive ? ' · возрождение' : '') + (f.playerHp <= 0 ? ' · опасно: поражение' : f.outOfSeats ? ' · ходы закончатся' : '');
}
function renderRoundBudget() {
  const panel=document.querySelector('#round-budget');
  if(!panel)return;
  panel.hidden=!G?.enemy||!['intro','play'].includes(G.phase);
  if(panel.hidden)return;
  const total=seatsCount(),left=Math.max(0,G.seatsLeft);
  const signature=left+':'+total;
  if(panel.dataset.budget===signature)return;
  panel.dataset.budget=signature;
  panel.classList.toggle('last-round',left===1);
  panel.classList.toggle('no-rounds',left===0);
  document.querySelector('#round-budget-title').textContent=left===1?'Последний ход!':left===0?'Ходы закончились':'Осталось ходов';
  document.querySelector('#round-budget-note').textContent=left===1?'Победи сейчас, иначе поражение':left===0?'Враг должен быть повержен':'Розыгрыш всех столов = 1 ход';
  document.querySelector('#rounds-left').textContent=left;
  document.querySelector('#rounds-total').textContent='из '+total;
  document.querySelector('#round-budget-track').innerHTML=Array.from({length:total},(_,i)=>'<i class="'+(i<total-left?'spent':'available')+'"></i>').join('');
  panel.setAttribute('aria-label','Осталось ходов: '+left+' из '+total+(left===1?'. Последний ход':''));
}
function payCollector() {
  if (G.phase !== 'play' || G.seat?.locked || G.enemy?.id !== 'collector' || G.battle.bribed || G.money < 3 || !['attack','heavy','hex'].includes(G.enemy.intent?.kind)) return;
  G.money -= 3; G.battle.bribed = true;
  log('Откуп: $3 · следующая атака отменена, переборы всё ещё опасны','gold'); render();
}

function showDeckBook() {
  if (!G?.started || !['play','intro','shop'].includes(G.phase) || G.seat?.locked) return;
  const groups = new Map();
  for (const card of G.runDeck) {
    const key = [card.rank,card.suit,card.up||0,card.mod||''].join('|');
    if (!groups.has(key)) groups.set(key,{card,total:0,draw:0,discard:0,table:0});
    const group = groups.get(key); group.total++;
    if (G.deck.some(c => c.id === card.id)) group.draw++;
    if (G.discard.some(c => c.id === card.id)) group.discard++;
    if (G.seat?.tables.some(t => t.cards.some(c => c.id === card.id))) group.table++;
  }
  const suitOrder = SUITS.map(s=>s.sym), rankOrder = RANKS.map(r=>r[0]);
  const rows = [...groups.values()].sort((a,b)=>suitOrder.indexOf(a.card.suit)-suitOrder.indexOf(b.card.suit)||rankOrder.indexOf(a.card.rank)-rankOrder.indexOf(b.card.rank));
  showOverlay('<div class="kicker">Состав колоды · порядок скрыт</div><h2>Оставшиеся карты</h2><div class="deck-toolbar"><button class="ghost" id="deck-close">Назад к игре</button></div><p class="sub">В колоде: '+G.deck.length+' · в сбросе: '+G.discard.length+'. Показывается количество, без порядка следующих карт.</p><div class="deck-book">'+rows.map(g=>'<div class="deck-book-card'+(!g.draw?' exhausted':'')+'">'+cardElement(g.card,{mini:1})+'<b>'+g.draw+' / '+g.total+'</b><small>сброс '+g.discard+' · стол '+g.table+'</small>'+(g.card.mod?'<small>'+MODS[g.card.mod].name+'</small>':'')+'</div>').join('')+'</div>',true);
  $('#deck-close').onclick = closeOverlay;
}

function reserveItem(index) {
  const item = G.shop?.items[index];
  if (G.phase !== 'shop' || !item || item.sold || !['joker','cons','up','mod'].includes(item.kind)) return;
  // Exactly one reserve. Selecting another replaces the old choice for free.
  G.shop.items.forEach(it => it.reserved = it === item && !item.reserved);
  renderShop(); saveRun();
}
function carryReservedItem() {
  G.reservedItem = G.shop?.items.find(item => item.reserved && !item.sold) || null;
  if (G.reservedItem) G.reservedItem = {...G.reservedItem,reserved:false};
}
function addReservedOffer(items) {
  const reserved = G.reservedItem;
  G.reservedItem = null;
  if (!reserved) return items;
  if (reserved.kind === 'joker' && G.jokers.some(j=>j.id===reserved.joker.id)) return items;
  if (reserved.kind === 'mod') {
    reserved.card = G.runDeck.find(card=>card.id===reserved.card.id);
    if (!reserved.card || reserved.card.mod) return items;
  }
  if (reserved.kind === 'up' && !G.runDeck.some(card=>card.rank===reserved.rank && (card.up||0)<3)) return items;
  const filtered = items.filter(item=>!(item.kind==='joker' && reserved.kind==='joker' && item.joker.id===reserved.joker.id));
  return [{...reserved,reserved:true,carried:true},...filtered];
}

function transferTargets(s, source) {
  return s.tables.map((table,index)=>({table,index})).filter(({table,index})=>index!==source&&!table.blocked&&table.cards.length<maxPlay());
}
function showTransferPicker(s, source = null) {
  const from = source && s.tables[source.table]?.cards[source.card];
  const content = from ? '<p class="sub">Куда перенести '+from.rank+from.suit+' со стола '+(source.table+1)+'?</p><div class="transfer-targets">'+transferTargets(s,source.table).map(({table,index})=>{
    const preview=previewConsumable(s,s.sel,source.table,source.card,index);
    return '<button class="evt-btn" data-move-to="'+index+'"><b>Стол '+(index+1)+'</b><span>'+previewText(preview,source.table,index)+'</span></button>';
  }).join('')+'</div>' : '<p class="sub">Выбери карту. Затем выбери стол назначения. Перенос не расходует ход.</p>'+s.tables.map((table,ti)=>table.blocked||!table.cards.length||!transferTargets(s,ti).length?'':'<section class="remove-group"><h3>Стол '+(ti+1)+'</h3><div class="remove-grid">'+table.cards.map((card,ci)=>'<button class="remove-card" data-move-from="'+ti+'" data-move-card="'+ci+'" aria-label="Перенести '+card.rank+card.suit+' со стола '+(ti+1)+'">'+cardElement(card,{mini:1})+'</button>').join('')+'</div></section>').join('');
  showOverlay('<div class="kicker">Расходник · перенос</div><h2>'+(from?'Выбери стол':'Какую карту перенести?')+'</h2>'+content+'<div class="row-btns">'+(from?'<button class="ghost" id="move-back">Другая карта</button>':'')+'<button class="ghost" id="move-cancel">Отмена</button></div>');
  $('#move-cancel').onclick=()=>{if(G.seat===s)s.sel=null;hideOverlay();render()};
  if($('#move-back'))$('#move-back').onclick=()=>showTransferPicker(s);
  document.querySelectorAll('[data-move-from]').forEach(button=>button.onclick=()=>showTransferPicker(s,{table:Number(button.dataset.moveFrom),card:Number(button.dataset.moveCard)}));
  document.querySelectorAll('[data-move-to]').forEach(button=>button.onclick=()=>movePlayedCard(s,source.table,source.card,Number(button.dataset.moveTo)));
}
function movePlayedCard(s, fromIndex, cardIndex, toIndex) {
  if(G.phase!=='play'||G.seat!==s||s.locked)return;
  const i=s.sel,item=G.cons[i],from=s.tables[fromIndex],to=s.tables[toIndex];
  if(item?.kind!=='move'||!from||from.blocked||!from.cards[cardIndex]||!to||toIndex===fromIndex||to.blocked||to.cards.length>=maxPlay()||bossIs('nocons')||(bossIs('thin')&&s.used))return;
  from.adj=removedCardAdj(from.adj,cardIndex,from.cards.length);
  const card=from.cards.splice(cardIndex,1)[0];to.cards.push(card);
  for(const table of [from,to]){table.dead=false;table.stood=false;table.locked=false}
  s.used=true;G.consUsed=(G.consUsed||0)+1;
  if(hasJoker('alchemist')&&Math.random()<.35)log('Алхимик: «Перенос» сохранён','gold');
  else G.cons.splice(i,1);
  s.sel=null;hideOverlay();refreshTables(s);
  log('Перенос '+card.rank+card.suit+': стол '+(fromIndex+1)+' → '+(toIndex+1),'gold');
  render();tgHaptic('light');autoFinish(s);
}

function initRunFeatures() {
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='hidden')saveRun()});
  window.addEventListener('pagehide',saveRun);
  $('#dealer').addEventListener('click',event=>{if(event.target.closest('.pile'))showDeckBook()});
  $('#dealer').addEventListener('keydown',event=>{if((event.key==='Enter'||event.key===' ')&&event.target.closest('.pile')){event.preventDefault();event.stopPropagation();showDeckBook()}});
}

function renderTargetCycle() {
  const el = document.querySelector('#target-cycle');
  const changing = G.boss === 'pendulum' || G.boss2 === 'pendulum';
  el.hidden = !changing || !['intro','play'].includes(G.phase);
  if (el.hidden) return;
  const turn = G.battle?.turn || 0;
  // The outgoing turn keeps its target until the next hand is created.
  const nextTurn = G.battle?.resolving ? turn : turn + 1;
  const result = G.seat && !G.battle?.resolving ? evalSeat(G.seat) : null;
  const phoenix = result && hasJoker('phoenix') && !G.phoenixUsed && result.total === 0 && result.bust;
  const spent = seatsCount() - G.seatsLeft + (G.battle?.resolving || phoenix ? 0 : 1);
  const next = limitForTurn(nextTurn, spent);
  el.innerHTML = '<b>Маятник · цель сейчас '+limitNow()+'</b><span>21 → 18 → 25 → 21 · следующая цель: '+next+'</span>'+
    (!(G.seat?.pendulum ?? bossIs('pendulum')) ? '<small>Дипломат отключил правило: действует обычная цель.</small>' : '');
}
