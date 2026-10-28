const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const screenshotDir=path.resolve(__dirname,'../../test-results');fs.mkdirSync(screenshotDir,{recursive:true});
const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{
 const browser=await launch(), checks=[],errors=[];
 try {
  const page=await browser.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});
  page.on('pageerror',e=>errors.push(e.message));
  await load(page);
  const logic=await page.evaluate(()=>{
   const checks=[];
   function check(name,pass){if(!pass)throw Error(name);checks.push(name);}
   function reset(key){resetTestRandom(42);newGame(0,'classic');hideOverlay();startSeat();G.cons=[CONS[key]];G.enemy.hp=G.enemy.maxHp=100000;G.seat.tables.forEach(t=>t.cards=[]);}
   function card(rank,suit='♠'){return {...G.runDeck.find(c=>c.rank===rank&&c.suit===suit)};}
   autoFinish=()=>{};
   for(const key of ['minus2','minus4','plus2','plus4','pct30','freeze']){
    reset(key);const s=G.seat;s.tables[0].cards=[card('9'),card('8')];s.sel=0;
    const before=JSON.stringify(G),saved=localStorage.getItem('vochko.run.v1');
    const p=previewConsumable(s,0,0);
    check(key+' preview leaves state/save unchanged',JSON.stringify(G)===before&&saved===localStorage.getItem('vochko.run.v1'));
    applyCons(0);
    check(key+' preview matches applied score and HP damage',p.after.total===evalSeat(s).total&&p.hit===attackPreview(evalSeat(s)).hp);
   }
   reset('move');let s=G.seat;s.tables[0].cards=[card('10'),card('9'),card('4')];s.tables[1].cards=[card('8','♥')];s.tables[0].adj.fz=2;s.sel=0;
   let p=previewConsumable(s,0,0,0,1);movePlayedCard(s,0,0,1);
   check('Transfer previews both sums and actual damage',p.after.total===evalSeat(s).total&&p.hit===attackPreview(evalSeat(s)).hp&&p.sums[0]===evalPlay(s.tables[0].cards,s.tables[0].adj).sum&&p.sums[1]===evalPlay(s.tables[1].cards,s.tables[1].adj).sum);
   reset('remove');s=G.seat;s.tables[0].cards=[card('10'),card('9'),card('4')];s.tables[0].dead=true;s.sel=0;p=previewConsumable(s,0,0,2);removePlayedCard(s,0,2);
   check('Remove preview matches rescue from dead table',p.after.total===evalSeat(s).total&&!s.tables[0].dead);
   reset('swap');s=G.seat;s.tables[0].cards=[card('9')];s.sel=0;check('Swap cannot reveal hidden draw',previewConsumable(s,0,0).unknown===true);s.peek=true;p=previewConsumable(s,0,0);applyCons(0);check('Visible swap preview matches',p.after.total===evalSeat(s).total);
   reset('minus2');s=G.seat;s.tables[0].cards=[card('9')];G.boss='nocons';check('Boss blocks preview',previewConsumable(s,0,0)===null);
   reset('plus2');s=G.seat;s.tables[0].cards=[card('9')];G.boss='noplus';check('No-plus boss blocks preview',previewConsumable(s,0,0)===null);
   reset('minus2');s=G.seat;G.jokers=[JOKERS.find(j=>j.id==='sync')];s.tables.forEach(t=>{t.cards=[card('2')];t.stood=true});check('Sync excludes manual stops',!evalSeat(s).tags.some(t=>t.includes('синхронизация')));
   s.tables.forEach(t=>{t.cards=[card('10'),card('A')];t.stood=false});check('Sync rewards three exact tables',evalSeat(s).tags.some(t=>t.includes('синхронизация')));
   s.tables.push(newTable());check('Sync requires purchased fourth table',!evalSeat(s).tags.some(t=>t.includes('синхронизация')));
   s.tables[3].blocked=true;check('Sync ignores blocked fourth table',evalSeat(s).tags.some(t=>t.includes('синхронизация')));
   s.tables[2].blocked=true;check('Sync requires at least three available tables',!evalSeat(s).tags.some(t=>t.includes('синхронизация')));
   reset('minus2');s=G.seat;s.tables[0].cards=[card('9'),card('8')];G.jokers=[JOKERS.find(j=>j.id==='alchemist'),JOKERS.find(j=>j.id==='miser')];
   const state=JSON.stringify(G);resetTestRandom(67);p=previewConsumable(s,0,0);const afterRandom=Math.random();resetTestRandom(67);check('Preview leaves RNG untouched',afterRandom===Math.random());check('Alchemist returns both outcomes without mutation',p.retainedHit!==undefined&&JSON.stringify(G)===state);
   reset('minus2');s=G.seat;s.tables[0].cards=[card('10'),card('9'),card('4')];G.seatsLeft=1;const res=evalSeat(s);const predicted=damageBreakdown(res);finishSeat(res);
   check('Damage breakdown agrees with resolved attack',predicted.hit.hp===G.lastTurn.damage);
   check('Loss report contains actual enemy HP, busts and remaining items',G.phase==='over'&&G.lastTurn.busts===1&&lossReviewHTML().includes('Срез −2')&&G.battleSummary.busts===1);
   reset('minus2');s=G.seat;s.tables[0].cards=[card('A'),card('K')];G.jokers=[JOKERS.find(j=>j.id==='bullseye'),JOKERS.find(j=>j.id==='breaker')];G.enemy.armor=.2;G.enemy.shield=100;
   const combat=damageBreakdown(evalSeat(s));check('Breakdown records actual active combat effects',combat.hit.steps.length===2&&combat.hit.armor===.2&&combat.hit.absorbed>0);
   finishSeat(evalSeat(s));check('Shield and armor breakdown matches real HP loss',combat.hit.hp===G.lastTurn.damage);
   newGame(0,'classic');hideOverlay();startSeat();G.extraTables=1;G.seat.tables.push(newTable());render();
   return checks;
  });checks.push(...logic);
  for(const width of [320,390,768,1280]){
   await page.setViewportSize({width,height:844});
   const layout=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth,dockBottom:document.querySelector('#dock').getBoundingClientRect().bottom,above:[...document.querySelectorAll('.tbl')].every(t=>t.querySelector('.t-sum').getBoundingClientRect().top<t.querySelector('.t-cards').getBoundingClientRect().top)}));
   assert.equal(layout.overflow,false,'horizontal overflow '+width);assert.equal(layout.above,true);if(width<=600)assert.ok(Math.abs(layout.dockBottom-844)<2);checks.push('Layout '+width+'px: four tables and controls');
  }
  await page.setViewportSize({width:390,height:844});
  await page.evaluate(()=>{G.seat.tables[0].cards=G.runDeck.filter(c=>c.suit==='♠'&&['10','9','4'].includes(c.rank));G.cons=[CONS.minus2];G.seat.sel=0;refreshTables(G.seat);render();});
  await page.evaluate(()=>{document.querySelectorAll('.toast,.score-float').forEach(el=>el.remove());document.querySelector('#table').classList.remove('score-burst');});
  await page.screenshot({path:path.join(screenshotDir,'consumable-preview.png')});
  await page.locator('#damage-details').click();await page.locator('#damage-close').waitFor();
  await page.screenshot({path:path.join(screenshotDir,'damage-breakdown.png')});await page.locator('#damage-close').click();checks.push('Damage explanation opens and returns to same turn');
  await page.evaluate(()=>{G.phase='shop';G.money=200;openShop();});
  const first=page.locator('[data-offer="0"]');const title=await first.locator('.si-name').textContent();const height=await first.evaluate(e=>e.getBoundingClientRect().height);
  await first.locator('.buy').click();
  assert.equal(await first.locator('.si-name').textContent(),title);assert.match(await first.locator('.buy').textContent(),/Куплено/);assert.ok(await first.evaluate(e=>e.getBoundingClientRect().height)>=height-1);assert.ok(await page.locator('.purchase-toast').isVisible());checks.push('Purchase retains card and confirms purchase');
  await page.evaluate(()=>{hideOverlay();G.phase='play';finishSeat(evalSeat(G.seat));saveRun();});
  const saved=await page.evaluate(()=>({tables:G.seat.tables.length,money:G.money,jokers:G.jokers.map(j=>j.id),lastTurn:G.lastTurn,battleSummary:G.battleSummary}));
  await page.reload();await page.evaluate(()=>resumeRun());
  assert.deepEqual(await page.evaluate(()=>({tables:G.seat.tables.length,money:G.money,jokers:G.jokers.map(j=>j.id),lastTurn:G.lastTurn,battleSummary:G.battleSummary})),saved);checks.push('Reload restores changed run');
  assert.deepEqual(errors,[]);writeReport('tactical-clarity.json',{checks,errors});console.log(checks.length+' checks passed');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
