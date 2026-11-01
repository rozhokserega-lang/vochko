/* Chapter progression is separate from legacy ante/stake runs. */
const CHAPTERS=[
 {id:'dungeon',name:'Темница',ready:true,desc:'Десять уровней до свободы. Выбери колоду и победи начальника темницы.'},
 {id:'club',name:'Подпольный клуб',ready:true,desc:'Десять боёв против шулеров. Выигрывай ходы, раскрывай уязвимости и победи хозяина.'},
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
// Keep ongoing three-fight saves playable under their original rules.
const CLUB_PREVIEW_LEVELS=[
 {name:'Уличный зазывала',enemy:'club_host',mechanic:'host',hp:2940,blind:0,portrait:0,attack:23},
 {name:'Ловкач',enemy:'club_cheat',mechanic:'near',hp:5760,blind:1,portrait:2,attack:30,relic:true},
 {name:'Хозяин клуба',enemy:'club_boss',mechanic:'previewBoss',hp:9200,blind:2,portrait:4,attack:38,shield:260}
];
const CLUB_LEVELS=[
 {name:'Уличный зазывала',enemy:'club_host',mechanic:'host',hp:2100,blind:0,portrait:0,attack:16},
 {name:'Карманник',enemy:'club_pickpocket',mechanic:'pocket',hp:2750,blind:0,portrait:1,attack:14},
 {name:'Ловкач',enemy:'club_cheat',mechanic:'near',hp:4000,blind:0,portrait:2,attack:17},
 {name:'Старшая шулерка',enemy:'club_sharp',mechanic:'exact',hp:5200,blind:1,portrait:3,attack:22,relic:true},
 {name:'Скупщик фишек',enemy:'club_broker',mechanic:'deal',hp:6000,blind:0,portrait:4,attack:18},
 {name:'Костяшник',enemy:'club_dice',mechanic:'long',hp:7250,blind:0,portrait:5,attack:18,heavy:27},
 {name:'Шулерка с печаткой',enemy:'club_signet',mechanic:'red',hp:8800,blind:0,portrait:6,attack:21},
 {name:'Клубный вышибала',enemy:'club_bouncer',mechanic:'armor',hp:11000,blind:1,portrait:7,attack:22,armor:.1,relic:true},
 {name:'Сборщик долгов',enemy:'club_debt',mechanic:'debt',hp:12800,blind:0,portrait:8,attack:24},
 {name:'Хозяин клуба',enemy:'club_boss',mechanic:'boss',hp:17000,blind:2,portrait:9,attack:27,heavy:34,shield:900}
];
const Campaign={
 active(){return !!G?.campaign;},
 progress(){if(!META.campaign)META.campaign={unlocked:0,completed:[],bestLevels:{}};META.campaign.completed= META.campaign.completed||[];META.campaign.bestLevels=META.campaign.bestLevels||{};const p=META.campaign;
  if(!p.clubFullProgressVersion){if(p.clubPrototypeCleared||((p.bestLevels[1]||0)>0&&!p.completed.includes(1))){p.clubPrototypeBest=p.bestLevels[1]||(p.clubPrototypeCleared?3:0);p.bestLevels[1]=0;}p.clubFullProgressVersion=2;}
  return p;},
 club(game=G){return !!game?.campaign&&game.chapter===1;},
 prototype(game=G){return this.club(game)&&game.clubVersion!==2;},
 levels(game=G){return this.club(game)?(this.prototype(game)?CLUB_PREVIEW_LEVELS:CLUB_LEVELS):DUNGEON_LEVELS;},
 name(game=G){return this.club(game)?'Подпольный клуб':'Темница';},
 final(){return G.level===this.levels().length;},
 level(){const levels=this.levels();return levels[Math.max(0,Math.min(levels.length-1,(G.level||1)-1))];},
 label(game=G){return game?.campaign?this.name(game)+' · уровень '+game.level+' / '+this.levels(game).length:'Этап '+game.ante;},
 savedLabel(game){if(game.endlessFromStart)return Endless.label(game)+' · '+game.player.hp+' HP';return game.campaign?this.label(game)+(this.prototype(game)?' · старая пробная глава':'')+' · '+game.player.hp+' HP':'Старый забег · этап '+game.ante+' · '+BLIND_SHORT[game.blind]+' · '+game.player.hp+' HP';},
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
   return {...def,name:level.name,id:level.enemy,glyph:def.glyph||'♚',portraitIndex:level.portrait??G.level-1,type:Campaign.final()?'boss':(level.blind===1||G.elite?'mini':'normal'),hp:G.target,maxHp:G.target,shield:0,armor:level.armor??(level.enemy==='sentinel'?COMBAT.armor:0),phase:1,effects:[],intent:null};
  };
 },
 renderHUD(){
  const active=this.active();document.body.classList.toggle('campaign-run',active);document.body.classList.toggle('endless-run',!!G?.endlessFromStart);document.body.classList.toggle('club-run',this.club());document.body.classList.toggle('club-full',this.club()&&!this.prototype());
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
  SETUP.mode='campaign';
  this.preloadPortraits();const progress=this.progress();GameMenu.backTarget='home';G.pending='setup';
  const selected=Number.isInteger(SETUP.chapter)&&SETUP.chapter<=progress.unlocked?SETUP.chapter:Math.min(progress.unlocked,1);
  showOverlay('<div class="location-screen"><button class="menu-back" id="locations-back">← Главное меню</button><header><div class="kicker">Пять ступеней к хозяину казино</div><h2>Путь к свободе</h2><p class="sub">Выбери локацию. Победа в десяти боях открывает следующую главу.</p></header><div class="location-chapters">'+CHAPTERS.map((c,i)=>{
   const unlocked=i<=progress.unlocked,playable=unlocked&&c.ready,best=Math.min(10,progress.bestLevels[i]||0),label=playable?'Доступна':unlocked?'Скоро':'Закрыто';
   return '<details class="location-chapter '+c.id+'"'+(i===selected?' open':'')+'><summary><span class="location-node">'+['I','II','III','IV','V'][i]+'</span><span><b>'+c.name+'</b><small>'+label+(playable?' · '+best+' / 10':'')+'</small></span><span class="location-chevron" aria-hidden="true">⌄</span></summary><div class="location-hero"><div class="location-hero-copy"><span class="location-label">Глава '+['I','II','III','IV','V'][i]+' · '+label+'</span><h3>'+c.name+'</h3><p>'+c.desc+'</p>'+(playable?'<div class="location-progress"><span>Лучший результат</span><b>'+best+' / 10</b></div><div class="location-steps" aria-label="Рекорд '+best+' из 10">'+Array.from({length:10},(_,n)=>'<i class="'+(n<best?'done':'')+'"></i>').join('')+'</div><button class="home-start" data-chapter="'+i+'">Выбрать колоду <span aria-hidden="true">→</span></button>':'<p class="location-lock">'+(unlocked?'Содержимое главы готовится':'Откроется после главы «'+CHAPTERS[i-1].name+'»')+'</p>')+'</div></div></details>';
  }).join('')+'</div></div>',true);
  document.querySelectorAll('.location-chapter').forEach(panel=>panel.addEventListener('toggle',()=>{if(!panel.open)return;document.querySelectorAll('.location-chapter').forEach(other=>{if(other!==panel)other.open=false;});}));
  $('#overlay .modal').classList.add('location-menu');
  document.querySelectorAll('[data-chapter]').forEach(button=>button.onclick=()=>{const chapter=Number(button.dataset.chapter);if(chapter>progress.unlocked||!CHAPTERS[chapter]?.ready)return;SETUP.chapter=chapter;GameMenu.setup();});$('#locations-back').onclick=()=>GameMenu.main();tgShowBack(true);
 },
 setupHTML(){return '<div class="campaign-choice"><div><small>Локация 1 из 5</small><b>Темница · 10 уровней</b></div><button class="ghost" id="setup-location">Карта локаций</button></div>';},
 recordEnd(win){
  if(G.metaDone)return;G.metaDone=true;const p=this.progress(),key=G.chapter||0;
  META.stats.runs++;if(win)META.stats.wins++;META.stats.bestScore=Math.max(META.stats.bestScore,G.stats.bestSeat);if(this.prototype())p.clubPrototypeBest=Math.max(p.clubPrototypeBest||0,G.level);else p.bestLevels[key]=Math.max(p.bestLevels[key]||0,G.level);
  const pts=Math.floor((G.runPoints||0)/1000),levels=G.stats.blinds*2,winB=win?15:0,total=pts+levels+winB;META.shop.coins+=total;G.coinInfo={points:G.runPoints||0,pts,antes:levels,winB,mult:1,total};
  if(G.daily){const r=META.daily[G.daily],prog=G.stats.blinds;if(!r||prog>r.prog)META.daily[G.daily]={prog,level:G.level,chapter:G.chapter||0,win,best:G.stats.bestSeat};}
  metaSave();
 },
 victory(){
  if(!this.active()||G.phase!=='shop'||!this.final()||G.enemy?.hp>0)return;G.phase='won';if(this.prototype()){const p=this.progress();p.clubPrototypeCleared=true;p.clubPrototypeBest=3;this.recordEnd(true);metaSave();tgClosingConfirmation(false);render();const game=G;setTimeout(()=>{if(G===game&&G.phase==='won')this.showVictory();},350);return;}const p=this.progress(),chapter=G.chapter||0;if(!p.completed.includes(chapter))p.completed.push(chapter);p.unlocked=Math.max(chapter+1,p.unlocked||0);p.bestLevels[chapter]=10;G.unlockedChapter=chapter+1;unlockAch('win');this.recordEnd(true);metaSave();tgClosingConfirmation(false);render();const game=G;
  setTimeout(()=>{if(G===game&&G.phase==='won')this.showVictory();},350);
 },
 showVictory(){
  if(this.club()&&!this.prototype()){
   showOverlay('<div class="campaign-exit"><div class="kicker">Подпольный клуб · 10 из 10</div><h2>Хозяин остался без выигрыша</h2><p class="sub">Все десять противников побеждены. Пройденная глава сохранена.</p><div class="chapter-unlocked"><b>Открыт Игорный дом</b><p>Право входа сохранено. Следующая глава пока готовится; Подпольный клуб можно пройти другой сборкой.</p></div><div class="stat-line"><span>Боёв пройдено</span><b>'+G.stats.blinds+' / 10</b></div><div class="stat-line"><span>Лучший ход</span><b>'+fmt(G.stats.bestSeat)+'</b></div>'+coinSummaryHTML()+'<div class="row-btns"><button class="primary" id="campaign-map">Карта локаций</button><button class="ghost" id="campaign-home">Главное меню</button></div></div>');
   $('#campaign-map').onclick=()=>this.locations();$('#campaign-home').onclick=()=>newGame();return;
  }
  if(this.prototype()){
   showOverlay('<div class="campaign-exit"><div class="kicker">Подпольный клуб · 3 из 3</div><h2>Клуб пройден</h2><p class="sub">Старая пробная глава завершена по прежним правилам. На карте уже доступен полный клуб из десяти боёв. Эта попытка не открывает Игорный дом.</p><div class="stat-line"><span>Лучший ход</span><b>'+fmt(G.stats.bestSeat)+'</b></div>'+coinSummaryHTML()+'<div class="row-btns"><button class="primary" id="campaign-map">Карта локаций</button><button class="ghost" id="campaign-home">Главное меню</button></div></div>');
   $('#campaign-map').onclick=()=>this.locations();$('#campaign-home').onclick=()=>newGame();return;
  }
  showOverlay('<div class="campaign-exit"><div class="kicker">Темница · 10 из 10</div><h2>Дверь открыта</h2><p class="sub">Начальник темницы повержен. Ты выбрался из подземелья.</p><div class="chapter-unlocked"><b>Открыт Подпольный клуб</b><p>Следующая глава сохранена в прогрессе. Доступна полная глава: десять противников, дополнительные ходы, сделки и уязвимости.</p></div><div class="stat-line"><span>Боёв пройдено</span><b>'+G.stats.blinds+' / 10</b></div><div class="stat-line"><span>Лучший ход</span><b>'+fmt(G.stats.bestSeat)+'</b></div>'+coinSummaryHTML()+'<div class="row-btns"><button class="primary" id="campaign-map">Карта локаций</button><button class="ghost" id="campaign-home">Главное меню</button></div></div>');
  $('#campaign-map').onclick=()=>this.locations();$('#campaign-home').onclick=()=>newGame();
 },
 showLoss(){
  showOverlay('<div class="kicker">'+this.label()+'</div><h2>Попытка окончена</h2><p class="sub">'+(G.lossReason||'Начни новую попытку. Открытия и покупки сохранены.')+'</p><div class="stat-line"><span>Побеждено противников</span><b>'+G.stats.blinds+' / '+this.levels().length+'</b></div>'+lossReviewHTML()+coinSummaryHTML()+'<div class="row-btns"><button class="primary" id="campaign-retry">Новая попытка</button><button class="ghost" id="campaign-home">Главное меню</button></div>');
  $('#campaign-retry').onclick=()=>{SETUP.mode='campaign';SETUP.chapter=G.chapter||0;GameMenu.setup();};$('#campaign-home').onclick=()=>newGame();
 },
 rules(){
  if(this.club()&&!this.prototype()){Club.showRules();return;}
  if(this.prototype()){
   showOverlay('<div class="kicker">Подпольный клуб · пробная глава</div><h2>Три боя в клубе</h2><div class="rules"><p>Каждый бой начинается с четырьмя ходами. Зазывала атакует на 23, Ловкач — на 30, хозяин — на 38 HP. Переборы по-прежнему причиняют дополнительный урон.</p><p>У Ловкача один раз за бой собери в одном розыгрыше два стола с суммой от цели −2 до цели: получишь дополнительный ход. Остальные столы могут быть пустыми или перебранными.</p><p>Хозяин чередует стойки. В защите он получает щит после твоего удара. В открытой стойке указанный стол получает +60% урона, хозяин атакует. Стойка и стол показаны до добора.</p><p>После первого и второго боёв доступны магазин и остановка. После Ловкача — реликвия и гарантированный выбор отдыха или кузницы перед боссом. Это короткая пробная глава, её победа пока не открывает Игорный дом.</p></div><button class="primary" id="ov-close">Понятно</button>');$('#ov-close').onclick=closeOverlay;return;
  }
  showOverlay('<div class="kicker">Путь из Темницы</div><h2>Десять уровней до свободы</h2><div class="rules"><p>Пройди 10 уровней и победи начальника темницы. Каждая из пяти локаций — отдельный забег. Победа навсегда открывает следующую локацию, поражение возвращает к началу текущей.</p><p>На ход — три стола, четвёртый можно купить. Добор кладёт карту на первый открытый стол. «Стоп на столе» переводит добор дальше, «Сыграть ход» наносит общий урон. Обычно на бой 4 хода.</p><p>Не превышай цель карт. Расходники исправляют сумму, удаляют и переносят карты. Красные столы из трёх карт лечат, чёрные бьют сильнее. Талант и джокеры определяют сборку.</p><p>После каждого уровня, кроме финала, — магазин и одна остановка. После уровней 4 и 8 даётся реликвия. Лечение доступно после 4, 8 и 9, а также после добровольной элиты. Перед уровнем 10 гарантирован выбор отдыха или кузницы.</p><p>Старые забеги можно продолжить до конца по прежним правилам. Ежедневный забег проходит в Темнице без стартовых покупок лавки. После Темницы доступен «Подпольный клуб» из десяти боёв. Остальные главы пока готовятся.</p></div><div class="row-btns"><button class="primary" id="ov-close">Понятно</button></div>');$('#ov-close').onclick=closeOverlay;
 }
};
