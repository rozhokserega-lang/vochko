const path=require('node:path');const assert=require('node:assert/strict');const {launch,load,writeReport}=require('./runtime.cjs');
const seeds=Number(process.env.BALANCE_SEEDS||30);
const offset=Number(process.env.BALANCE_OFFSET||0);
(async()=>{const b=await launch();try{const p=await b.newPage();await load(p);await p.addScriptTag({path:path.join(__dirname,'bot.js')});
await p.evaluate(()=>{
 render=()=>{};renderShop=()=>{};saveRun=()=>{};showBlindIntro=()=>{};showScoreBurst=()=>{};tgHaptic=()=>{};flashHint=()=>{};metaSave=()=>{};purchaseFeedback=()=>{};toast=()=>{};showOverlay=()=>{};showRelicChoice=()=>{};window.setTimeout=()=>0;autoFinish=()=>{};HealingFX.record=()=>{};
 stand=()=>{if(G.phase==='play'&&G.seat)finishSeat(evalSeat(G.seat));};
 const reset=VochkoBot.reset,shop=VochkoBot.shop;
 VochkoBot.reset=function(seed,deck,stake,opts){reset.call(this,seed,deck,stake,opts);G.talent=window.balanceConfig.talent;window.evolutions=0;};
 VochkoBot.shop=function(...args){shop.apply(this,args);for(const j of [...G.jokers])if(JOKER_GROWTH[j.id]&&!growthState(j.id).branch&&growthState(j.id).progress>=JOKER_GROWTH[j.id].goal){G.evolutionChoice=j.id;chooseGrowth(j.id,({crimson:'bloom',precision:'master',insurer:'cover'})[j.id]);window.evolutions++;}};
 nodeResult=function(title,msg,pendingTag){G.pending=pendingTag||'nodeDone';G.nodeResult={title,msg,pendingTag};};
 const take=takeNode;
 takeNode=function(key){const deal=window.balanceConfig?.deal;
  if(key==='straight'&&deal&&G.pending==='path'&&G.path?.includes('bargain')&&!hasBargain(deal)&&BARGAINS[deal].can()){
   G.pending='bargains';G.bargainSelection=deal;acceptBargain(deal);leaveNode();return;
  }take(key);
 };
});
await p.evaluate(rules=>{
 if(rules==='after')return;
 const original=applyStartDeck,shop=buildShopItems,reward=baseReward;
 applyStartDeck=function(key){
  if(key==='alchemy'){G.cons=shuffle(Object.keys(CONS)).slice(0,3).map(k=>CONS[k]);G.money=Math.max(0,G.money-2);return;}
  original(key);
 };
 buildShopItems=function(){const items=shop();if(hasBargain('velvet'))items.forEach(it=>it.price+=1);return items;};
 baseReward=function(){return Math.max(0,reward()-(hasBargain('pockets')?1:0));};
},process.env.BALANCE_RULESET||'after');
const arms=[...['healer','sharp','daring','warden','scout',null].map(talent=>({name:'talent-'+(talent||'none'),talent,deck:'classic'})),...['short','gold','glass','alchemy','scarlet','nocturne'].map(deck=>({name:'deck-'+deck,talent:'sharp',deck})),...['velvet','blood','fury','pockets'].map(deal=>({name:'deal-'+deal,talent:'sharp',deck:'classic',deal}))].filter(a=>process.env.BALANCE_ARMS?process.env.BALANCE_ARMS.split(',').includes(a.name):!a.deal);
const runs=[],summary=[];
for(const cfg of arms){const arm=[];for(let seed=offset;seed<offset+seeds;seed++){
 const r=await p.evaluate(cfg=>{window.balanceConfig=cfg;return {...VochkoBot.run({seed:cfg.seed,deck:cfg.deck,tactical:true,style:'balanced'}),evolutions:window.evolutions,bargains:G.bargains};},{...cfg,seed});assert.equal(r.error,null);arm.push(r);runs.push({arm:cfg.name,...r});
 }const row={name:cfg.name,runs:seeds,wins:arm.filter(r=>r.phase==='won').length,meanBlinds:arm.reduce((a,r)=>a+r.blinds,0)/seeds,hpLoss:arm.filter(r=>r.reason?.includes('Здоровье')).length,turnLoss:arm.filter(r=>r.reason?.includes('Ходы')).length,evolutions:arm.reduce((a,r)=>a+r.evolutions,0)};summary.push(row);console.log(JSON.stringify(row));}
writeReport(process.env.BALANCE_REPORT||'balance-progression.json',{seeds,offset,ruleset:process.env.BALANCE_RULESET||'after',summary,runs,scope:'No purchased meta boosts, all unlocks available, one fixed heuristic. Straight routes except the designated bargain when offered. Evolution is earned and chosen in shops.'});
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
