const assert=require('node:assert/strict');
const path=require('node:path');
const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{
 const browser=await launch();
 try{
  const page=await browser.newPage();await load(page);await page.addScriptTag({path:path.join(__dirname,'bot.js')});
  await page.evaluate(()=>{
   render=()=>{};renderShop=()=>{};saveRun=()=>{};showBlindIntro=()=>{};showScoreBurst=()=>{};tgHaptic=()=>{};flashHint=()=>{};metaSave=()=>{};purchaseFeedback=()=>{};toast=()=>{};showOverlay=()=>{};
   showRelicChoice=()=>{};window.setTimeout=()=>0;autoFinish=()=>{};
   stand=()=>{if(G.phase==='play'&&G.seat)finishSeat(evalSeat(G.seat));};
  });
  const seeds=Number(process.env.SEEDS||40);assert.ok(Number.isInteger(seeds)&&seeds>0);
  const configs=[{name:'cautious',threshold:16},{name:'moderate',threshold:18},{name:'risky',threshold:20},{name:'save-fourth',threshold:18,saving:true},{name:'no-tactics',threshold:18,tactical:false},
   {name:'short-bronze',threshold:18,deck:'short',stake:1},{name:'gold-silver',threshold:18,deck:'gold',stake:2}];
  const results=[];
  for(const config of configs){
   for(let seed=0;seed<seeds;seed++){
    const run=await page.evaluate(c=>VochkoBot.run(c),{...config,seed});results.push({policy:config.name,...run});
    if(seed===0){const repeat=await page.evaluate(c=>VochkoBot.run(c),{...config,seed});assert.deepEqual(repeat,run,'Seed must reproduce exactly: '+config.name);}
   }
   console.log(config.name+': '+seeds+' runs');writeReport('playtest-runs.json',results);
  }
  const summary=configs.map(c=>{const r=results.filter(x=>x.policy===c.name);return {policy:c.name,runs:r.length,wins:r.filter(x=>x.phase==='won').length,averageBlinds:r.reduce((n,x)=>n+x.blinds,0)/r.length,healthLoss:r.filter(x=>x.reason?.includes('Здоровье')).length,turnLoss:r.filter(x=>x.reason?.includes('Ходы')).length,fourthTable:r.filter(x=>x.fourthTable).length,errors:r.filter(x=>x.error).length,used:r.reduce((all,x)=>{for(const [key,n] of Object.entries(x.used))all[key]=(all[key]||0)+n;return all;},{})};});
  writeReport('balance-summary.json',summary);console.log(JSON.stringify(summary,null,2));
  if(results.some(x=>x.error||!['over','won'].includes(x.phase)))process.exitCode=1;
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
