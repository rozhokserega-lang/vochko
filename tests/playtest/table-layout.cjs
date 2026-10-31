const assert=require('node:assert/strict');
const {launch,load}=require('./runtime.cjs');
(async()=>{const b=await launch();try{const p=await b.newPage({reducedMotion:'reduce'});const errors=[];p.on('pageerror',e=>errors.push(e.message));await load(p);
for(const [width,height] of [[320,740],[390,844],[1280,900]])for(const count of [3,4]){
 await p.setViewportSize({width,height});
 await p.evaluate(count=>{META.onboarding={seen:true};newGame(0,'classic',{campaign:true});hideOverlay();G.extraTables=count===4?1:0;G.jokers=[{...JOKERS.find(j=>j.id==='wide')}];startSeat();render();},count);
 let baseline;
 for(let n=0;n<=5;n++){
  const result=await p.evaluate(n=>{G.seat.tables.forEach((t,i)=>{t.cards=Array.from({length:n},(_,k)=>({...G.runDeck.find(c=>c.rank==='2'&&c.suit==='♠'),id:'layout-'+i+'-'+k,mod:['gold','glass','heavy','wild'][k%4]}));});refreshTables(G.seat);render();return {height:document.querySelector('.tables').getBoundingClientRect().height,footer:document.querySelector('.t-footer').getBoundingClientRect().top,damage:document.querySelector('#seat-stats').getBoundingClientRect().top,overflow:document.documentElement.scrollWidth>innerWidth,fits:[...document.querySelectorAll('.tbl')].every(t=>{const cards=t.querySelectorAll('.card');return !cards.length||cards[cards.length-1].getBoundingClientRect().bottom<=t.querySelector('.t-feedback').getBoundingClientRect().top})};},n);
  if(!baseline)baseline=result;
  assert.equal(result.height,baseline.height);assert.equal(result.footer,baseline.footer);assert.equal(result.damage,baseline.damage);assert.equal(result.overflow,false);assert(result.fits);
 }
 await p.evaluate(()=>{G.cons=[CONS.minus2];G.seat.sel=0;render();});
 assert.equal(await p.locator('.tables').evaluate(e=>e.getBoundingClientRect().height),baseline.height);
 if(width===390&&count===3){await p.evaluate(()=>{G.seat.sel=null;render();});await p.screenshot({path:'/tmp/vochko-stable-tables.png'});}
 console.log(width+'px / '+count+' tables: 0–5 cards and preview stable');
}
assert.deepEqual(errors,[]);
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1});
