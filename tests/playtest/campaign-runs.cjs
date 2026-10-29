const path=require('node:path');const assert=require('node:assert/strict');const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{const b=await launch();try{const p=await b.newPage();await load(p);await p.addScriptTag({path:path.join(__dirname,'bot.js')});
await p.evaluate(fresh=>{
 render=()=>{};renderShop=()=>{};saveRun=()=>{};showBlindIntro=()=>{};showScoreBurst=()=>{};tgHaptic=()=>{};flashHint=()=>{};metaSave=()=>{};purchaseFeedback=()=>{};toast=()=>{};showOverlay=()=>{};showRelicChoice=()=>{};window.setTimeout=()=>0;autoFinish=()=>{};HealingFX.record=()=>{};
 stand=()=>{if(G.phase==='play'&&G.seat)finishSeat(evalSeat(G.seat));};
 const start=newGame;newGame=function(stake,deck,opts){META.unlockAll=!fresh;return start(0,deck,{...opts,campaign:true,talent:window.campaignTalent});};
 const shop=VochkoBot.shop;
 VochkoBot.shop=function(...args){
  if(G.level===10){Campaign.victory();return;}
  if(Campaign.relicOffer()){openRelicChoice();if(G.relicChoice){let best=0;G.relicChoice.forEach((k,i)=>{if(this.relicValue(k)>this.relicValue(G.relicChoice[best]))best=i;});pickRelic(best);}}
  else openShop();const open=openShop;openShop=()=>{};try{shop.apply(this,args);}finally{openShop=open;}
  for(const j of G.jokers)if(JOKER_GROWTH[j.id]&&!growthState(j.id).branch&&growthState(j.id).progress>=JOKER_GROWTH[j.id].goal){G.evolutionChoice=j.id;chooseGrowth(j.id,({crimson:'bloom',precision:'master',insurer:'cover'})[j.id]);}
 };
},process.env.CAMPAIGN_FRESH==='1');const runs=[],summary=[];const seeds=Number(process.env.CAMPAIGN_SEEDS||30);
for(const talent of (process.env.CAMPAIGN_FRESH==='1'?['healer','sharp','daring']:['healer','sharp','daring','warden','scout'])){const arm=[];for(let seed=0;seed<seeds;seed++){
const r=await p.evaluate(({talent,seed})=>{window.campaignTalent=talent;return {...VochkoBot.run({seed,deck:'classic',tactical:true,style:'balanced'}),level:G.level,campaign:G.campaign};},{talent,seed});assert.equal(r.error,null);assert.ok(['won','over'].includes(r.phase));assert.ok(r.blinds<=10);arm.push(r);runs.push({talent,...r});}
const s={talent,runs:seeds,wins:arm.filter(r=>r.phase==='won').length,meanWins:arm.reduce((n,r)=>n+r.blinds,0)/seeds,hpLoss:arm.filter(r=>r.reason?.includes('Здоровье')).length,turnLoss:arm.filter(r=>r.reason?.includes('Ходы')).length};summary.push(s);console.log(JSON.stringify(s));}
writeReport(process.env.CAMPAIGN_FRESH==='1'?'campaign-runs-fresh.json':'campaign-runs.json',{summary,runs,fresh:process.env.CAMPAIGN_FRESH==='1',scope:'Dungeon only; no purchased meta boosts or pregranted items. Fresh mode restricts locked items; standard mode has all unlocks available. One heuristic, straight routes, earned relics and evolution. Not human win rates.'});
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
