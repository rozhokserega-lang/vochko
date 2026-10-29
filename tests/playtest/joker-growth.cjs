const assert=require('node:assert/strict');const {launch,load}=require('./runtime.cjs');
(async()=>{const b=await launch();try{const p=await b.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});const errors=[];p.on('pageerror',e=>errors.push(e.message));await load(p);
const checks=await p.evaluate(()=>{
 const checks=[];function check(n,v){if(!v)throw Error(n);checks.push(n);}
 function reset(id,branch){newGame(0,'classic');hideOverlay();G.jokers=[JOKERS.find(j=>j.id===id)];G.relics=[];G.jokerGrowth=branch?{[id]:{progress:JOKER_GROWTH[id].goal,branch}}:{};startSeat();}
 function card(rank,suit='♠'){return {...G.runDeck.find(c=>c.rank===rank&&c.suit===suit)}}
 for(const id of Object.keys(JOKER_GROWTH)){
  reset(id);G.seat.tables[0].cards=[card('2','♥'),card('3','♥'),card('4','♦')];G.seat.tables[1].cards=[card('A'),card('K')];G.seat.tables[2].cards=[card('K'),card('Q'),card('5')];const res=evalSeat(G.seat),s=G.seat;recordJokerGrowth(res,s);check('Count played condition '+id,growthState(id).progress===1);recordJokerGrowth(res,s);check('No duplicate progress '+id,growthState(id).progress===1);
  G.phase='shop';openShop();G.jokerGrowth[id].progress=JOKER_GROWTH[id].goal;showGrowthChoice(id);saveRun();resumeRun();check('Restore pending choice '+id,G.evolutionChoice===id&&!!document.querySelector('[data-growth-branch]'));
  const branch=Object.keys(JOKER_GROWTH[id].branches)[0];chooseGrowth(id,branch);check('Choice applied '+id,growthIs(id,branch));chooseGrowth(id,Object.keys(JOKER_GROWTH[id].branches)[1]);check('Choice cannot change '+id,growthIs(id,branch));sellJoker(id);check('Sold effect inactive '+id,!growthIs(id,branch));G.jokers.push(JOKERS.find(j=>j.id===id));check('Repurchase retains branch '+id,growthIs(id,branch));saveRun();resumeRun();check('Branch saved '+id,growthIs(id,branch));
 }
 reset('crimson','bloom');G.seat.tables[0].cards=[card('2','♥'),card('3','♥'),card('4','♦')];check('Bloom 20 heal',evalSeat(G.seat).heal===20);G.talent='healer';check('Bloom with talent 30',evalSeat(G.seat).heal===30);
 reset('precision','master');G.seat.tables[0].cards=[card('A'),card('K')];check('Master 35%',evalSeat(G.seat).total===Math.round(evalPlay(G.seat.tables[0].cards).score*1.35));
 reset('precision','remedy');G.seat.tables[0].cards=[card('A'),card('K')];check('Remedy 3 heal',evalSeat(G.seat).heal===3);
 reset('insurer','cover');check('Cover penalty 1',bustPenalty()===1);
 for(const [id,branch] of [['crimson','ward'],['precision','remedy'],['insurer','premium'],['insurer','cover']]){
  reset(id,branch);G.player.hp=60;G.enemy.hp=G.enemy.maxHp=999999;G.enemy.intent={kind:'attack',amount:8};G.seat.tables[0].cards=[card('2','♥'),card('3','♥'),card('4','♦')];G.seat.tables[1].cards=[card('A'),card('K')];G.seat.tables[2].cards=[card('K'),card('Q'),card('5')];const res=evalSeat(G.seat),forecast=combatForecast(res),money=G.money;finishSeat(res);check('Forecast actual '+id+'/'+branch,G.player.hp===forecast.playerHp&&G.player.shield===forecast.playerShield);if(branch==='premium')check('Premium gives 3 dollars',G.money===money+3);if(branch==='ward')check('Ward grants 4 shield',res.growthShield===4);
 }
 reset('precision');delete G.jokerGrowth;saveRun();resumeRun();check('Legacy save without growth',growthState('precision').progress===0);
 return checks;
});
assert.deepEqual(errors,[]);console.log(JSON.stringify({passed:checks.length,checks,errors},null,2));
await p.evaluate(()=>{G.phase='shop';G.jokers=[JOKERS.find(j=>j.id==='crimson')];G.jokerGrowth={crimson:{progress:4,branch:null}};openShop();});await p.locator('[data-growth="crimson"]').click();await p.locator('[data-growth-branch="ward"]').click();assert.equal(await p.evaluate(()=>growthIs('crimson','ward')),true);
for(const width of [320,390]){await p.setViewportSize({width,height:844});assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);}console.log('Choice UI and mobile widths passed');
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
