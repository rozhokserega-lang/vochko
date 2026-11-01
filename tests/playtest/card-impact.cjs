const assert=require('node:assert/strict');const {launch,load}=require('./runtime.cjs');
(async()=>{const b=await launch();try{
 const p=await b.newPage({viewport:{width:390,height:844},reducedMotion:'no-preference'}),errors=[];p.on('pageerror',e=>errors.push(e.message));await load(p);
 async function prepare(hp=100000){return p.evaluate(hp=>{
  META.onboarding={seen:true};newGame(0,'classic');hideOverlay();startSeat();G.enemy.hp=G.enemy.maxHp=hp;G.enemy.shield=1000;G.enemy.armor=.12;G.enemy.intent={kind:'guard',amount:0};
  G.seat.tables.forEach((t,i)=>{t.cards=['K','A'].map(rank=>({...G.runDeck.find(c=>c.rank===rank&&c.suit===['♠','♥','♣'][i])}));});refreshTables(G.seat);render();
  const result=evalSeat(G.seat),expected=attackPreview(result);window.hitEvents=[];window.initialEnemyHp=hp;window.commits=0;
  if(!window.originalFinish)window.originalFinish=finishSeat;finishSeat=function(...args){window.commits++;return window.originalFinish(...args)};
  window.hitObserver?.disconnect();window.hitObserver=new MutationObserver(records=>records.forEach(r=>r.addedNodes.forEach(node=>{
   if(node.nodeType===1&&node.matches('.attack-card-impact'))window.hitEvents.push({hp:Number(node.dataset.hp),shield:Number(node.dataset.shield),actual:G.enemy.hp,display:Number(document.querySelector('#enemy-health').parentElement.getAttribute('aria-valuenow')),x:parseFloat(node.style.left),y:parseFloat(node.style.top)});
  })));window.hitObserver.observe(document.body,{childList:true,subtree:true});return {expected,hp};
 },hp);}
 const {expected,hp}=await prepare();await p.locator('#btn-stand').click();await p.waitForFunction(()=>!AttackFX.active);
 const outcome=await p.evaluate(()=>({hits:window.hitEvents,hp:G.enemy.hp,shield:G.enemy.shield,left:G.seatsLeft,commits:window.commits,portrait:(()=>{const r=document.querySelector('#enemy-portrait').getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()}));
 assert.equal(outcome.hits.length,6);assert.equal(outcome.commits,1);assert.equal(outcome.left,3);assert.equal(outcome.hp,hp-expected.hp);assert.equal(outcome.shield,1000-expected.absorbed);
 assert.equal(outcome.hits.reduce((sum,h)=>sum+h.hp,0),expected.hp);assert.equal(outcome.hits.reduce((sum,h)=>sum+h.shield,0),expected.absorbed);
 assert(outcome.hits.some(h=>h.actual===hp&&h.display<hp),'HP must visibly drain at collisions before committing the turn');
 assert(outcome.hits[0].shield>0,'First impacts must hit the shield');let shieldUsed=0;for(const hit of outcome.hits){shieldUsed+=hit.shield;if(hit.hp)assert.equal(shieldUsed,expected.absorbed,'HP may drain only after the absorbed shield is exhausted');}
 assert(outcome.hits.every(h=>Math.abs(h.x-outcome.portrait.x)<=9&&Math.abs(h.y-outcome.portrait.y)<=6));
 console.log('Six collisions drain shield then HP; damage labels sum exactly to the single committed attack');
 await prepare();await p.locator('#btn-stand').click();await p.waitForFunction(()=>window.hitEvents.length>=1);await p.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'));});await p.waitForFunction(()=>!AttackFX.active);assert.equal(await p.evaluate(()=>window.commits),1);assert.equal(await p.locator('.attack-fx-layer').count(),0);await p.evaluate(()=>{delete document.hidden;});console.log('Hiding mid-flight flushes one attack and clears the preview');
 await prepare();await p.locator('#btn-stand').click();await p.waitForFunction(()=>window.hitEvents.length>=1);await p.evaluate(()=>newGame(0,'classic'));await p.waitForTimeout(900);assert.equal(await p.evaluate(()=>G.enemy.hp),await p.evaluate(()=>G.enemy.maxHp));assert.equal(await p.evaluate(()=>G.seatsLeft),4);assert.equal(await p.locator('.attack-fx-layer').count(),0);console.log('Restart during card impacts leaves the new enemy and turn budget untouched');
 await prepare(1000);await p.evaluate(()=>{G.enemy.intent={kind:'attack',amount:99};});await p.locator('#btn-stand').click();await p.waitForFunction(()=>!AttackFX.active);assert.equal(await p.evaluate(()=>G.enemy.hp),0);assert.equal(await p.evaluate(()=>G.player.hp),100);assert.equal(await p.evaluate(()=>G.stats.blinds),1);console.log('A lethal card series wins once without an enemy counterattack');
 await p.emulateMedia({reducedMotion:'reduce'});await p.reload();await prepare();await p.locator('#btn-stand').click();assert.equal(await p.evaluate(()=>window.commits),1);assert.equal(await p.locator('.attack-card-impact').count(),0);assert.deepEqual(errors,[]);console.log('Reduced motion keeps immediate combat without travelling cards');
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
