/* Deterministic policy. Reads draw order only while an in-game peek is active. */
window.VochkoBot = {
 reset(seed,deck='classic',stake=0){
  localStorage.clear();resetTestRandom(seed+1);cardSeq=0;lastBoss=null;
  META={shop:defaultShop(),unlocked:{},ach:{},stats:{runs:0,wins:0,bestAnte:0,bestScore:0,endlessBest:0},daily:{},unlockAll:true};
  newGame(stake,deck);hideOverlay();
 },
 jokerValue(j,owned=G.jokers){
  // Representative visible deck compositions, never upcoming draw order.
  const rank=r=>G.runDeck.find(c=>c.rank===r);
  const samples=[['A','K'],['10','9','2'],['7','7','6'],['5','6','9'],['9','8'],['2','3','4','9']];
  const score=jokers=>withGameState({...G,jokers},()=>samples.reduce((sum,ranks)=>{
   const s={...G.seat,tables:Array.from({length:tablesPerSeat()},(_,i)=>({...newTable(),cards:samples[(samples.indexOf(ranks)+i)%samples.length].map(rank).filter(Boolean)}))};
   return sum+evalSeat(s).total;
  },0)/samples.length);
  const base=score(owned),gain=score(owned.concat(j))-base;
  const utility={encore:base/Math.max(1,seatsCount()),execution:base*.12,bullseye:base*.16,revenge:base*.12,breaker:base*.08,desperate:base*.08,slayer:base*.08,phoenix:base*.10,tips:150,banker:100,alchemist:200,wide:300,xray:180,surgeon:180};
  return gain+(utility[j.id]||0);
 },
 relicValue(key){
  const values={vitality:G.player.hp<55?120:70,mend:G.player.hp<75?110:65,plating:95,revive:100,ward:85,opener:65,prism:90,slot: G.jokers.length>=maxJokers()?105:35,belt:25,anvil:40,kit:65,vault:70,piggy:55,echo:40,crown:60};
  return values[key]||30;
 },
 shop(saving,bought){
  if(G.blind===2&&G.ante<8){openRelicChoice();if(G.relicChoice){let best=0;G.relicChoice.forEach((k,i)=>{if(this.relicValue(k)>this.relicValue(G.relicChoice[best]))best=i});pickRelic(best);}}
  else openShop();
  if(!G.shop)openShop();
  if(shopHealOpen())while(G.player.hp<75&&G.money>=COMBAT.healPrice&&(G.shop.heals||0)<CONFIG.healsPerShop)Combat.buyHeal();
  const table=G.shop.items.findIndex(it=>it.kind==='table'&&!it.sold);
  if(saving&&table>=0&&G.money>=G.shop.items[table].price){buyItem(table);bought.push('table');}
  // Build a small core first, then reserve cash for the fourth table.
  const saveCash=saving&&!G.extraTables&&G.jokers.length>=2;
  const order=G.shop.items.map((it,i)=>({it,i,value:it.kind==='joker'?this.jokerValue(it.joker):0})).sort((a,b)=>b.value-a.value);
  for(const {it,i,value} of order){
   if(it.sold||saveCash||it.price>G.money)continue;
   if(it.kind==='joker'){
    if(G.jokers.some(j=>j.id===it.joker.id))continue;
    if(G.jokers.length>=maxJokers()){
     const losses=G.jokers.map(j=>({j,value:this.jokerValue(j,G.jokers.filter(x=>x!==j))})).sort((a,b)=>a.value-b.value);
     if(value<=losses[0].value+100)continue;
     sellJoker(losses[0].j.id);
    }
    buyItem(i);bought.push(it.joker.id);
   }else if(it.kind==='cons'&&G.cons.length<consSlots()&&['minus','plus','pct','freeze','remove','move','peek','peek3','burn','swap'].includes(CONS[it.key].kind)){
    buyItem(i);bought.push(it.key);
   }else if(it.kind==='up'||it.kind==='mod'){buyItem(i);bought.push(it.kind);}
  }
 },
 useItem(used){
  const s=G.seat;if(bossIs('nocons')||(bossIs('thin')&&s.used))return false;
  const base=combatForecast(evalSeat(s));
  const utility=f=>f.hit.hp+45*(f.playerHp-G.player.hp)+(f.win?100000:0);
  let best=null;
  for(let i=0;i<G.cons.length;i++){
   const k=G.cons[i];
   if(['peek','peek3'].includes(k.kind)&&!s.peek3&&!(k.kind==='peek'&&s.peek)&&activeTableIndex(s)>=0){pickCons(i);used[k.kind]=(used[k.kind]||0)+1;return true;}
   for(let ti=0;ti<s.tables.length;ti++){
    const choices=k.kind==='remove'||k.kind==='move'?s.tables[ti].cards.map((_,ci)=>ci):[undefined];
    for(const ci of choices)for(const to of k.kind==='move'?transferTargets(s,ti).map(x=>x.index):[undefined]){
     const p=previewConsumable(s,i,ti,ci,to);if(!p||p.unknown)continue;
     const value=utility(p.forecast)-utility(base);
     const freezing=k.kind==='freeze'&&p.sums[ti]>=limitNow()-1&&p.sums[ti]<=limitNow()&&s.tables[ti].cards.length<maxPlay();
     const gain=value+(freezing?300:0);
     if(gain>100&&(!best||gain>best.gain))best={i,ti,ci,to,k,gain};
    }
   }
  }
  if(!best)return false;
  s.sel=best.i;
  if(best.k.kind==='move')movePlayedCard(s,best.ti,best.ci,best.to);
  else if(best.k.kind==='remove')removePlayedCard(s,best.ti,best.ci);
  else applyCons(best.ti);
  used[best.k.kind]=(used[best.k.kind]||0)+1;return true;
 },
 run({seed,threshold=18,saving=false,deck='classic',stake=0,tactical=true}){
  this.reset(seed,deck,stake);
  const bought=[],used={},trace=[];let actions=0,error=null;
  try {
   while(!['over','won'].includes(G.phase)&&actions++<4000){
    if(G.phase==='intro'){startSeat();continue;}
    if(G.phase==='shop'){
     trace.push({stage:G.ante,fight:G.blind,hp:G.player.hp,money:G.money,jokers:G.jokers.map(j=>j.id),fourthTable:!!G.extraTables});
     this.shop(saving,bought);nextBlind();if(G.pending==='path')takeNode('straight');continue;
    }
    if(G.phase!=='play')throw Error('Unexpected phase '+G.phase);
    const s=G.seat;
    if(tactical&&this.useItem(used))continue;
    const ti=activeTableIndex(s);if(ti<0){finishSeat(evalSeat(s));continue;}
    const t=s.tables[ti],r=t.cards.length?evalPlay(t.cards,t.adj):null;
    let stop=r&&(r.bust||r.sum>=limitNow()-(21-threshold));
    const visible=(s.peek||s.peek3||hasJoker('xray'))&&G.deck.length;
    if(tactical&&visible){
     const next=G.deck[G.deck.length-1];
     const after=evalPlay(t.cards.concat(next),t.adj);
     if(r&&!r.bust&&after.bust){
      const burn=G.cons.findIndex(k=>k.kind==='burn');
      if(burn>=0&&!bossIs('nocons')&&!(bossIs('thin')&&s.used)){pickCons(burn);used.burn=(used.burn||0)+1;continue;}
      stop=true;
     }else if(!after.bust&&(!r||after.score>=r.score))stop=false;
    }
    if(stop){t.stood=true;refreshTables(s);continue;}
    const c=drawFromDeck();if(!c){t.stood=true;if(!s.tables.some(t=>t.cards.length))throw Error('No cards');continue;}
    t.cards.push(c);refreshTables(s);
   }
   if(!['over','won'].includes(G.phase))throw Error('Action limit exceeded');
  }catch(e){error=e.stack||e.message;}
  return {seed,threshold,saving,deck,stake,tactical,phase:G.phase,blinds:G.stats.blinds,stage:G.ante,hp:G.player.hp,enemyHp:G.enemy?.hp,reason:G.lossReason,used,bought,trace,error,actions,fourthTable:!!G.extraTables};
 }
};
