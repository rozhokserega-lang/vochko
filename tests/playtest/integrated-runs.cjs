const path=require('node:path');const assert=require('node:assert/strict');const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{const b=await launch();try{const p=await b.newPage();await load(p);await p.addScriptTag({path:path.join(__dirname,'bot.js')});
await p.evaluate(()=>{
 render=()=>{};renderShop=()=>{};saveRun=()=>{};showBlindIntro=()=>{};showScoreBurst=()=>{};tgHaptic=()=>{};flashHint=()=>{};metaSave=()=>{};purchaseFeedback=()=>{};toast=()=>{};showOverlay=()=>{};showRelicChoice=()=>{};window.setTimeout=()=>0;autoFinish=()=>{};HealingFX.record=()=>{};
 stand=()=>{if(G.phase==='play'&&G.seat)finishSeat(evalSeat(G.seat));};
 const reset=VochkoBot.reset;
 VochkoBot.reset=function(seed,deck,stake,opts){reset.call(this,seed,deck,stake,opts);const cfg=window.integrationConfig;G.talent=cfg.talent;G.bargains=[cfg.deal];BARGAINS[cfg.deal].apply();G.jokerGrowth={[cfg.joker]:{progress:JOKER_GROWTH[cfg.joker].goal,branch:cfg.branch}};};
});
const runs=[];for(const talent of ['healer','sharp','daring','warden','scout'])for(const deck of ['scarlet','nocturne']){
 for(let seed=0;seed<10;seed++){
 const run=await p.evaluate(({talent,deck,seed})=>{const branches=Object.entries(JOKER_GROWTH).flatMap(([joker,d])=>Object.keys(d.branches).map(branch=>({joker,branch})));const choice=branches[seed%branches.length];const deal=Object.keys(BARGAINS)[seed%4];window.integrationConfig={talent,deal,...choice};return {...VochkoBot.run({seed,deck,jokers:[choice.joker],tactical:true,style:'balanced'}),talent,deal,...choice};},{talent,deck,seed});assert.equal(run.error,null);assert.ok(['over','won'].includes(run.phase));runs.push(run);
 }console.log(talent+'/'+deck+': 10 runs complete');
}
const summary={runs:runs.length,wins:runs.filter(r=>r.phase==='won').length,errors:runs.filter(r=>r.error).length,averageBlinds:runs.reduce((sum,r)=>sum+r.blinds,0)/runs.length,scope:'Controlled starting combinations, not organic progression or a player win-rate estimate.'};writeReport('integrated-runs.json',{summary,runs});console.log(JSON.stringify(summary,null,2));
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
