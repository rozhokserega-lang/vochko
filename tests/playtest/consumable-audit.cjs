const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true});
 try{
 const page=await browser.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});
 await page.route('https://telegram.org/**',r=>r.abort());await page.goto((process.env.GAME_URL || require('node:url').pathToFileURL(require('node:path').resolve(__dirname, '../../index.html')).href));
 const report=await page.evaluate(()=>{
  const findings=[],checks=[];
  function reset(key){newGame(0,'classic');hideOverlay();startSeat();G.cons=[CONS[key]];G.enemy.hp=G.enemy.maxHp=100000;}
  function card(rank,suit='♠',mod){return {...G.runDeck.find(c=>c.rank===rank&&c.suit===suit),mod}}
  function check(name,value,detail){(value?checks:findings).push({name,detail})}
  for(const [key,expected] of [['minus2',21],['minus4',21],['plus2',19],['plus4',21],['pct30',17]]){
   reset(key);G.seat.tables[0].cards=key==='minus2'?[card('10'),card('9'),card('4')]:key.startsWith('plus')?[card('9'),card('8')]:[card('10'),card('9'),card('6')];refreshTables(G.seat);G.seat.sel=0;const tested=G.seat.tables[0];applyCons(0);
   check(key+' changes the sum and consumes one item',evalPlay(tested.cards,tested.adj).sum===expected&&G.cons.length===0);
  }
  reset('freeze');G.seat.tables[0].cards=[card('10'),card('9')];G.seat.sel=0;applyCons(0);G.seat.tables[0].cards.push(card('K'));check('Freeze retains sum while scoring new chips',evalPlay(G.seat.tables[0].cards,G.seat.tables[0].adj).sum===19&&evalPlay(G.seat.tables[0].cards,G.seat.tables[0].adj).chips===290);
  reset('swap');G.seat.tables[0].cards=[card('10'),card('9')];G.deck=[card('2')];G.seat.sel=0;applyCons(0);check('Swap replaces only last card',G.seat.tables[0].cards[1].rank==='2'&&G.discard.some(c=>c.rank==='9'));
  reset('shuffle');const held=card('5');G.seat.tables[0].cards=[held];G.deck=[card('2')];G.discard=[card('3')];pickCons(0);check('Shuffle combines draw and discard without held cards',G.deck.length===2&&!G.deck.some(c=>c.id===held.id)&&!G.discard.length);
  for(const key of ['peek','peek3','burn']){
   reset(key);G.deck=[];G.discard=[card('8')];pickCons(0);
   check(key+' works when draw pile needs recycling',key==='burn'?G.cons.length===0&&G.deck.length===0&&G.discard.length===1&&G.discard[0].rank==='8':G.deck.length===1&&nextCardsHTML(G.seat).includes('8'),{consLeft:G.cons.length,draw:G.deck.length,discard:G.discard.length});
   reset(key);G.deck=[];G.discard=[];pickCons(0);check(key+' does not spend item on an empty deck',G.cons.length===1,{consLeft:G.cons.length});
  }
  reset('plus2');G.seat.tables.forEach((t,i)=>{t.cards=i===2?[card('2'),card('3'),card('5'),card('9')]:[card('10'),card('9')];t.stood=i<2});refreshTables(G.seat);
  const before=G.seatsLeft;autoFinish(G.seat);check('Full boards allow useful consumable before autoplay',G.seatsLeft===before&&G.seat&&!G.seat.locked,{before,after:G.seatsLeft});
  reset('minus2');const aces=evalPlay([card('A'),card('A','♥'),card('2')]);check('Tied ace values prefer the closest legal total',aces.sum===14,{shown:aces.sum,score:aces.score});
  reset('minus2');G.jokers=[JOKERS.find(j=>j.id==='relay')];G.seat.tables[0].cards=[card('A'),card('K')];G.seat.tables[1].cards=[card('9','♥','glass')];
  const relay=evalSeat(G.seat).tables[1];const expectedRelay=evalPlay(G.seat.tables[1].cards,{dv:0,dc:4});check('Relay bonus inherits glass multiplier',relay.score===expectedRelay.score,{actual:relay.score,expected:expectedRelay.score});
  reset('minus2');G.extraTables=1;G.seat.tables.push(newTable());G.jokers=[JOKERS.find(j=>j.id==='ladder')];G.seat.tables[0].cards=[card('10'),card('9')];G.seat.tables[1].cards=[card('10'),card('Q')];G.seat.tables[2].cards=[card('A'),card('K')];
  const ladder=evalSeat(G.seat);check('Ladder recognizes three live consecutive tables with fourth empty',ladder.tags.some(t=>t.includes('лесенка')),{sums:ladder.tables.map(t=>t.sum),tags:ladder.tags});
  reset('minus2');G.cons=[CONS.peek,CONS.freeze];G.jokers=[JOKERS.find(j=>j.id==='sync')];G.seat.tables.forEach(t=>{t.cards=[card('2')];t.stood=true});check('Sync is not a free multiplier for manually stopped small hands',!evalSeat(G.seat).tags.some(t=>t.includes('синхронизация')),{tags:evalSeat(G.seat).tags});
  return {checks,findings};
 });
 fs.writeFileSync(__dirname+'/consumable-audit.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
