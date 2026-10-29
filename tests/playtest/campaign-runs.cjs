const path=require('node:path');const assert=require('node:assert/strict');const {launch,load,writeReport}=require('./runtime.cjs');
// Balance knobs for experiments: CAMPAIGN_HP_MULT / CAMPAIGN_ATK_MULT scale every level,
// CAMPAIGN_HP_PATCH="1,1,1,1.1,..." scales levels 1-10 individually, CAMPAIGN_TAG suffixes the report file.
const HP_MULT=Number(process.env.CAMPAIGN_HP_MULT||1);const ATK_MULT=Number(process.env.CAMPAIGN_ATK_MULT||1);const TAG=process.env.CAMPAIGN_TAG||'';
const HP_PATCH=(process.env.CAMPAIGN_HP_PATCH||'').split(',').filter(Boolean).map(Number);
const ATK_PATCH=Number(process.env.CAMPAIGN_ATK_PATCH||1);
(async()=>{const b=await launch();try{const p=await b.newPage();await load(p);await p.addScriptTag({path:path.join(__dirname,'bot.js')});
await p.evaluate(({hpMult,atkMult,hpPatch,atkPatch})=>{DUNGEON_LEVELS.forEach((l,i)=>{l.hp=Math.round(l.hp*hpMult*(hpPatch[i]||1))});const atk=atkMult*atkPatch;if(atk!==1)COMBAT.attack=COMBAT.attack.map(v=>Math.round(v*atk));},{hpMult:HP_MULT,atkMult:ATK_MULT,hpPatch:HP_PATCH,atkPatch:ATK_PATCH});
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
writeReport((process.env.CAMPAIGN_FRESH==='1'?'campaign-runs-fresh':'campaign-runs')+TAG+'.json',{summary,runs,fresh:process.env.CAMPAIGN_FRESH==='1',hpMult:HP_MULT,atkMult:ATK_MULT,hpPatch:HP_PATCH,atkPatch:ATK_PATCH,scope:'Dungeon only; no purchased meta boosts or pregranted items. Fresh mode restricts locked items; standard mode has all unlocks available. One heuristic, straight routes, earned relics and evolution. Not human win rates.'});
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
