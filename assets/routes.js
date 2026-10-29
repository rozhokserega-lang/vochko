/* Permanent run bargains and one-action rest stops. No timers or idle effects. */
const BARGAINS={
 velvet:{name:'Бархатное кресло',gain:'+1 слот джокера.',cost:'Все новые товары в магазинах дороже на $1. Отложенные ранее товары сохраняют цену.',can:()=>true,apply:()=>{G.slotJ=(G.slotJ||0)+1;}},
 blood:{name:'Цена крови',gain:'Сразу +$18.',cost:'Максимальное HP −25. Текущее HP обрезается до нового максимума; лечение этого не вернёт.',can:()=>G.player.maxHp>25,apply:()=>{G.player.maxHp-=25;G.player.hp=Math.min(G.player.hp,G.player.maxHp);G.money+=18;}},
 fury:{name:'Ярость должника',gain:'Общий урон каждого хода +20%.',cost:'Каждая атака врага сильнее на 2 до защиты. Штраф за перебор не меняется.',can:()=>true,apply:()=>{}},
 pockets:{name:'Бездонные карманы',gain:'+2 слота расходников.',cost:'Базовая награда за каждый выигранный бой −$1. Остальные награды не меняются.',can:()=>true,apply:()=>{G.slotC=(G.slotC||0)+2;}}
};
function hasBargain(id){return !!G?.bargains?.includes(id);}
function bargainSummary(){return G?.bargains?.length?'<details class="run-talent" data-run-panel="bargains"><summary>Сделки: '+G.bargains.length+'</summary>'+G.bargains.filter(k=>BARGAINS[k]).map(k=>'<p><b>'+BARGAINS[k].name+'</b><br>'+BARGAINS[k].gain+'<br><span class="bargain-cost">'+BARGAINS[k].cost+'</span></p>').join('')+'</details>':'';}
function openBargains(){
 G.phase='path';G.pending='bargains';G.bargainSelection=null;render();
 showOverlay(GameMenu.sceneHeader('contract','Сделка · до конца забега','У каждой выгоды есть цена','Можно заключить одну сделку за визит. Каждая доступна один раз за забег.')+
 '<div class="bargain-list">'+Object.entries(BARGAINS).filter(([id])=>!hasBargain(id)).map(([id,b])=>'<section class="bargain-card"><h3>'+b.name+'</h3><p class="bargain-gain">'+b.gain+'</p><p class="bargain-cost">'+b.cost+'</p><button class="buy" data-bargain="'+id+'" '+(!b.can()?'disabled':'')+'>Рассмотреть сделку</button></section>').join('')+'</div><div class="row-btns"><button class="ghost" id="bargain-leave">Отказаться и идти дальше</button></div>');
 document.querySelectorAll('[data-bargain]').forEach(b=>b.onclick=()=>confirmBargain(b.dataset.bargain));$('#bargain-leave').onclick=leaveNode;
}
function confirmBargain(id){
 const b=BARGAINS[id];if(G.pending!=='bargains'||!b||hasBargain(id)||!b.can())return;
 G.bargainSelection=id;saveRun();
 showOverlay(GameMenu.sceneHeader('contract','Подтверждение сделки',b.name)+ '<div class="bargain-card"><p class="bargain-gain">'+b.gain+'</p><p class="bargain-cost">'+b.cost+'</p><p>Оба эффекта действуют до конца этого забега. Отменить сделку нельзя.</p></div><div class="row-btns"><button class="ghost" id="bargain-back">Назад</button><button class="primary" id="bargain-accept">Заключить сделку</button></div>');
 $('#bargain-back').onclick=openBargains;$('#bargain-accept').onclick=()=>acceptBargain(id);
}
function acceptBargain(id){
 const b=BARGAINS[id];if(G.phase!=='path'||G.pending!=='bargains'||G.bargainSelection!==id||!b||hasBargain(id)||!b.can())return;
 G.bargains=G.bargains||[];G.bargains.push(id);b.apply();G.bargainSelection=null;
 log('Сделка: '+b.name,'gold');nodeResult('Сделка заключена',b.gain+' Цена: '+b.cost,'bargainDone');
}
function openRest(){
 G.phase='path';G.pending='rest';render();const actual=Math.min(20,G.player.maxHp-G.player.hp);
 showOverlay(GameMenu.sceneHeader('straight','Отдых · '+Campaign.label(),'Переведи дух','Выбери одно действие. Подготовленный щит действует только в следующем бою.')+
 '<div class="evt-list"><button class="evt-btn" id="rest-heal" '+(!actual?'disabled':'')+'>Восстановить '+actual+' HP<small>До 20 HP, без превышения максимума.</small></button><button class="evt-btn" id="rest-shield">Подготовиться: 8 щита<small>Получишь в начале следующего боя. Не переносится дальше.</small></button><button class="ghost" id="rest-leave">Пройти мимо</button></div>');
 $('#rest-heal').onclick=()=>takeRest('heal');$('#rest-shield').onclick=()=>takeRest('shield');$('#rest-leave').onclick=leaveNode;
}
function takeRest(kind){
 if(G.phase!=='path'||G.pending!=='rest')return;
 if(kind==='heal'){if(G.player.hp>=G.player.maxHp)return;const amount=Combat.heal(20,'rest');nodeResult('Отдых','Восстановлено '+amount+' HP.','restDone');}
 else if(kind==='shield'){G.nextRestShield=8;nodeResult('Подготовка','В следующем бою начнёшь с дополнительными 8 щита.','restDone');}
}
function eliteRouteText(){const boss=G.pathEliteBoss&&BOSSES[G.pathEliteBoss];return 'HP врага '+fmt(Math.round(targetFor(G.ante,G.blind)*1.35))+' (×1,35). Атаки +20%. '+(boss?'Правило: '+boss.name+' — '+boss.desc:'Правило босса.')+' Награда за победу: выбор реликвии и +$5 сверх обычной награды.';}
function forgeConfirm(id){
 if(G.forgeMode==='suit'){forgeSuitChoice(id);return;}
 if(G.phase!=='path'||G.pending!=='forge'||!['remove','upgrade','copy'].includes(G.forgeMode))return;
 const c=G.runDeck.find(c=>c.id===id);if(!c)return;
 const mode=G.forgeMode,preview={...c,up:(c.up||0)+(mode==='upgrade'?2:0)};
 const text=mode==='remove'?'Карта навсегда исчезнет из колоды. Карт останется: '+(G.runDeck.length-1)+'.':mode==='copy'?'В колоде появится точная копия, включая печать и улучшения. Карт станет: '+(G.runDeck.length+1)+'.':'Значение карты +2, чипы +20. Это также повышает риск перебора.';
 const allowed=mode==='remove'?G.runDeck.length>20:mode==='copy'?G.runDeck.length<60:c.mod!=='curse';
 G.forgeSelection=id;saveRun();
 showOverlay(GameMenu.sceneHeader('campfire','Кузница · подтверждение',({remove:'Удалить карту?',copy:'Скопировать карту?',upgrade:'Улучшить карту?'})[mode])+
 '<div class="forge-preview">'+cardElement(c,{mini:1})+(mode==='upgrade'?'<span aria-hidden="true">→</span>'+cardElement(preview,{mini:1}):'')+'</div><p class="forge-preview-label">'+text+'</p>'+(!allowed?'<p class="bargain-cost">'+(mode==='upgrade'?'Проклятую карту нельзя улучшить.':'Допустимый размер колоды — от 20 до 60 карт.')+'</p>':'')+'<div class="row-btns"><button class="ghost" id="forge-preview-back">Назад</button><button class="primary" id="forge-preview-accept" '+(!allowed?'disabled':'')+'>Подтвердить</button></div>');
 $('#forge-preview-back').onclick=()=>forgeAction(mode);$('#forge-preview-accept').onclick=()=>{if(G.forgeSelection!==id)return;forgeApply(id);};
}
