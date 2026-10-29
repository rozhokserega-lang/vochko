const assert=require('node:assert/strict');
const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{const browser=await launch();const checks=[];try{
 for(const width of [320,390,430]){
  const p=await browser.newPage({viewport:{width,height:width===320?568:width===390?844:932},hasTouch:true,reducedMotion:'reduce'});const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.addInitScript(()=>{const n=()=>{};window.Telegram={WebApp:{platform:'ios',safeAreaInset:{top:47,bottom:34,left:0,right:0},contentSafeAreaInset:{top:48,bottom:0,left:0,right:0},onEvent:n,ready:n,expand:n,setHeaderColor:n,setBackgroundColor:n,BackButton:{show:n,hide:n,onClick:n}}};});await load(p);
  await p.evaluate(()=>{META.onboarding={seen:true};newGame(0,'classic',{campaign:true});hideOverlay();startSeat();G.cons=[CONS.minus2,CONS.minus4,...Object.values(CONS)];G.jokers=Object.values(JOKERS).slice(0,5);render();});
  assert.equal(await p.locator('#cons [data-cons]:visible').count(),3);const height=await p.locator('#cons').evaluate(e=>e.offsetHeight);
  await p.locator('[data-cons-more]').click();assert.equal(await p.locator('[data-inventory-cons]').count(),await p.evaluate(()=>G.cons.length));await p.locator('[data-inventory-cons="0"]').click();assert.equal(await p.evaluate(()=>G.seat.sel),0);assert(await p.locator('#overlay').evaluate(e=>e.classList.contains('hidden')));
  await p.locator('.joker-inventory-toggle').click();assert.equal(await p.locator('.inventory-item').count(),5);await p.evaluate(()=>closeOverlay());assert(await p.locator('#overlay').evaluate(e=>e.classList.contains('hidden')));
  await p.evaluate(()=>{G.cons=Object.values(CONS);renderActions();});assert.equal(await p.locator('#cons').evaluate(e=>e.offsetHeight),height);
  for(const four of [false,true]){
   await p.evaluate(four=>{G.extraTables=four?1:0;startSeat();G.seat.tables.forEach((t,i)=>{t.cards=G.runDeck.slice(i*4,i*4+4)});refreshTables(G.seat);render();window.scrollTo(0,0);},four);
   assert.equal(await p.locator('.tbl').count(),four?4:3);assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
   assert(await p.locator('#btn-stand').isEnabled());
  }
  assert.deepEqual(errors,[]);checks.push(width+'px: inventories, item selection, close, stable row, three/four tables, no horizontal overflow or JS errors');await p.close();
 }
 writeReport('duel-field.json',{checks});console.log(checks.join('\n'));
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
