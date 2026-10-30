/* Illustrated campaign transitions. All decisions still use the existing run state. */
const Passage={
 icon(key){const paths={back:'<path d="m15 5-7 7 7 7"/>',next:'<path d="m9 5 7 7-7 7"/>',check:'<path d="m6 12 4 4 8-9"/>',heart:'<path d="M12 20 3.5 11.5C-2 5 7 0 12 6c5-6 14-1 8.5 5.5Z" fill="currentColor" stroke="none"/>',target:'<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><path d="m12 12 9-9m-5 0h5v5"/>',shield:'<path d="M12 2 3 6v6c0 5 9 10 9 10s9-5 9-10V6Z"/><path d="M12 5v13"/>',cards:'<rect x="6" y="4" width="13" height="18" rx="2"/><path d="M4 19 1 4l12-2m-1 9 3 4-3 4-3-4Z"/>',clock:'<path d="M6 3h12M6 21h12M8 3v4l8 10v4M16 3v4L8 17v4"/>'};return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'+(paths[key]||paths.next)+'</svg>';},
 face(index){return '--passage-x:'+((index%5)*25)+'%;--passage-y:'+Math.floor(index/5)*100+'%;';},
 stopArt(key){const i=({rest:0,campfire:1,straight:2,event:3,elite:4,contract:5,bargain:5})[key]??2;return '<span class="passage-stop-art" style="--stop-x:'+((i%3)*50)+'%;--stop-y:'+Math.floor(i/3)*100+'%" aria-hidden="true"></span>';},
 copy(key){return ({rest:'Восстановить до 20 HP или получить 8 щита.',campfire:'Удалить, улучшить, скопировать карту или сменить масть.',straight:'Без остановки · +$2',event:'Случайная встреча: риск или выгода.',elite:'HP ×1,35 · атаки +20% · реликвия и +$5.',contract:'Усложнение боя за дополнительную награду.',bargain:'Сильный бонус за постоянный недостаток.'})[key]||NODES[key].desc;},
 nav(label){return '<div class="passage-nav"><button type="button" class="passage-menu" aria-label="Главное меню. Забег сохранится">'+this.icon('back')+'<span>Меню</span></button><span>'+label+'</span></div>';},
 path(picks){
  const level=G.level||1,previous=DUNGEON_LEVELS[level-2],next=Campaign.level();
  return '<div class="passage-screen passage-route path-screen" data-passage-screen="route">'+
   '<div class="passage-route-scene">'+this.nav('Темница · '+(previous?'после боя '+(level-1):'начало пути'))+'<header class="passage-heading"><h2>Глубже в темницу</h2><p class="passage-completed">'+this.icon('check')+(previous?previous.name+' побеждён':'Первый шаг к свободе')+'</p></header>'+
   '<div class="passage-route-ribbon" aria-label="Путь к выходу: следующий бой '+level+' из 10"><span>Путь<br>к выходу</span><ol>'+DUNGEON_LEVELS.map((d,i)=>'<li class="'+(i+1<level?'complete':i+1===level?'current':'waiting')+'" '+(i+1===level?'aria-current="step"':'')+' aria-label="'+(i+1)+'. '+d.name+(i+1<level?' — пройден':i+1===level?' — следующий бой':'')+'"><i>'+(i+1<level?this.icon('check'):'')+'</i></li>').join('')+'</ol></div></div>'+
   '<div class="passage-route-body"><section class="passage-next"><span class="passage-face" aria-hidden="true" style="'+this.face(level-1)+'"></span><div><h3>Далее: '+next.name+'</h3><p>Уровень '+level+' / 10</p></div>'+this.icon('next')+'</section><h3 class="passage-section-title">Выбери остановку</h3><div class="passage-choices route-options">'+picks.map(key=>'<button type="button" class="passage-choice" data-node="'+key+'">'+this.stopArt(key)+'<span class="passage-choice-copy"><b>'+(key==='straight'?'Идти дальше':NODES[key].name)+'</b><span>'+this.copy(key)+'</span></span>'+this.icon('next')+'</button>').join('')+'</div>'+
   (picks.includes('elite')?'<details class="passage-extra"><summary>Правило элитного боя</summary><p>'+eliteRouteText()+'</p></details>':'')+
   '<p class="passage-footnote">'+this.icon('clock')+'<span>Следующий бой начнётся после выбора пути.</span></p></div></div>';
 },
 intro(){
  const enemy=G.enemy,level=G.level||1,index=Number.isInteger(enemy.portraitIndex)?enemy.portraitIndex:level-1;
  const rules=[G.boss,G.boss2].filter(Boolean),relic=Campaign.relicOffer();
  const ruleHTML=rules.length?rules.map(key=>'<section class="passage-rule">'+this.icon('cards')+'<div><h3>'+BOSSES[key].name+'</h3><p>'+BOSSES[key].desc+'</p></div></section>').join(''):'<section class="passage-rule">'+this.icon('cards')+'<div><h3>Особенность противника</h3><p>'+(enemyTrait()||'Собирай очки на столах и победи противника до конца ходов.')+'</p></div></section>';
  const reward=level===10?'Выход из Темницы':relic?'Реликвия'+(G.elite?' и +$5':''):'Деньги и магазин';
  return '<div class="passage-screen passage-intro battle-brief" data-passage-screen="intro">'+this.nav('Темница · уровень '+level+' / 10')+'<header class="passage-heading"><h2>За следующей дверью</h2></header>'+
   '<div class="passage-enemy-scene"><span class="passage-enemy-portrait" style="'+this.face(index)+'" aria-hidden="true"></span><div class="passage-enemy-caption"><span>'+(G.elite?'Элитный противник':enemy.type==='boss'?'Последний страж':enemy.type==='mini'?'Опасный противник':'Следующий противник')+'</span><h3>'+enemy.name+'</h3></div></div>'+
   '<div class="passage-intro-body"><div class="passage-stats brief-stats"><div>'+this.icon('heart')+'<span><small>Здоровье</small><b>'+fmt(enemy.hp)+'</b></span></div><div>'+this.icon('target')+'<span><small>Цель</small><b>'+limitNow()+'</b></span></div><div>'+this.icon('shield')+'<span><small>Броня</small><b>'+(enemy.armor?Math.round(enemy.armor*100)+'%':'—')+'</b></span></div></div><p class="passage-turn-limit">На бой: <b>'+seatsCount()+' хода</b></p>'+ruleHTML+
   (G.contract?'<section class="passage-rule"><div><h3>Контракт: '+G.contract.name+'</h3><p>'+G.contract.desc+' Награда: +$'+G.contract.reward+'.</p></div></section>':'')+
   '<section class="passage-reward">'+itemArt('relic',relic?'revive':'coins')+'<div><small>Награда за победу</small><b>'+reward+'</b></div></section>'+
   '<div class="passage-cta"><button type="button" class="primary" id="ov-start">Войти в бой</button></div><details class="passage-preparation"><summary>Подготовиться '+this.icon('next')+'</summary><div class="passage-preparation-content">'+(G.fairStart?'<p>Честный старт: бонусы лавки отключены.</p>':'')+talentSummary()+bargainSummary()+tableFeaturesSummary(true)+(rules.length&&enemyTrait()?'<p>'+enemyTrait()+'</p>':'')+'<p>'+tablesPerSeat()+' стола за ход. Добор и остановка стола не тратят ход.</p><button type="button" class="ghost" id="ov-rules">Правила боя</button></div></details></div></div>';
 },
 decorate(){
  const root=document.querySelector('#overlay [data-passage-screen]');if(!root)return;
  root.closest('.modal').classList.add('passage-modal');
  root.querySelector('.passage-menu').onclick=()=>{FastDraw.flush();saveRun();newGame();};
 },
 preload(){if(this.images)return;this.images=['passage-corridor.webp','passage-stops.webp'].map(file=>{const image=new Image();image.src='assets/'+file;return image;});}
};
