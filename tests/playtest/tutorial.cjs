const assert=require('node:assert/strict');const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{const b=await launch();try{const p=await b.newPage({viewport:{width:390,height:844},reducedMotion:'reduce',hasTouch:true});await load(p);const checks=[];
await p.evaluate(()=>{newGame(0,'classic',{campaign:true});hideOverlay();startSeat();G.deck=G.runDeck.filter(c=>['2','3','4'].includes(c.rank));render();});assert.equal(await p.evaluate(()=>G.tutorialStep),'draw');assert.equal(await p.locator('#tutorial-coach').count(),1);assert.equal(await p.locator('#btn-draw').isEnabled(),true);checks.push('First non-daily dungeon attempt shows optional hints without blocking input');
await p.locator('#btn-draw').tap();assert.equal(await p.evaluate(()=>G.tutorialStep),'build');await p.locator('#btn-draw').tap();assert.equal(await p.evaluate(()=>G.tutorialStep),'stop');await p.locator('#btn-stop-table').tap();assert.equal(await p.evaluate(()=>G.tutorialStep),'play');await p.locator('#btn-stand').tap();assert.equal(await p.locator('#tutorial-coach').count(),0);assert.equal(await p.evaluate(()=>META.onboarding.status),'completed');checks.push('Draw, second card, stop and attack complete four hints');
await p.reload();await p.evaluate(()=>{newGame(0,'classic',{campaign:true});hideOverlay();startSeat();});assert.equal(await p.locator('#tutorial-coach').count(),0);checks.push('Completion persists after reload and another new run');
const result=await p.evaluate(()=>{
 const checks=[];function check(n,v){if(!v)throw Error(n);checks.push(n);}function fresh(){localStorage.removeItem(RUN_SAVE_KEY);delete META.onboarding;META.stats.runs=0;META.campaign={unlocked:0,completed:[],bestLevels:{}};}
 fresh();newGame(0,'classic',{campaign:true});hideOverlay();startSeat();Tutorial.finish('skipped');saveRun();newGame(0,'classic',{campaign:true});check('Skipped guide never restarts',!G.tutorialStep&&META.onboarding.status==='skipped');
 fresh();newGame(0,'classic',{campaign:true,daily:true});check('No automatic daily tutorial',!G.tutorialStep);
 fresh();newGame(0,'classic');check('No automatic legacy tutorial',!G.tutorialStep);
 fresh();META.stats.runs=3;newGame(0,'classic',{campaign:true});check('Existing players not interrupted',!G.tutorialStep);
 fresh();newGame(0,'classic',{campaign:true});hideOverlay();startSeat();G.deck=[G.runDeck.find(c=>c.rank==='K'&&c.suit==='♠'),G.runDeck.find(c=>c.rank==='A'&&c.suit==='♠')];hit();hit();check('Naturally exact first table skips unavailable stop',G.tutorialStep==='play');FastDraw.flush();resumeRun();check('Resume preserves first-attempt progress',G.tutorialStep==='play');
 return checks;
});checks.push(...result);assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);writeReport('tutorial.json',{checks});console.log(checks.join('\n'));
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
