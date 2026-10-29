const assert=require('node:assert/strict');const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{const b=await launch();try{const p=await b.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});const errors=[];p.on('pageerror',e=>errors.push(e.message));await load(p);
const checks=await p.evaluate(()=>{
 const checks=[];function check(n,v){if(!v)throw Error(n);checks.push(n);}
 function reset(){newGame(0,'classic');hideOverlay();G.jokers=[];G.relics=[];G.bargains=[];startSeat();}
 function c(rank,suit='♠'){return {...G.runDeck.find(c=>c.rank===rank&&c.suit===suit)}}
 reset();check('First fight plain',G.tableFeatures.length===0);G.blind=1;startBlind();const features=G.tableFeatures.slice();check('Unique features for 3 tables',features.length===3&&new Set(features).size===3);startSeat();check('Features stay across turns',JSON.stringify(features)===JSON.stringify(G.tableFeatures));saveRun();resumeRun();check('Features survive reload',JSON.stringify(features)===JSON.stringify(G.tableFeatures));
 G.extraTables=1;startBlind();check('Fourth table gets a feature',G.tableFeatures.length===4&&new Set(G.tableFeatures).size===4);G.boss='max3';assignTableFeatures();check('No impossible four-card feature under max3',!G.tableFeatures.includes('long'));
 for(const [id,ranks]of [['duo',['10','9']],['trio',['7','6','5']],['long',['2','3','4','9']],['low',['2','3','10']],['near',['10','10']]]){
  reset();G.tableFeatures=[id];G.seat.tables[0].cards=ranks.map((r,i)=>c(r,i%2?'♥':'♠'));const base=evalPlay(G.seat.tables[0].cards).score;check('Feature applied '+id,evalSeat(G.seat).total===Math.round(base*(1+TABLE_FEATURES[id].bonus/100)));const sum=evalPlay(G.seat.tables[0].cards).sum;check('Sum unchanged '+id,evalSeat(G.seat).tables[0].sum===sum);G.seat.tables[0].cards=[c('K'),c('Q'),c('5')];check('No bonus on bust '+id,evalSeat(G.seat).total===0);
 }
 reset();G.tableFeatures=['trio'];G.seat.tables[0].cards=[c('7'),c('6'),c('5')];check('Trio active',featureActive(G.seat.tables[0],0));G.seat.tables[0].cards.push(c('2'));check('Fourth card loses trio bonus',!featureActive(G.seat.tables[0],0));
 reset();G.tableFeatures=['near'];G.seat.tables[0].cards=[c('10'),c('9')];G.cons=[CONS.plus2];G.seat.sel=0;const preview=previewConsumable(G.seat,0,0);applyCons(0);check('Consumable updates rule and preview',evalPlay(G.seat.tables[0].cards,G.seat.tables[0].adj).sum===21&&!featureActive(G.seat.tables[0],0)&&preview.forecast.hit.hp===combatForecast(evalSeat(G.seat)).hit.hp);
 reset();G.tableFeatures=['trio','duo'];G.seat.tables[0].cards=[c('7'),c('6'),c('5')];G.seat.tables[1].cards=[c('9')];G.cons=[CONS.move];G.seat.sel=0;movePlayedCard(G.seat,0,2,1);check('Transfer recomputes both lanes',!featureActive(G.seat.tables[0],0)&&featureActive(G.seat.tables[1],1));
 for(const talent of Object.keys(TALENTS))for(const feature of Object.keys(TABLE_FEATURES)){
  reset();G.talent=talent;G.tableFeatures=[feature];G.player.hp=60;G.enemy.hp=G.enemy.maxHp=100000;G.enemy.intent={kind:'attack',amount:7};G.seat.tables[0].cards=[c('7'),c('6'),c('5')];const result=evalSeat(G.seat),forecast=combatForecast(result);finishSeat(result);check('Forecast '+talent+'/'+feature,G.player.hp===forecast.playerHp&&G.enemy.hp===100000-forecast.hit.hp);
 }
 newGame(0,'classic',{campaign:true});hideOverlay();
 for(let level=1;level<=10;level++){
  G.level=level;startBlind();hideOverlay();startSeat();check('Dungeon level '+level+' has no assigned features',G.tableFeatures.length===0);
  G.tableFeatures=['duo','trio','low'];G.seat.tables[0].cards=[c('10'),c('9')];
  check('Old dungeon bonuses disabled '+level,featureMultiplier(G.seat.tables[0],0)===1&&tableFeature(0)===null);
  check('Old dungeon descriptions hidden '+level,tableFeaturesSummary()===''&&tableFeatureBadge(G.seat.tables[0],0)==='');
 }
 saveRun();resumeRun();check('Resumed dungeon stays plain',tableFeature(0)===null&&tableFeaturesSummary()==='');
 reset();delete G.tableFeatures;saveRun();resumeRun();check('Legacy save stays plain',!tableFeature(0));
 return checks;
});assert.deepEqual(errors,[]);writeReport('table-features.json',{checks,errors});console.log(checks.length+' table-feature checks passed');
for(const width of [320,390])for(const count of [3,4]){await p.setViewportSize({width,height:844});await p.evaluate(count=>{newGame(0,'classic');G.blind=1;G.extraTables=count===4?1:0;startBlind();hideOverlay();startSeat();G.tableFeatures=['duo','trio','low','long'].slice(0,count);render();},count);assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);assert.equal(await p.locator('.table-feature').count(),count);assert.ok(await p.evaluate(()=>[...document.querySelectorAll('.table-feature')].every(e=>e.scrollWidth<=e.clientWidth+1)));}
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
