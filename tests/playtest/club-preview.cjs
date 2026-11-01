const assert=require('node:assert/strict');
const {launch,load}=require('./runtime.cjs');
(async()=>{const b=await launch();try{
 const p=await b.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'}),errors=[];p.on('pageerror',e=>errors.push(e.message));await load(p);
 await p.evaluate(()=>{META.onboarding={seen:true};newGame(0,'classic',{campaign:true,chapter:1});delete G.clubVersion;startBlind();});assert.equal(await p.evaluate(()=>G.chapter),0);
 await p.evaluate(()=>{Campaign.progress().unlocked=1;metaSave();Campaign.locations();});
 await p.locator('[data-chapter="1"]').click();assert((await p.locator('.preparation-nav').textContent()).includes('Подпольный клуб'));await p.locator('#ov-go').click();await p.evaluate(()=>{delete G.clubVersion;startBlind();});
 assert.equal(await p.evaluate(()=>G.chapter),1);assert.equal(await p.evaluate(()=>G.boss),null);assert.equal(await p.locator('#hud-ante').textContent(),'1/3');await p.locator('#ov-start').click();assert.equal(await p.evaluate(()=>G.enemy.intent.amount),23);
 const bonus=await p.evaluate(()=>{
  G.level=2;startBlind();hideOverlay();startSeat();G.enemy.hp=G.enemy.maxHp=100000;G.seatsLeft=1;
  const c=(r,s)=>({...G.runDeck.find(c=>c.rank===r&&c.suit===s)});
  G.seat.tables[0].cards=[c('K','♠'),c('9','♣')];G.seat.tables[1].cards=[c('Q','♠'),c('9','♦')];refreshTables(G.seat);render();
  const result=evalSeat(G.seat),forecast=combatForecast(result),before=G.player.hp;
  const previewCount=seatsCount();attackPreview(result);combatForecast(result);
  finishSeat(result);saveRun();return {out:forecast.outOfSeats,previewCount,total:seatsCount(),left:G.seatsLeft,earned:G.battle.clubBonusEarned,hpLost:before-G.player.hp,phase:G.phase};
 });assert.deepEqual(bonus,{out:false,previewCount:4,total:5,left:1,earned:true,hpLost:30,phase:'play'});
 await p.reload();await p.locator('#ov-continue').click();assert.equal(await p.evaluate(()=>G.chapter),1);assert.equal(await p.evaluate(()=>seatsCount()),5);assert.equal(await p.evaluate(()=>G.seatsLeft),1);
 const repeat=await p.evaluate(()=>{const r={tables:[{sum:21},{sum:21}]};Club.reward(r);return {left:G.seatsLeft,total:seatsCount()};});assert.deepEqual(repeat,{left:1,total:5});
 const boss=await p.evaluate(()=>{
  G.level=3;startBlind();hideOverlay();startSeat();const reset=seatsCount(),guard={...G.enemy.intent};
  const r={total:1000,heal:0,exact:0,tables:[{score:500},{score:500}, {empty:true}]};
  G.battle.turn=1;Enemy.plan();const open={...G.enemy.intent};Club.boostTables(r.tables);r.total=r.tables.reduce((sum,t)=>sum+(t.score||0),0);const hit=attackPreview(r),same=attackPreview(r);const before=G.enemy.hp;Combat.attack(r);
  const actual=before-G.enemy.hp;
  const c=(rank,suit)=>({...G.runDeck.find(c=>c.rank===rank&&c.suit===suit)});
  G.seat.tables[0].cards=[c('K','♠'),c('9','♣')];G.seat.tables[1].cards=[c('Q','♠'),c('9','♦')];
  G.enemy.intent.clubOpen=false;const base=evalSeat(G.seat);G.enemy.intent.clubOpen=true;const boosted=evalSeat(G.seat);render();
  const highlight=document.querySelectorAll('.club-vulnerable').length;
  G.jokers=[{...JOKERS.find(j=>j.id==='allin')}];G.battle.allinBusts=1;G.seat.tables[2].cards=[c('K','♣'),c('Q','♣'),c('9','♠')];const zero=attackPreview(evalSeat(G.seat)).hp;
  return {reset,guard,open,expected:hit.hp,actual,same:hit.hp===same.hp,localBoost:boosted.tables[0].score===Math.round(base.tables[0].score*1.6),highlight,zero};
 });assert.equal(boss.reset,4);assert.equal(boss.guard.kind,'guard');assert.equal(boss.guard.amount,260);assert.equal(boss.open.clubOpen,true);assert.equal(boss.open.amount,38);assert.equal(boss.expected,1300);assert.equal(boss.actual,1300);assert.equal(boss.same,true);assert.equal(boss.localBoost,true);assert.equal(boss.highlight,1);assert.equal(boss.zero,0);
 // A real three-fight progression, including the earned relic and final victory.
 await p.evaluate(()=>{newGame(0,'classic',{campaign:true,chapter:1});delete G.clubVersion;startBlind();});
 for(let level=1;level<=3;level++){
  assert.equal(await p.evaluate(()=>G.level),level);await p.locator('#ov-start').click();
  await p.evaluate(()=>{G.enemy.hp=1;G.seat.tables[0].cards.push(drawFromDeck());finishSeat(evalSeat(G.seat));});
  await p.waitForFunction(()=>G.phase==='won'||!!G.shop||!!G.relicChoice?.length);
  if(level===3)break;
  if(level===2)await p.locator('[data-relic]').first().click();
  assert.equal(await p.evaluate(()=>shopHealOpen()),true);await p.locator('#btn-next').click();
  assert.equal(await p.locator('.passage-route-ribbon li').count(),3);
  if(level===2)assert.deepEqual(await p.evaluate(()=>G.path),['rest','campfire','straight']);
  await p.locator('[data-node="straight"]').click();
 }
 await p.waitForFunction(()=>!!document.querySelector('#campaign-map'));assert.equal(await p.evaluate(()=>G.stats.blinds),3);assert.equal(await p.evaluate(()=>Campaign.progress().unlocked),1);assert.equal(await p.evaluate(()=>Campaign.progress().clubPrototypeCleared),true);
 const wins=await p.evaluate(()=>META.stats.wins);await p.evaluate(()=>Campaign.victory());assert.equal(await p.evaluate(()=>META.stats.wins),wins);
 for(const [width,height]of [[320,568],[390,844],[430,932],[1280,900]]){
  await p.setViewportSize({width,height});await p.evaluate(()=>{newGame(0,'classic',{campaign:true,chapter:1});delete G.clubVersion;startBlind();G.level=2;startBlind();hideOverlay();startSeat();render();});
  assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  assert((await p.locator('.club-tactic').textContent()).includes('+1 ход'));
  const intent=await p.locator('#enemy-intent').boundingBox(),player=await p.locator('.player-row').boundingBox();assert(intent.y+intent.height<=player.y||intent.x>=player.x+player.width,'Tactic must not overlap player health');
  if(width===390)await p.screenshot({path:'/tmp/vochko-club.png'});
 }
 assert.deepEqual(errors,[]);console.log('Legacy club preview: saved three-fight rules, rewards and layouts preserved');
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
