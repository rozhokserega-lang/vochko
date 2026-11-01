/* Chapter progression is separate from legacy ante/stake runs. */
const CHAPTERS=[
 {id:'dungeon',name:'Темница',ready:true,desc:'Десять уровней до свободы. Выбери колоду и победи начальника темницы.'},
 {id:'club',name:'Подпольный клуб',ready:true,prototype:true,desc:'Пробная глава · 3 боя. Выигрывай дополнительные ходы и используй уязвимости.'},
 {id:'house',name:'Игорный дом',ready:false,desc:'Профессиональные игроки и сочетания особенностей столов.'},
 {id:'salon',name:'Закрытый салон',ready:false,desc:'Дорогие возможности, сильные сборки и опасные сделки.'},
 {id:'owner',name:'Казино хозяина',ready:false,desc:'Последняя глава: испытание освоенных механик.'}
];
const DUNGEON_LEVELS=[
 {name:'Крысолов',enemy:'collector',hp:1800,blind:0},
 {name:'Надзиратель',enemy:'brawler',hp:2400,blind:0},
 {name:'Камерный шулер',enemy:'collector',hp:3000,blind:0},
 {name:'Ключник',enemy:'sentinel',hp:4300,blind:1,rule:'max3',relic:true},
 {name:'Скупщик',enemy:'collector',hp:5100,blind:0},
 {name:'Тюремный лекарь',enemy:'usurer',hp:6200,blind:1},
 {name:'Смотритель',enemy:'sentinel',hp:7300,blind:0},
 {name:'Палач',enemy:'brawler',hp:8400,blind:1,rule:'hot',elite:true,relic:true},
 {name:'Страж ворот',enemy:'sentinel',hp:9800,blind:0},
 {name:'Начальник темницы',enemy:'jailer',hp:13000,blind:2,rule:'pendulum'}
];
const CLUB_LEVELS=[
 {name:'Уличный зазывала',enemy:'club_host',hp:2940,blind:0,portrait:0,attack:23},
 {name:'Ловкач',enemy:'club_cheat',hp:5760,blind:1,portrait:2,attack:30,relic:true},
 {name:'Хозяин клуба',enemy:'club_boss',hp:9200,blind:2,portrait:4,attack:38}
];
const Campaign={
 active(){return !!G?.campaign;},
 progress(){if(!META.campaign)META.campaign={unlocked:0,completed:[],bestLevels:{}};META.campaign.completed= META.campaign.completed||[];META.campaign.bestLevels=META.campaign.bestLevels||{};return META.campaign;},
 club(game=G){return !!game?.campaign&&game.chapter===1;},
 levels(game=G){return this.club(game)?CLUB_LEVELS:DUNGEON_LEVELS;},
 name(game=G){return this.club(game)?'Подпольный клуб':'Темница';},
 final(){return G.level===this.levels().length;},
 level(){const levels=this.levels();return levels[Math.max(0,Math.min(levels.length-1,(G.level||1)-1))];},
 label(game=G){return game?.campaign?this.name(game)+' · уровень '+game.level+' / '+this.levels(game).length:'Этап '+game.ante;},
 savedLabel(game){return game.campaign?this.label(game)+' · '+game.player.hp+' HP':'Старый забег · этап '+game.ante+' · '+BLIND_SHORT[game.blind]+' · '+game.player.hp+' HP';},
 prepare(){if(!this.active())return;G.chapter=this.club()?1:0;G.level=Math.max(1,Math.min(this.levels().length,G.level||1));G.ante=1+Math.floor((G.level-1)/3);G.blind=this.level().blind;},
 elite(){return this.active()&&!!this.level().elite;},
 applyRule(){if(this.club()){G.boss=null;G.boss2=null;return;}if(this.active()&&this.level().rule){G.boss=this.level().rule;G.boss2=null;lastBoss=G.boss;}},
 healOpen(){if(this.club())return G.level>=1;return this.active()?[4,8,9,10].includes(G.level)||G.elite:null;},
 relicOffer(){return this.active()?(!this.final()&&(!!this.level().relic||G.elite)):((G.blind===2&&(G.ante<CONFIG.maxAnte||G.endless))||G.elite);},
 target(){return this.active()?this.level().hp:null;},
 preloadPortraits(){if(!this.portraits){this.portraits=new Image();this.portraits.src='assets/dungeon-opponents.webp';if(this.portraits.decode)this.portraits.decode().catch(()=>{});}},
 portraitStyle(){const i=Number.isInteger(G.enemy?.portraitIndex)?G.enemy.portraitIndex:(G.level||1)-1;return '--dungeon-x:'+((i%5)*25)+'%;--dungeon-y:'+Math.floor(i/5)*100+'%;';},
 next(){
  if(!this.active()||G.phase!=='shop')return;
  carryReservedItem();hideOverlay();if(this.final()){this.victory();return;}
  G.level++;this.prepare();openPath();
 },
 pathWeights(weights){if(this.club()){delete weights.elite;delete weights.contract;}if(this.active()&&this.level().rule){delete weights.elite;delete weights.contract;}return weights;},
 adjustPath(picks){return this.active()&&this.final()?['rest','campfire','straight']:picks;},
 install(){
  const create=Enemy.create;Enemy.create=function(){
   if(!Campaign.active())return create.call(this);
   const level=Campaign.level(),def=ENEMIES.find(e=>e.id===level.enemy)||{id:'jailer',moves:['attack','guard','heavy','rage']};
   return {...def,name:level.name,id:level.enemy,glyph:def.glyph||'♚',portraitIndex:level.portrait??G.level-1,type:Campaign.final()?'boss':(level.blind===1||G.elite?'mini':'normal'),hp:G.target,maxHp:G.target,shield:0,armor:level.enemy==='sentinel'?COMBAT.armor:0,phase:1,effects:[],intent:null};
  };
 },
 renderHUD(){
  const active=this.active();document.body.classList.toggle('campaign-run',active);document.body.classList.toggle('club-run',this.club());
  $('#hud-ante').closest('.pill').querySelector('.label').textContent=active?'Уровень':'Этап';
  $('#hud-blind').closest('.pill').querySelector('.label').textContent=active?'Локация':'Бой';
  if(active){$('#hud-ante').textContent=G.level+'/'+this.levels().length;$('#hud-blind').textContent=this.name();}
  if(active){const i=Number.isInteger(G.enemy?.portraitIndex)?G.enemy.portraitIndex:G.level-1;$('#enemy-portrait').style.setProperty('--dungeon-x',(i%5)*25+'%');$('#enemy-portrait').style.setProperty('--dungeon-y',Math.floor(i/5)*100+'%');}
  let track=$('#campaign-track');if(!active){track?.remove();return;}
  if(!track){track=document.createElement('div');track.id='campaign-track';track.className='campaign-track';$('#table-supplies').insertAdjacentElement('beforebegin',track);}
  track.setAttribute('aria-label',this.name()+'. Уровень '+G.level+' из '+this.levels().length);
  track.innerHTML=this.levels().map((l,i)=>'<span class="'+(i+1<G.level?'done':i+1===G.level?'current':'')+(l.rule?' special':'')+'" title="'+(i+1)+'. '+l.name+'">'+(i+1)+'</span>').join('');
 },
 locations(){
  this.preloadPortraits();const progress=this.progress();GameMenu.backTarget='home';G.pending='setup';
  const best=Math.min(10,progress.bestLevels[0]||0);
  showOverlay('<div class="location-screen"><button class="menu-back" id="locations-back">← Главное меню</button><header><div class="kicker">Пять ступеней к хозяину казино</div><h2>Путь к свободе</h2><p class="sub">Начни в Темнице. Пройди 10 боёв, чтобы открыть следующую главу.</p></header><section class="location-hero"><div class="location-hero-copy"><span class="location-label">Глава I · доступна</span><h3>Темница</h3><p>Десять противников. Одна дверь на свободу.</p><div class="location-progress"><span>Лучший результат</span><b>'+best+' / 10</b></div><div class="location-steps" aria-label="Рекорд '+best+' из 10">'+Array.from({length:10},(_,i)=>'<i class="'+(i<best?'done':'')+'"></i>').join('')+'</div><button class="home-start" data-chapter="0">Выбрать колоду <span aria-hidden="true">→</span></button></div></section><div class="location-next-label">Дальше по пути</div><div class="location-path">'+CHAPTERS.slice(1).map((c,index)=>{const i=index+1,unlocked=i<=progress.unlocked;if(unlocked&&c.ready)return '<section class="location-locked location-playable"><span class="location-node">II</span><div><h3>'+c.name+'</h3><p>'+c.desc+'</p><small>Лучший результат: '+Math.min(3,progress.bestLevels[1]||0)+' / 3 · пробная глава</small><button class="home-start" data-chapter="1">Войти в клуб →</button></div></section>';return '<section class="location-locked"><span class="location-node" aria-hidden="true">'+['II','III','IV','V'][index]+'</span><div><h3>'+c.name+'</h3><p>'+c.desc+'</p><small>'+(unlocked?'Открыто · содержимое готовится':'После главы «'+CHAPTERS[i-1].name+'»')+'</small></div><span class="location-lock">'+(unlocked?'Скоро':'Закрыто')+'</span></section>';}).join('')+'</div></div>',true);
  $('#overlay .modal').classList.add('location-menu');
  document.querySelectorAll('[data-chapter]').forEach(button=>button.onclick=()=>{const chapter=Number(button.dataset.chapter);if(chapter>progress.unlocked||!CHAPTERS[chapter]?.ready)return;SETUP.chapter=chapter;GameMenu.setup();});$('#locations-back').onclick=()=>GameMenu.main();tgShowBack(true);
 },
 setupHTML(){return '<div class="campaign-choice"><div><small>Локация 1 из 5</small><b>Темница · 10 уровней</b></div><button class="ghost" id="setup-location">Карта локаций</button></div>';},
 recordEnd(win){
  if(G.metaDone)return;G.metaDone=true;const p=this.progress(),key=G.chapter||0;
  META.stats.runs++;if(win)META.stats.wins++;META.stats.bestScore=Math.max(META.stats.bestScore,G.stats.bestSeat);p.bestLevels[key]=Math.max(p.bestLevels[key]||0,G.level);
  const pts=Math.floor((G.runPoints||0)/1000),levels=G.stats.blinds*2,winB=win?15:0,total=pts+levels+winB;META.shop.coins+=total;G.coinInfo={points:G.runPoints||0,pts,antes:levels,winB,mult:1,total};
  if(G.daily){const r=META.daily[G.daily],prog=G.stats.blinds;if(!r||prog>r.prog)META.daily[G.daily]={prog,level:G.level,chapter:G.chapter||0,win,best:G.stats.bestSeat};}
  metaSave();
 },
 victory(){
  if(!this.active()||G.phase!=='shop'||!this.final()||G.enemy?.hp>0)return;G.phase='won';if(this.club()){const p=this.progress();p.clubPrototypeCleared=true;p.bestLevels[1]=3;this.recordEnd(true);metaSave();tgClosingConfirmation(false);render();const game=G;setTimeout(()=>{if(G===game&&G.phase==='won')this.showVictory();},350);return;}const p=this.progress();if(!p.completed.includes(0))p.completed.push(0);p.unlocked=Math.max(1,p.unlocked||0);p.bestLevels[0]=10;G.unlockedChapter=1;unlockAch('win');this.recordEnd(true);metaSave();tgClosingConfirmation(false);render();const game=G;
  setTimeout(()=>{if(G===game&&G.phase==='won')this.showVictory();},350);
 },
 showVictory(){
  if(this.club()){
   showOverlay('<div class="campaign-exit"><div class="kicker">Подпольный клуб · 3 из 3</div><h2>Клуб пройден</h2><p class="sub">Три пробных боя завершены. Полная глава будет состоять из десяти боёв; Игорный дом пока закрыт.</p><div class="stat-line"><span>Лучший ход</span><b>'+fmt(G.stats.bestSeat)+'</b></div>'+coinSummaryHTML()+'<div class="row-btns"><button class="primary" id="campaign-map">Карта локаций</button><button class="ghost" id="campaign-home">Главное меню</button></div></div>');
   $('#campaign-map').onclick=()=>this.locations();$('#campaign-home').onclick=()=>newGame();return;
  }
  showOverlay('<div class="campaign-exit"><div class="kicker">Темница · 10 из 10</div><h2>Дверь открыта</h2><p class="sub">Начальник темницы повержен. Ты выбрался из подземелья.</p><div class="chapter-unlocked"><b>Открыт Подпольный клуб</b><p>Следующая глава сохранена в прогрессе. Доступна пробная версия: три боя с новыми приёмами и дополнительным ходом за условие.</p></div><div class="stat-line"><span>Боёв пройдено</span><b>'+G.stats.blinds+' / 10</b></div><div class="stat-line"><span>Лучший ход</span><b>'+fmt(G.stats.bestSeat)+'</b></div>'+coinSummaryHTML()+'<div class="row-btns"><button class="primary" id="campaign-map">Карта локаций</button><button class="ghost" id="campaign-home">Главное меню</button></div></div>');
  $('#campaign-map').onclick=()=>this.locations();$('#campaign-home').onclick=()=>newGame();
 },
 showLoss(){
  showOverlay('<div class="kicker">'+this.label()+'</div><h2>Попытка окончена</h2><p class="sub">'+(G.lossReason||'Начни новую попытку. Открытия и покупки сохранены.')+'</p><div class="stat-line"><span>Побеждено противников</span><b>'+G.stats.blinds+' / '+this.levels().length+'</b></div>'+lossReviewHTML()+coinSummaryHTML()+'<div class="row-btns"><button class="primary" id="campaign-retry">Новая попытка</button><button class="ghost" id="campaign-home">Главное меню</button></div>');
  $('#campaign-retry').onclick=()=>{SETUP.chapter=G.chapter||0;GameMenu.setup();};$('#campaign-home').onclick=()=>newGame();
 },
 rules(){
  if(this.club()){
   showOverlay('<div class="kicker">Подпольный клуб · пробная глава</div><h2>Три боя в клубе</h2><div class="rules"><p>Каждый бой начинается с четырьмя ходами. Зазывала атакует на 23, Ловкач — на 30, хозяин — на 38 HP. Переборы по-прежнему причиняют дополнительный урон.</p><p>У Ловкача один раз за бой собери в одном розыгрыше два стола с суммой от цели −2 до цели: получишь дополнительный ход. Остальные столы могут быть пустыми или перебранными.</p><p>Хозяин чередует стойки. В защите он получает щит после твоего удара. В открытой стойке указанный стол получает +60% урона, хозяин атакует. Стойка и стол показаны до добора.</p><p>После первого и второго боёв доступны магазин и остановка. После Ловкача — реликвия и гарантированный выбор отдыха или кузницы перед боссом. Это короткая пробная глава, её победа пока не открывает Игорный дом.</p></div><button class="primary" id="ov-close">Понятно</button>');$('#ov-close').onclick=closeOverlay;return;
  }
  showOverlay('<div class="kicker">Путь из Темницы</div><h2>Десять уровней до свободы</h2><div class="rules"><p>Пройди 10 уровней и победи начальника темницы. Каждая из пяти локаций — отдельный забег. Победа навсегда открывает следующую локацию, поражение возвращает к началу текущей.</p><p>На ход — три стола, четвёртый можно купить. Добор кладёт карту на первый открытый стол. «Стоп на столе» переводит добор дальше, «Сыграть ход» наносит общий урон. Обычно на бой 4 хода.</p><p>Не превышай цель карт. Расходники исправляют сумму, удаляют и переносят карты. Красные столы из трёх карт лечат, чёрные бьют сильнее. Талант и джокеры определяют сборку.</p><p>После каждого уровня, кроме финала, — магазин и одна остановка. После уровней 4 и 8 даётся реликвия. Лечение доступно после 4, 8 и 9, а также после добровольной элиты. Перед уровнем 10 гарантирован выбор отдыха или кузницы.</p><p>Старые забеги можно продолжить до конца по прежним правилам. Ежедневный забег проходит в Темнице без стартовых покупок лавки. После Темницы доступна пробная глава «Подпольный клуб» из трёх боёв. Остальные главы пока готовятся.</p></div><div class="row-btns"><button class="primary" id="ov-close">Понятно</button></div>');$('#ov-close').onclick=closeOverlay;
 }
};
