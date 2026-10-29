const assert=require('node:assert/strict');const {launch,load}=require('./runtime.cjs');
(async()=>{const browser=await launch();try{const p=await browser.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});const errors=[];p.on('pageerror',e=>errors.push(e.message));await load(p);
const checks=await p.evaluate(()=>{
 const checks=[];function check(n,v){if(!v)throw Error(n);checks.push(n);}
 function reset(){newGame(0,'classic',{talent:'sharp'});hideOverlay();G.phase='path';G.bargains=[];G.slotJ=G.slotC=0;}
 for(const id of Object.keys(BARGAINS)){
  reset();const slots=maxJokers(),cons=consSlots(),reward=baseReward();G.player.hp=90;openBargains();confirmBargain(id);check('No mutation before confirm '+id,!hasBargain(id));acceptBargain(id);check('Accepted '+id,hasBargain(id));const state=JSON.stringify(G);acceptBargain(id);check('No double reward '+id,JSON.stringify(G)===state);
  if(id==='velvet'){check('Joker slot',maxJokers()===slots+1);const price=buildShopItems().find(x=>x.kind==='cons');check('Surcharge',price.price===CONS[price.key].price+1);}
  if(id==='blood')check('Blood clamps HP',G.player.maxHp===75&&G.player.hp===75&&G.money>=18);
  if(id==='pockets')check('Pockets slots/reward',consSlots()===cons+2&&baseReward()===Math.max(0,reward-1));
  saveRun();resumeRun();check('Save accepted '+id,hasBargain(id)&&G.pending==='bargainDone');
 }
 reset();openBargains();confirmBargain('blood');saveRun();resumeRun();check('Restore confirmation',G.bargainSelection==='blood'&&!!document.querySelector('#bargain-accept'));acceptBargain('blood');check('Restored confirmation accepts',hasBargain('blood'));
 reset();G.player.maxHp=25;openBargains();confirmBargain('blood');check('Cannot kill through blood',!G.bargainSelection);
 reset();G.player.hp=90;openRest();takeRest('heal');check('Rest capped',G.player.hp===100);takeRest('heal');check('Rest not duplicated',G.player.hp===100);
 reset();openRest();takeRest('shield');startBlind();check('Prepared shield applied',G.player.shield===8&&G.nextRestShield===0);startBlind();check('Prepared shield one fight',G.player.shield===0);
 reset();G.path=['elite','rest','straight'];G.pending='path';G.pathEliteBoss='max3';const expected=Math.round(targetFor(G.ante,G.blind)*1.35);takeNode('elite');check('Elite announced rule/HP',G.boss==='max3'&&G.target===expected&&G.elite);
 reset();openCampfire();const card=G.runDeck.find(c=>c.rank==='5');forgeAction('upgrade');forgeConfirm(card.id);const before=card.up||0;check('Forge before confirmation',G.runDeck.find(c=>c.id===card.id).up===card.up);saveRun();resumeRun();check('Forge confirmation restored',G.forgeSelection===card.id&&!!document.querySelector('#forge-preview-accept'));forgeApply(card.id);check('Forge upgrade applied once',G.runDeck.find(c=>c.id===card.id).up===before+2);forgeApply(card.id);check('Forge no duplicate upgrade',G.runDeck.find(c=>c.id===card.id).up===before+2);
 reset();G.bargains=['fury'];startBlind();startSeat();const c=r=>({...G.runDeck.find(c=>c.rank===r&&c.suit==='♠')});G.seat.tables[0].cards=[c('10'),c('9')];const boosted=evalSeat(G.seat).total;G.bargains=[];const bare=evalSeat(G.seat).total;check('Fury damage',boosted===Math.round(bare*1.2));G.bargains=['fury'];G.enemy.intent={kind:'attack',amount:6};check('Fury enemy attack',enemyResponse(evalSeat(G.seat)).raw===8);const res=evalSeat(G.seat),f=combatForecast(res);finishSeat(res);check('Fury forecast matches',G.player.hp===f.playerHp);
 return checks;
});assert.deepEqual(errors,[]);console.log(JSON.stringify({passed:checks.length,checks,errors},null,2));
for(const width of [320,390]){await p.setViewportSize({width,height:844});await p.evaluate(()=>{G.phase='path';G.bargains=[];openBargains();});assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);}
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
