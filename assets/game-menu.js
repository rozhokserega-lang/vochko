/* Dedicated title screen, focused run setup, and illustrated intermissions. */
const GameMenu={
 backTarget:null,
 routeArt(key){key=({rest:'straight',bargain:'contract'})[key]||key;const index=['event','campfire','elite','contract','straight'].indexOf(key);return '<span class="route-art" aria-hidden="true" style="--route-x:'+Math.max(0,index)*25+'%"></span>'},
 deckArt(key){
  const art={scarlet:['joker','crimson'],nocturne:['joker','blot'],classic:['joker','ace'],short:['cons','minus4'],gold:['relic','coins'],glass:['relic','revive'],alchemy:['joker','alchemist']}[key]||['joker','ace'];
  return itemArt(...art);
 },
 main(){
  G.pending='setup';this.backTarget='home';
  const saved=readSavedRun(),stats=META.stats;
  showOverlay('<div class="home-screen"><header class="home-identity"><span class="home-eyebrow">КАРТОЧНЫЙ ПОБЕГ</span><h1>ВОЧКО</h1><div class="home-ornament" aria-hidden="true">♠</div><p>Выберись из Темницы. Дойди до хозяина.</p></header>'+
   '<div class="home-card-fan" aria-hidden="true"><span class="home-playing-card card-left"><b>Q ♦</b><i style="--court:33.3333%"></i></span><span class="home-playing-card card-middle"><b>A ♠</b><i style="--court:100%"></i></span><span class="home-playing-card card-right"><b>K ♥</b><i style="--court:0%"></i></span></div>'+
   '<nav class="home-actions" aria-label="Главное меню">'+
   (saved?'<button class="home-start" id="ov-continue"><b>Продолжить</b><small>'+Campaign.savedLabel(saved.game)+'</small></button>':'')+
   '<button class="'+(saved?'home-secondary':'home-start')+'" id="menu-new-game">Новая игра</button>'+
   '<button class="home-secondary daily-action" id="menu-daily"><span>Ежедневный забег</span><small>Одна колода для всех</small></button>'+
   '<div class="home-links"><button id="menu-shop">'+itemArt('relic','coins')+'<span>Лавка</span></button><button id="menu-achievements">'+itemArt('relic','crown')+'<span>Достижения</span></button><button id="menu-rules">'+itemArt('joker','insurer')+'<span>Правила</span></button></div></nav>'+
   '<footer class="home-records"><span>Победы <b>'+stats.wins+'</b></span><span>Рекорд <b>'+(Campaign.progress().bestLevels[0]||0)+'/10'+'</b></span><span>Монеты <b>'+META.shop.coins+'</b></span></footer></div>',true);
  $('#overlay .modal').classList.add('game-home');
  if($('#ov-continue'))$('#ov-continue').onclick=()=>{this.backTarget=null;resumeRun()};
  $('#menu-new-game').onclick=()=>Campaign.locations();
  $('#menu-daily').onclick=()=>{this.backTarget=null;newGame(0,'classic',{daily:true,campaign:true})};
  $('#menu-shop').onclick=()=>this.page(()=>showMetaShop('seals'));
  $('#menu-achievements').onclick=()=>this.page(showMeta);
  $('#menu-rules').onclick=()=>this.page(showRules);
  Campaign.preloadPortraits();Passage.preload();
  tgShowBack(false);
 },
 page(open){
  this.backTarget='home';open();
  $('#overlay .modal')?.classList.add('game-menu-page');
  const back=$('#ov-back')||$('#ov-close');if(back)back.onclick=()=>this.main();
  tgShowBack(true);
 },
 setup(){
  const previousScroll=document.querySelector('.deck-selector')?.scrollLeft||0;
  G.pending='setup';this.backTarget='setup';
  const unlocked=unlockedStake();
  if(SETUP.stake>unlocked)SETUP.stake=unlocked;
  if(!isUnlocked('deck',SETUP.deck))SETUP.deck='classic';
  const deck=DECKS[SETUP.deck];
  if(!TALENTS[SETUP.talent]||!isUnlocked('talent',SETUP.talent))SETUP.talent='sharp';
  showOverlay('<div class="setup-screen"><button class="menu-back" id="setup-back">← К выбору главы</button><div class="kicker">Новый забег</div><h2>Твоя колода</h2><p class="sub">Выбери, с чем войдёшь в казино.</p>'+
   '<div class="chosen-deck"><span class="chosen-deck-art">'+this.deckArt(SETUP.deck)+'</span><div><h3>'+deck.name+'</h3><p>'+deck.desc+'</p></div></div>'+
   '<div class="deck-selector" aria-label="Выбор колоды">'+Object.entries(DECKS).sort(([a],[b])=>['classic','short','gold','glass','alchemy','scarlet','nocturne'].indexOf(a)-['classic','short','gold','glass','alchemy','scarlet','nocturne'].indexOf(b)).map(([key,value])=>{
    const enabled=isUnlocked('deck',key),selected=key===SETUP.deck;
    return '<button class="deck-option'+(selected?' selected':'')+'" data-deck="'+key+'" aria-pressed="'+selected+'" '+(!enabled?'disabled':'')+' title="'+(enabled?value.desc:lockHint('deck',key))+'">'+this.deckArt(key)+'<b>'+value.name+'</b><small>'+(enabled?(selected?'Выбрана':'Выбрать'):'Закрыта')+'</small></button>';
   }).join('')+'</div>'+
   '<h3 class="talent-heading">Стартовый талант</h3><div class="talent-options" aria-label="Выбор таланта">'+Object.entries(TALENTS).sort(([a],[b])=>['healer','sharp','daring','warden','scout'].indexOf(a)-['healer','sharp','daring','warden','scout'].indexOf(b)).map(([key,t])=>{const enabled=isUnlocked('talent',key);return '<button class="talent-option" data-talent="'+key+'" aria-pressed="'+(key===SETUP.talent)+'" '+(!enabled?'disabled':'')+'><span class="talent-mark" aria-hidden="true">'+t.mark+'</span><span><b>'+t.name+'</b><small>'+(enabled?(key===SETUP.talent?'Выбран':'Выбрать'):lockHint('talent',key))+'</small>'+'</span><span class="talent-check" aria-hidden="true">'+(key===SETUP.talent?'✓':!enabled?'·':'')+'</span></button>';}).join('')+'</div><div class="talent-current" aria-live="polite"><b>'+TALENTS[SETUP.talent].mark+' '+TALENTS[SETUP.talent].name+'</b>'+TALENTS[SETUP.talent].desc+'<small>'+TALENTS[SETUP.talent].hint+'</small></div><p class="talent-note">Один талант до конца забега. Не занимает слот джокера.</p>'+

   '<label class="fair-start"><input type="checkbox" id="setup-fair" '+(SETUP.fairStart?'checked':'')+'><span><b>Честный старт</b>Без стартовых денег, печатей, джокера и слотов из лавки. Открытые колоды и таланты доступны; покупки сохраняются.</span></label><p class="setup-openings">Новые варианты открываются за достижения. Купленные бонусы лавки не удаляются.</p><div class="setup-footer"><button class="home-start" id="ov-go">Начать забег</button>'+(readSavedRun()?'<small>Новый забег заменит текущее сохранение.</small>':'<small>Прогресс сохраняется автоматически.</small>')+'</div></div>');
  $('#overlay .modal').classList.add('game-setup');
  document.querySelector('.deck-selector').scrollLeft=previousScroll;
  $('#setup-back').onclick=()=>Campaign.locations();
  document.querySelectorAll('[data-deck]').forEach(button=>button.onclick=()=>{SETUP.deck=button.dataset.deck;this.setup()});


  $('#setup-fair').onchange=event=>{SETUP.fairStart=event.target.checked;};
  document.querySelectorAll('[data-talent]').forEach(button=>button.onclick=()=>{if(!isUnlocked('talent',button.dataset.talent))return;const modal=$('#overlay .modal'),scroll=modal.scrollTop;SETUP.talent=button.dataset.talent;this.setup();$('#overlay .modal').scrollTop=scroll;});
  $('#ov-go').onclick=()=>{this.backTarget=null;newGame(0,SETUP.deck,{campaign:true,talent:SETUP.talent,fairStart:!!SETUP.fairStart})};
  tgShowBack(true);
 },
 pathHTML(picks){
  if(Campaign.active())return Passage.path(picks);
  return '<div class="path-screen"><div class="kicker">'+Campaign.label()+' · между боями</div><h2>Выбери свой путь</h2><p class="sub">Впереди '+(Campaign.active()?Campaign.level().name:BLIND_NAMES[G.blind].toLowerCase())+'. Куда заглянем по дороге?</p><div class="route-options">'+picks.map((key,index)=>{
   const node=NODES[key];return '<button class="route-card route-'+key+'" data-node="'+key+'">'+this.routeArt(key)+'<span class="route-copy"><small>Путь '+(index+1)+'</small><b>'+node.name+'</b><span>'+(key==='elite'?eliteRouteText():node.desc)+'</span><em>Выбрать →</em></span></button>';
  }).join('')+'</div><p class="path-hint">Любой путь ведёт к следующему бою.</p></div>';
 },
 sceneHeader(type,kicker,title,text=''){
  return '<header class="scene-header">'+this.routeArt(type)+'<div class="scene-shade"></div><div class="scene-heading"><div class="kicker">'+kicker+'</div><h2>'+title+'</h2></div></header>'+(text?'<p class="scene-description">'+text+'</p>':'');
 },
 resultHTML(title,message){
  const type=G.pending==='forgeDone'?'campfire':G.pending==='eventDone'?'event':'straight';
  return this.sceneHeader(type,title,'Путь продолжается')+'<div class="scene-result"><span aria-hidden="true">✦</span><p>'+message+'</p></div><div class="row-btns"><button class="primary" id="ov-onward">К следующему бою →</button></div>';
 },
 battleIntroHTML(){
  if(Campaign.active())return Passage.intro();
  const enemy=G.enemy,boss=G.boss?BOSSES[G.boss]:null;
  const portrait=((({collector:0,brawler:1,sentinel:2,usurer:3})[enemy.id]??4)*25)+'%';
  const rule=key=>'<div class="brief-house-rule"><b>'+BOSSES[key].name+'</b><p>'+BOSSES[key].desc+'</p></div>';
  return '<div class="battle-brief"><header class="brief-header"><div class="brief-portrait" aria-hidden="true" style="--portrait-x:'+portrait+';'+(Campaign.active()?Campaign.portraitStyle():'')+'"></div><div><div class="kicker">'+(Campaign.active()?Campaign.label():('Этап '+G.ante+' · '+BLIND_NAMES[G.blind]))+'</div><h2>'+enemy.name+'</h2><p>'+(G.elite?'Элитный противник':enemy.type==='boss'?(Campaign.active()?'Начальник темницы':'Босс казино'):enemy.type==='mini'?'Мини-босс':'Следующий противник')+'</p></div></header>'+
   '<div class="brief-stats"><div><span>HP врага</span><strong>'+fmt(enemy.hp)+'</strong></div><div><span>Ходов на бой</span><strong>'+seatsCount()+'</strong></div><div><span>Цель карт</span><strong>'+limitNow()+'</strong></div></div>'+
   (G.fairStart?'<p class="talent-note">Честный старт: бонусы лавки отключены на этот забег.</p>':'')+talentSummary()+bargainSummary()+tableFeaturesSummary(true)+(enemyTrait()?'<p class="brief-trait">'+enemyTrait()+'</p>':'')+
   (boss?'<div class="brief-rules-title">Правило дома</div>'+rule(G.boss)+(G.boss2?rule(G.boss2):''):'')+
   (G.contract?'<div class="brief-house-rule"><b>Контракт: '+G.contract.name+'</b><p>'+G.contract.desc+' Награда: +$'+G.contract.reward+'.</p></div>':'')+
   '<details class="brief-help"><summary>Как проходит бой?</summary><p>Разыгрывай '+tablesPerSeat()+' стола за один ход. Кнопка «Сыграть ход» тратит ход, добор карт и остановка стола — нет. Очки становятся уроном. Победи врага, пока не закончатся ходы или HP. При переборе — ещё '+bustPenalty()+' входящего урона за стол.</p></details>'+
   '<div class="row-btns"><button class="ghost" id="ov-rules">Правила</button><button class="primary" id="ov-start">Начать бой</button></div></div>';
 },
 decorate(){
  const modal=$('#overlay .modal');if(!modal)return;
  if(G.phase==='path'&&G.pending!=='setup')modal.classList.add('game-intermission');
  if(G.phase==='intro'&&G.enemy&&G.pending!=='setup')modal.classList.add('battle-intro-screen');
  Passage.decorate();
 },
 back(){
  if(this.backTarget==='setup'){Campaign.locations();return;}
  if(this.backTarget==='home'){this.main();return}
  if(G?.phase==='won')showVictory();else if(G?.phase==='over')showGameOver();else this.main();
 }
};
