const assert=require('node:assert/strict');
const path=require('node:path');
const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{
 const browser=await launch();
 try{
  const page=await browser.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));await load(page);
  const checks=await page.evaluate(()=>{
   const checks=[];const check=(name,pass)=>{if(!pass)throw Error(name);checks.push(name)};
   const reset=()=>{newGame(0,'classic');hideOverlay();startSeat();G.cons=[];G.jokers=[];G.enemy.hp=G.enemy.maxHp=100000;G.enemy.intent={kind:'guard',amount:0};};
   const card=(rank,suit)=>({...G.runDeck.find(c=>c.rank===rank&&c.suit===suit)});
   const aces=()=>['♠','♥','♦'].map(s=>card('A',s));
   const kings=()=>['♠','♥','♦'].map(s=>card('K',s));
   reset();let r=evalPlay(aces());check('Three aces score one x2 critical',r.critical&&r.score===396&&r.sum===13&&!r.bust);
   r=evalPlay(aces().concat(card('A','♣')));check('Four aces keep one critical',r.critical&&r.score===528&&r.tags.filter(t=>t.includes('крит')).length===1);
   r=evalPlay(aces().slice(0,2));check('Two aces do not crit',!r.critical);
   G.boss='ace11';r=evalPlay(aces());check('Critical cannot cancel Ace11 bust',r.bust&&r.score===0);G.boss=null;
   G.jokers=[JOKERS.find(j=>j.id==='pair')];r=evalPlay(aces());check('Critical stacks with pair bonus',r.score===792);G.jokers=[];
   const glass=aces();glass[0].mod='glass';check('Critical stacks with glass',evalPlay(glass).score===792);
   r=evalPlay(kings());check('Three kings preserve sum and avoid bust',r.royal&&r.sum===30&&!r.bust&&r.score===180);
   r=evalPlay(kings().concat(card('9','♣')));check('Fourth card retains king protection',r.royal&&r.sum===39&&!r.bust);
   G.seat.tables[0].cards=kings();refreshTables(G.seat);r=evalSeat(G.seat);check('Kings are not automatically exact or dead',r.exact===0&&r.bust===0&&!G.seat.tables[0].dead&&!G.seat.tables[0].locked);
   const hp=G.player.hp;finishSeat(r);check('Kings cause no bust penalty',G.player.hp===hp&&G.lastTurn.busts===0);
   reset();G.seat.tables[0].cards=kings();G.cons=[CONS.remove];G.seat.sel=0;
   let preview=previewConsumable(G.seat,0,0,0);removePlayedCard(G.seat,0,0);check('Removing king updates combo and preview',preview.after.total===evalSeat(G.seat).total&&!evalPlay(G.seat.tables[0].cards).royal);
   reset();G.seat.goal=18;G.seat.tables[0].cards=[card('K','♠'),card('K','♥')];G.seat.tables[0].dead=true;G.seat.tables[1].cards=[card('K','♦')];G.cons=[CONS.move];G.seat.sel=0;
   preview=previewConsumable(G.seat,0,1,0,0);movePlayedCard(G.seat,1,0,0);check('Transfer rescues target-18 table with kings',preview.after.total===evalSeat(G.seat).total&&!G.seat.tables[0].dead&&evalPlay(G.seat.tables[0].cards).royal);
   reset();G.seat.tables[0].cards=aces();G.enemy.shield=100;G.enemy.armor=.2;const forecast=combatForecast(evalSeat(G.seat));finishSeat(evalSeat(G.seat));check('Critical forecast matches shield and armor resolution',forecast.hit.hp===G.lastTurn.damage&&G.lastTurn.damage<396);
   reset();G.blind=2;G.boss='pendulum';G.boss2=null;G.seat=null;G.battle.turn=0;G.seatsLeft=8;startSeat();
   for(const expected of [21,18,25,21]){
    check('Pendulum turn '+G.battle.turn+' target '+expected,limitNow()===expected);
    const s=G.seat;s.tables[0].cards=[card('2','♠')];G.cons=[CONS.plus2];s.sel=0;applyCons(0);check('Consumable keeps target '+expected,limitNow()===expected);G.enemy.intent={kind:'guard',amount:0};render();saveRun();check('Render/save preserves target '+expected,limitNow()===expected);
    finishSeat(evalSeat(s));check('Recorded outgoing target '+expected,G.lastTurn.goal===expected);
   }
   G.jokers=[JOKERS.find(j=>j.id==='diplomat')];G.seatsLeft=2;G.seat=null;startSeat();check('Diplomat restores normal target',limitNow()===G.limit);
   check('Pendulum conflicts are symmetric',['hot','lowLimit'].every(k=>BOSS_CLASH.pendulum.includes(k)&&BOSS_CLASH[k].includes('pendulum')));
   reset();G.blind=2;G.boss='pendulum';G.battle.turn=1;G.seatsLeft=3;G.jokers=['diplomat','phoenix'].map(id=>JOKERS.find(j=>j.id===id));G.seat=null;startSeat();G.seat.tables[0].cards=[card('10','♠'),card('10','♥')];render();
   check('Phoenix preview uses real next target despite unspent turn',document.querySelector('#target-cycle').textContent.includes('следующая цель: 25'));
   G.enemy.intent={kind:'guard',amount:0};finishSeat(evalSeat(G.seat));check('Phoenix advances target cycle without spending turn',G.seatsLeft===3&&limitNow()===25);
   G.seat.tables[0].cards=[card('2','♠')];G.enemy.intent={kind:'guard',amount:0};finishSeat(evalSeat(G.seat));check('Diplomat disables cycle after second spent turn',G.seatsLeft===2&&limitNow()===G.limit);
   reset();G.blind=2;G.boss='pendulum';G.battle.turn=1;G.seat=null;G.enemy=Enemy.create();G.enemy.hp=G.enemy.maxHp=100000;startSeat();check('Pendulum is a selectable named boss',BOSS_KEYS.includes('pendulum')&&G.enemy.name==='Маятник');G.seat.tables[0].cards=kings();G.seat.tables[1].cards=aces();refreshTables(G.seat);render();saveRun();
   return checks;
  });
  assert.match(await page.locator('#target-cycle').textContent(),/сейчас 18.*следующая цель: 25/);
  assert.equal(await page.locator('.combo-badge').count(),2);checks.push('Current/next targets and combo badges visible');
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  writeReport('combinations.json',{checks,errors});await page.evaluate(()=>{document.querySelectorAll('.score-float,.toast').forEach(el=>el.remove());document.querySelector('#table').classList.remove('score-burst');});await page.screenshot({path:path.resolve(__dirname,'../../test-results/combinations.png')});
  await page.reload();await page.evaluate(()=>resumeRun());assert.equal(await page.evaluate(()=>limitNow()),18);assert.match(await page.locator('#target-cycle').textContent(),/следующая цель: 25/);checks.push('Reload preserves current and next target');
  // Delay the response explicitly so the outgoing animated state can be inspected.
  const resolving=await page.evaluate(()=>{AttackFX.deferResponse=()=>{};G.seat.locked=true;finishSeat(evalSeat(G.seat),true);return {target:limitNow(),saved:readSavedRun().game.seat.goal,turn:G.battle.turn};});
  assert.deepEqual(resolving,{target:18,saved:18,turn:2});checks.push('Animated resolution keeps outgoing and saved target');
  assert.deepEqual(errors,[]);writeReport('combinations.json',{checks,errors});console.log(checks.length+' combination/target checks passed');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
