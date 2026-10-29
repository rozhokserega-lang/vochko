/* A single physical mark on a starter card; knowledge, not a stat bonus. */
const CardMark={price:40,selected:null,
 valid(key){return typeof key==='string'&&RANKS.some(([r])=>SUITS.some(s=>r+s.sym===key));},
 apply(){
  if(!META.shop.markOwned||!this.valid(META.shop.markCard))return;
  const card=G.runDeck.find(c=>c.rank+c.suit===META.shop.markCard);if(card)card.notched=true;
 },
 runSummary(){const card=G?.runDeck?.find(c=>c.notched);return card?'<details class="run-talent" data-run-panel="mark"><summary>Метка этого забега: '+card.rank+card.suit+'</summary><p>Надрыв на верхней рубашке означает эту карту. Настройки лавки не меняют метку уже начатого забега.</p></details>':'';},
 html(){
  const sh=META.shop;if(!this.valid(this.selected))this.selected=sh.markCard||null;
  return '<div class="mark-intro"><h3>Надорванный уголок</h3><p>Пометь одну конкретную карту. Когда она окажется сверху колоды, на рубашке будет виден надрыв. Лицо карты не раскрывается: ты узнаёшь её по своей метке.</p><p>Одна метка на стартовую колоду. '+(sh.markOwned?'Выбор можно менять бесплатно между забегами.':'Улучшение навсегда стоит '+this.price+' монет.')+' На уже начатый забег изменение не влияет.</p><div class="mark-preview"><span class="card back mini notched-example"><span></span></span><span>'+(this.selected?'Выбрана <b>'+this.selected+'</b>':'Выбери карту ниже')+'<small>Ежедневный режим и «Честный старт» — без метки.</small></span></div></div>'+
  '<div class="mark-grid">'+baseCards().map(c=>'<button class="mark-choice" data-mark-card="'+c.rank+c.suit+'" aria-pressed="'+(this.selected===c.rank+c.suit)+'" aria-label="Пометить '+c.rank+c.suit+'">'+cardElement({...c,notched:this.selected===c.rank+c.suit},{mini:1})+'</button>').join('')+'</div><div class="row-btns"><button class="primary" id="mark-confirm" '+(!this.selected||(!sh.markOwned&&sh.coins<this.price)?'disabled':'')+'>'+(sh.markOwned?'Применить метку':'Купить и пометить · '+this.price+' монет')+'</button>'+(sh.markOwned?'<button class="ghost" id="mark-clear">Убрать метку</button>':'')+'</div>';
 },
 bind(){
  document.querySelectorAll('[data-mark-card]').forEach(button=>button.onclick=()=>{const scroll=document.querySelector('.mark-grid').scrollTop;this.selected=button.dataset.markCard;showMetaShop('mark');document.querySelector('.mark-grid').scrollTop=scroll;});
  const confirm=document.querySelector('#mark-confirm');if(confirm)confirm.onclick=()=>this.confirm();const clear=document.querySelector('#mark-clear');if(clear)clear.onclick=()=>{META.shop.markCard=null;this.selected=null;metaSave();showMetaShop('mark');};
 },
 confirm(){
  const sh=META.shop;if(!this.valid(this.selected)||(!sh.markOwned&&sh.coins<this.price))return;
  if(!sh.markOwned){sh.coins-=this.price;sh.markOwned=true;}sh.markCard=this.selected;metaSave();showMetaShop('mark');toast('Метка '+this.selected+' сохранена для следующих забегов');
 },
 setupHTML(){
  const sh=META.shop,key=sh.markOwned&&this.valid(sh.markCard)?sh.markCard:null;
  return '<div class="mark-setup"><span><b>'+(key?'Метка карты: '+key:'Надорванный уголок')+'</b><small>'+(key?(SETUP.deck==='short'&&['2','3'].includes(key.slice(0,-1))?'В короткой колоде этой карты нет. Выбери другую метку.':'Надрыв на верхней рубашке поможет узнать карту. В честном старте отключён.'):'Улучшение колоды в лавке · '+this.price+' монет')+'</small></span><button class="ghost" id="setup-mark">'+(key?'Изменить':'Пометить')+'</button></div>';
 }
};
