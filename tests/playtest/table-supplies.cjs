const assert=require('node:assert/strict');
const {launch,load}=require('./runtime.cjs');
(async()=>{const browser=await launch();try{
 for(const [width,height] of [[320,568],[390,844],[430,932],[1280,900]]){
  const page=await browser.newPage({viewport:{width,height},reducedMotion:'reduce'});await load(page);
  await page.evaluate(()=>{META.onboarding={seen:true};newGame(0,'classic',{campaign:true});hideOverlay();startSeat();render();});
  const baseline=await page.locator('.tables').boundingBox();
  assert.equal(baseline.y,302,'Keep the original top edge of the tables');
  for(const count of [0,1,3,6]){
   await page.evaluate(count=>{G.cons=Array(count).fill(CONS.minus2);render();},count);
   const tables=await page.locator('.tables').boundingBox();assert.deepEqual(tables,baseline);
   const left=await page.locator('#cons').boundingBox(),right=await page.locator('#dealer').boundingBox();assert(left.x+left.width<=right.x);
   const card=await page.locator('#dealer .card').first().boundingBox();assert(card.width>=42&&card.height>=59);
   const counter=await page.locator('#dealer .pcount').boundingBox();assert(counter.y>=card.y+card.height);assert(counter.y+counter.height<=right.y+right.height);
   assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  }
  await page.locator('[data-cons-more]').scrollIntoViewIfNeeded();await page.locator('[data-cons-more]').click();assert.equal(await page.locator('[data-inventory-cons]').count(),6);await page.locator('.inventory-close').click();
  await page.evaluate(()=>{G.seat.peek3=true;render();});assert.equal(await page.locator('#dealer>.card').count(),3);assert.deepEqual(await page.locator('.tables').boundingBox(),baseline);
  await page.evaluate(()=>{G.seat.peek3=false;render();});await page.locator('#dealer .pile').click();assert(await page.locator('.deck-book').isVisible());
  await page.close();console.log(width+'px: tables unchanged; inventory, deck counter, preview and deck viewer work');
 }
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
