const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict');
(async()=>{const browser=await chromium.launch({channel:'msedge',headless:true});try{
const page=await browser.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.route('https://telegram.org/**',r=>r.abort());await page.goto((process.env.GAME_URL||require('node:url').pathToFileURL(require('node:path').resolve(__dirname,'../../index.html')).href));
for(const width of [320,390]){await page.setViewportSize({width,height:844});await page.evaluate(()=>showRunSetup());assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);if(width===390)await page.screenshot({path:'D:/vochko/.preview/talents-setup.png'});}
const checks=await page.evaluate(()=>{
 const checks=[];function check(label,ok){if(!ok)throw Error(label);checks.push(label);}
 function reset(talent){newGame(0,'classic',{talent});hideOverlay();startSeat();G.jokers=[];G.relics=[];}
 function card(rank,suit='♠'){return {...G.runDeck.find(c=>c.rank===rank&&c.suit===suit)}}
 reset('healer');G.seat.tables[0].cards=[card('2','♥'),card('3','♥'),card('4','♦')];check('Healer red tables 10 → 15',evalSeat(G.seat).heal===15);
 G.jokers=[JOKERS.find(j=>j.id==='crimson')];check('Healer stacks with crimson 10 → 23',evalSeat(G.seat).heal===23);G.player.hp=50;check('Shop-style heal not amplified',Combat.heal(10)===10);
 reset('sharp');G.seat.tables[0].cards=[card('A'),card('K')];const base=evalPlay(G.seat.tables[0].cards).score;check('Exact +15%',evalSeat(G.seat).total===Math.round(base*1.15));G.seat.tables[0].cards=[card('10'),card('9')];check('Nonexact unchanged',evalSeat(G.seat).total===evalPlay(G.seat.tables[0].cards).score);
 reset('daring');G.seat.tables[0].cards=[card('10'),card('9')];G.seat.tables[1].cards=[card('K'),card('Q'),card('5')];const bare=evalPlay(G.seat.tables[0].cards).score;check('One bust +30%',evalSeat(G.seat).total===Math.round(bare*1.3));G.seat.tables[2].cards=[card('K'),card('Q'),card('5')];check('Two busts no bonus',evalSeat(G.seat).total===bare);
 for(const talent of Object.keys(TALENTS)){reset(talent);G.player.hp=70;G.seat.tables[0].cards=[card('2','♥'),card('3','♥'),card('4','♦')];G.seat.tables[1].cards=[card('A'),card('K')];G.seat.tables[2].cards=[card('K'),card('Q'),card('5')];const res=evalSeat(G.seat),forecast=combatForecast(res);finishSeat(res);check('Forecast '+talent,G.player.hp===forecast.playerHp&&G.enemy.hp===Math.max(0,G.enemy.maxHp-forecast.hit.hp));}
 reset('sharp');saveRun();check('Save talent',readSavedRun().game.talent==='sharp');resumeRun();check('Resume talent',G.talent==='sharp');delete G.talent;saveRun();resumeRun();check('Legacy save no talent',activeTalent()===null);
 newGame(0,'classic',{daily:true,talent:'healer'});check('Daily has no talent',G.talent===null);newGame(0,'classic',{talent:'bad'});check('Invalid talent ignored',G.talent===null);
 showRunSetup();check('Three talent choices',document.querySelectorAll('[data-talent]').length===3);
 return checks;
});
await page.locator('[data-talent="healer"]').click();await page.locator('#ov-go').click();assert.equal(await page.evaluate(()=>G.talent),'healer');await page.reload();await page.locator('#ov-continue').click();assert.equal(await page.evaluate(()=>G.talent),'healer');assert.deepEqual(errors,[]);console.log(JSON.stringify({checks,ui:'Select/start/reload/continue passed',errors},null,2));
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1});
