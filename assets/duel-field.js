/* Compact inventories keep the battle field stable at every inventory size. */
const DuelField={
 consumables(){
  if(G.phase!=='play'||!G.seat||G.seat.locked)return;
  showOverlay('<div class="inventory-screen"><div class="kicker">Карманные средства</div><h2>Расходники</h2><p class="sub">Выбери предмет. Для направленного эффекта затем нажми на нужный стол.</p><div class="duel-inventory">'+G.cons.map((c,i)=>'<button class="inventory-item" data-inventory-cons="'+i+'">'+itemArt('cons',Object.keys(CONS).find(id=>CONS[id]===c))+'<span><b>'+c.name+'</b><small>'+c.desc+'</small></span></button>').join('')+'</div><button class="ghost inventory-close">Вернуться к столам</button></div>');
  document.querySelectorAll('[data-inventory-cons]').forEach(b=>b.onclick=()=>{const i=Number(b.dataset.inventoryCons);hideOverlay();pickCons(i);});document.querySelector('.inventory-close').onclick=()=>hideOverlay();
 },
 jokers(){
  const bar=document.querySelector('#jokers-bar');if(!bar)return;
  let trigger=bar.querySelector('.joker-inventory-toggle');
  if(!trigger){trigger=document.createElement('button');trigger.type='button';trigger.className='joker-inventory-toggle';bar.prepend(trigger);}
  trigger.innerHTML='<span>Джокеры <b>'+G.jokers.length+' / '+maxJokers()+'</b></span><span class="joker-medallions" aria-hidden="true">'+G.jokers.slice(0,5).map(j=>itemArt('joker',j.id)).join('')+'</span><span aria-hidden="true">⌃</span>';
  trigger.setAttribute('aria-label','Открыть джокеры и эффекты забега');trigger.onclick=()=>this.showJokers();
 },
 showJokers(){
  showOverlay('<div class="inventory-screen"><div class="kicker">Твоя сборка · '+G.jokers.length+' / '+maxJokers()+'</div><h2>Джокеры</h2><div class="duel-inventory">'+(G.jokers.length?G.jokers.map(j=>'<article class="inventory-item r-'+j.rarity+'">'+itemArt('joker',j.id)+'<div><small class="inventory-rarity">'+RARITY[j.rarity].name+'</small><b>'+j.name+'</b><p>'+j.desc+'</p>'+growthTooltip(j.id)+(j.charges?'<small>Осталось ходов: '+j.charges+'</small>':'')+'</div></article>').join(''):'<p class="sub">Покупай джокеры в магазине между боями. Их эффекты действуют автоматически.</p>')+'</div><div class="inventory-build">'+talentSummary()+bargainSummary()+growthSummary()+tableFeaturesSummary()+CardMark.runSummary()+'</div><button class="ghost inventory-close">Вернуться к столам</button></div>');document.querySelector('.inventory-close').onclick=()=>hideOverlay();
 }
};
