const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs=require('fs');
(async()=>{const browser=await chromium.launch({channel:'msedge',headless:true});try{
 const page=await browser.newPage();await page.route('https://telegram.org/**',r=>r.abort());await page.goto((process.env.GAME_URL || require('node:url').pathToFileURL(require('node:path').resolve(__dirname, '../../index.html')).href));
 const results=[];
 for(const threshold of [16,18,20])for(let batch=0;batch<4;batch++){
 const runs=await page.evaluate(({threshold,batch})=>{
  render=()=>{};renderShop=()=>{};saveRun=()=>{};showBlindIntro=()=>{};showScoreBurst=()=>{};tgHaptic=()=>{};flashHint=()=>{};metaSave=()=>{};window.setTimeout=()=>0;
  stand=()=>{if(G.phase==='play'&&G.seat)finishSeat(evalSeat(G.seat));};
  const output=[];
  for(let seed=batch*10;seed<batch*10+10;seed++){
   newGame(0,'classic');G.daily='audit-'+seed;G.money=4;G.jokers=[];G.relics=[];G.cons=[CONS.minus2,CONS.minus4];G.extraTables=G.slotJ=G.slotC=0;G.player.hp=G.player.maxHp=100;startBlind();
   const used={},bought=[],trace=[];let actions=0,error=null;
   try{while(!['over','won'].includes(G.phase)&&actions++<4000){
    if(G.phase==='intro'){startSeat();continue;}
    if(G.phase==='shop'){
     trace.push({ante:G.ante,blind:G.blind,hp:G.player.hp,turns:G.seatsLeft,money:G.money,jokers:G.jokers.map(j=>j.id)});
     if(G.blind===2&&G.ante<8){openRelicChoice();pickRelic(0);}else openShop();if(shopHealOpen())for(let i=0;i<2&&G.player.hp<75;i++)Combat.buyHeal();
     for(let pass=0;pass<2;pass++){
      const order=G.shop.items.map((it,i)=>({it,i})).sort((a,b)=> (b.it.kind==='joker')-(a.it.kind==='joker'));
      for(const {it,i} of order){if(it.sold||G.money<it.price)continue;if(it.kind==='joker'&&G.jokers.length<maxJokers()||it.kind==='cons'&&G.cons.length<consSlots()||it.kind==='up'||it.kind==='mod'){const before=G.money;buyItem(i);if(G.money<before)bought.push(it.kind==='joker'?it.joker.id:it.key||it.kind);}}
      if(pass===0&&G.money>=10&&G.jokers.length<maxJokers())rerollShop();
     }
     nextBlind();if(G.pending==='path')takeNode('straight');continue;
    }
    if(G.phase!=='play')throw Error('Unexpected phase '+G.phase);
    const s=G.seat;let consumed=false;
    if(!bossIs('nocons')&&!(bossIs('thin')&&s.used))for(let i=0;i<G.cons.length&&!consumed;i++){
     const k=G.cons[i];if(!['minus','plus','pct','freeze'].includes(k.kind)||bossIs('noplus')&&k.kind==='plus')continue;
     for(let ti=0;ti<s.tables.length;ti++){
      const t=s.tables[ti];if(t.dead||t.locked||t.blocked||!t.cards.length)continue;const r=evalPlay(t.cards,t.adj);let adj={...t.adj};
      if(k.kind==='minus')adj.dv-=consPower(k);if(k.kind==='plus'){adj.dv+=consPower(k);adj.dc+=consPower(k);}if(k.kind==='pct')adj.dv-=Math.ceil(r.sum*k.n);
      const improved=k.kind==='freeze'?!adj.fz&&r.sum>=limitNow()-1&&t.cards.length<maxPlay()&&!r.bust:evalPlay(t.cards,adj).score>r.score+200;
      if(improved){s.sel=i;const n=G.consUsed;applyCons(ti);if(G.consUsed>n){used[k.name]=(used[k.name]||0)+1;consumed=true;}break;}
     }
    }
    if(consumed||G.seat!==s)continue;
    const ti=activeTableIndex(s);if(ti<0){stand();continue;}
    const t=s.tables[ti],r=t.cards.length?evalPlay(t.cards,t.adj):null;
    if(r&&(r.bust||r.sum>=limitNow()-(21-threshold))){t.stood=true;refreshTables(s);continue;}
    const c=drawFromDeck();if(!c){t.stood=true;if(!s.tables.some(x=>x.cards.length))throw Error('No cards');continue;}t.cards.push(c);refreshTables(s);
   }}catch(e){error=e.message;}
   output.push({seed,threshold,phase:G.phase,blinds:G.stats.blinds,ante:G.ante,blind:G.blind,hp:G.player.hp,enemyHp:G.enemy?.hp,reason:G.lossReason,used,bought,trace,error,actions});
  }return output;
 },{threshold,batch});results.push(...runs);console.log('Completed',results.length,'runs');fs.writeFileSync(require('node:path').join(__dirname, 'playtest-runs.json'),JSON.stringify(results,null,2));
 }
 console.log(JSON.stringify([16,18,20].map(threshold=>{const r=results.filter(x=>x.threshold===threshold);return {threshold,runs:r.length,wins:r.filter(x=>x.phase==='won').length,averageBlinds:r.reduce((s,x)=>s+x.blinds,0)/r.length,healthLoss:r.filter(x=>x.reason?.includes('Здоровье')).length,turnLoss:r.filter(x=>x.reason?.includes('Ходы')).length,errors:r.filter(x=>x.error).map(x=>x.error)};}),null,2));
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1});
