const assert=require('node:assert/strict');
const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{
 const browser=await launch();
 try{
  const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  const errors=[];page.on('pageerror',error=>errors.push(error.message));await load(page);
  await page.evaluate(()=>{
   newGame(0,'classic');hideOverlay();startSeat();
   G.jokers=[{...JOKERS.find(j=>j.rarity==='legendary')}];
   G.seat.tables[0].cards=G.runDeck.slice(0,3).map(c=>({...c,mod:'gold'}));render();
  });
  await page.waitForTimeout(1200);
  const result=await page.evaluate(()=>({
   infinite:document.getAnimations().filter(a=>a.effect?.getTiming().iterations===Infinity).length,
   blur:getComputedStyle(document.querySelector('#hud')).backdropFilter,
   cardLayer:getComputedStyle(document.querySelector('.card')).willChange,
   mobileFX:MOBILE_FX,
   overflow:document.documentElement.scrollWidth>innerWidth
  }));
  assert.equal(result.infinite,0);assert.equal(result.blur,'none');assert.equal(result.cardLayer,'auto');assert.equal(result.mobileFX,true);assert.equal(result.overflow,false);
  await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,value:true});document.dispatchEvent(new Event('visibilitychange'));});
  assert.equal(await page.evaluate(()=>document.documentElement.classList.contains('game-backgrounded')),true);
  await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,value:false});document.dispatchEvent(new Event('visibilitychange'));});
  assert.equal(await page.evaluate(()=>document.documentElement.classList.contains('game-backgrounded')),false);
  assert.deepEqual(errors,[]);writeReport('mobile-performance.json',{...result,errors});console.log('7 mobile performance checks passed');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
