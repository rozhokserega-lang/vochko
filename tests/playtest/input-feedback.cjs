const assert=require('node:assert/strict');const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{const b=await launch();try{const checks=[];
const p=await b.newPage({viewport:{width:390,height:844},hasTouch:true,reducedMotion:'no-preference'});await load(p);
await p.evaluate(()=>{newGame(0,'classic');hideOverlay();startSeat();G.deck=G.runDeck.filter(c=>['2','3','4'].includes(c.rank));render();});
const original=await p.evaluate(()=>G.deck.length);for(let i=0;i<6;i++)await p.locator('#btn-draw').tap();assert.equal(await p.evaluate(()=>G.seat.tables.reduce((s,t)=>s+t.cards.length,0)),6);assert.equal(await p.evaluate(()=>G.deck.length),original-6);checks.push('Six taps produce six cards without queuing or double dealing');
assert.equal(await p.evaluate(()=>document.querySelector('#run-talent-panel')?.isConnected),true);checks.push('Build panel survives fast draw rendering');
await p.evaluate(()=>{G.enemy.hp=G.enemy.maxHp=100000;G.enemy.intent={kind:'attack',amount:4};document.querySelector('#seat-stats').scrollIntoView();});
await p.evaluate(()=>{
 window.attackVisuals={cards:0,projectiles:0};
 window.attackObserver=new MutationObserver(records=>records.forEach(record=>record.addedNodes.forEach(node=>{
  if(node.nodeType!==1)return;
  if(node.matches('.attack-orb,.attack-beam'))window.attackVisuals.projectiles++;
  if(node.matches('.attack-fx-layer>.card'))window.attackVisuals.cards++;
 })));
 window.attackObserver.observe(document.body,{childList:true,subtree:true});
});
await p.locator('#btn-stand').tap();
const points=await p.evaluate(()=>[...document.querySelectorAll('.attack-caption')].map(e=>({x:parseFloat(e.style.left),y:parseFloat(e.style.top)})));assert.ok(points.length>0&&points.every(pt=>pt.x>=0&&pt.x<=390&&pt.y>=0&&pt.y<=844));checks.push('Charge stays in visible viewport after scrolling');
await p.waitForFunction(()=>!AttackFX.active);assert.equal(await p.locator('.combat-receipt').count(),0);checks.push('Card hits do not duplicate damage in a summary banner');assert.equal(await p.evaluate(()=>G.seatsLeft),3);checks.push('One attack and one spent turn');
const visuals=await p.evaluate(()=>{window.attackObserver.disconnect();return window.attackVisuals;});assert.equal(visuals.projectiles,0);assert.equal(visuals.cards,6);checks.push('All six cards fly from the tables without a score orb or beam');
await p.evaluate(()=>{
 G.jokers=[JOKERS.find(j=>j.id==='pair'),JOKERS.find(j=>j.id==='suits')];
 const c=(rank,suit)=>G.runDeck.find(card=>card.rank===rank&&card.suit===suit);
 G.seat.tables[0].cards=[c('K','♠'),c('K','♥')];
 G.seat.tables[1].cards=[c('9','♥'),c('9','♦')];
 G.enemy.intent={kind:'guard',amount:0};render();
});
await p.locator('#btn-stand').tap();
const tally=await p.evaluate(()=>new Promise(resolve=>{
 const seen={caption:false,mult:null,punch:false,numbers:[]};let last='';
 const timer=setInterval(()=>{
  const caption=document.querySelector('.attack-caption')?.textContent;
  if(caption==='ОЧКИ'||/^СТОЛ /.test(caption))seen.caption=true;
  const badge=document.querySelector('.attack-mult-badge')?.textContent;
  if(badge&&/[x×]/.test(badge))seen.mult=badge;
  if(document.querySelector('#tags .tag.punch'))seen.punch=true;
  const number=document.querySelector('.attack-charge-number')?.textContent;
  if(number&&number!==last){seen.numbers.push(number);last=number;}
  if(!AttackFX.active){clearInterval(timer);resolve(seen);}
 },40);
 setTimeout(()=>{clearInterval(timer);resolve(seen);},6000);
}));
assert.equal(tally.caption,true);assert.ok(tally.mult);assert.ok(tally.punch);assert.ok(tally.numbers.length>=3);checks.push('Score climbs table by table with separate multiplier punches');
const reduced=await b.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});await load(reduced);await reduced.evaluate(()=>{newGame(0,'classic');hideOverlay();startSeat();G.seat.tables[0].cards=G.runDeck.filter(c=>['A','K'].includes(c.rank)&&c.suit==='♠');G.enemy.hp=G.enemy.maxHp=100000;render();stand();});assert.equal(await reduced.locator('.attack-fx-layer').count(),0);assert.ok(await reduced.locator('.combat-receipt').textContent().then(t=>t.includes('ПОПАДАНИЕ')));checks.push('Reduced motion retains static damage feedback');await reduced.evaluate(()=>newGame(0,'classic'));assert.equal(await reduced.locator('.combat-receipt').count(),0);checks.push('Restart removes stale receipt');
writeReport('input-feedback.json',{checks});console.log(checks.join('\n'));
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
