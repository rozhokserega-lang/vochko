/* Cosmetic-only choreography. All game mutations still go through finishSeat. */
const AttackFX = {
  active:null,receipt:null,receiptTimer:0,
  visiblePoint(point){
    const style=getComputedStyle(document.body),top=parseFloat(style.paddingTop)||0,bottom=parseFloat(style.paddingBottom)||0;
    return {x:Math.max(40,Math.min(innerWidth-40,point.x)),y:Math.max(top+55,Math.min(innerHeight-bottom-135,point.y))};
  },
  clearReceipt(){clearTimeout(this.receiptTimer);this.receipt?.getAnimations().forEach(a=>a.cancel());this.receipt?.remove();this.receipt=null},
  showReceipt(hit,result){
    if(document.hidden)return;this.clearReceipt();
    const el=document.createElement('div');el.className='combat-receipt';el.setAttribute('role','status');
    el.textContent=hit.hp?'ПОПАДАНИЕ −'+fmt(hit.hp)+' HP'+(hit.absorbed?' · ЩИТ −'+fmt(hit.absorbed):''):hit.absorbed?'ЩИТ −'+fmt(hit.absorbed):result.bust?'ПЕРЕБОР · БЕЗ УРОНА':'БЕЗ УРОНА';
    document.body.appendChild(el);this.receipt=el;
    if(!REDUCED&&el.animate)el.animate([{opacity:0,translate:'0 6px'},{opacity:1,translate:'0 0',offset:.15},{opacity:1,offset:.8},{opacity:0,translate:'0 -6px'}],{duration:700});
    this.receiptTimer=setTimeout(()=>{if(this.receipt===el)this.clearReceipt()},750);
  },
  center(element) {
    if(!element)return null;
    const rect=element.getBoundingClientRect();
    return {x:rect.left+rect.width/2,y:rect.top+rect.height/2};
  },
  node(run,className,point,text='') {
    const element=document.createElement('span');element.className=className;element.textContent=text;
    if(point){element.style.left=point.x+'px';element.style.top=point.y+'px'}
    run.root.appendChild(element);return element;
  },
  animate(run,element,frames,options) {
    const animation=element.animate(frames,{fill:'forwards',...options});run.animations.push(animation);return animation;
  },
  valid(run) {return this.active===run&&G===run.game&&G.seat===run.seat&&G.phase==='play'},
  cleanup(run) {
    run.animations.forEach(animation=>animation.cancel());
    if(run.frame)cancelAnimationFrame(run.frame);
    run.root.remove();
    if(this.active===run){this.active=null;document.body.classList.remove('attack-busy');$('#btn-rules').disabled=false}
    run.tables.forEach(element=>element.classList.remove('attack-charging','attack-fizzle'));
    if(run.accumulator&&(!this.active||this.active===run))run.accumulator.classList.remove('attack-accumulator');
  },
  cancel() {if(this.active)this.cleanup(this.active);this.clearReceipt()},
  flush() {
    const run=this.active;if(!run)return;
    if(this.valid(run)){
      if(!run.committed)run.commit(false);
      else if(run.response)run.response();
    }
    this.cleanup(run);
  },
  deferResponse(game,seat,respond) {
    const run=this.active;
    if(!run||run.game!==game||run.seat!==seat||document.hidden){respond();return}
    run.response=respond;
    setTimeout(()=>{if(G===game&&G.seat===seat&&G.battle.resolving)respond()},270);
  },
  async play(game,seat,result) {
    this.cancel();
    const root=document.createElement('div');root.className='attack-fx-layer';root.setAttribute('aria-hidden','true');document.body.appendChild(root);
    const run={game,seat,root,animations:[],tables:[],committed:false,frame:0};this.active=run;
    run.commit=animated=>{if(this.valid(run)&&!run.committed){run.committed=true;const hit=attackPreview(result);finishSeat(result,animated);this.showReceipt(hit,result)}};
    const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
    try{
      if(REDUCED||document.hidden||typeof root.animate!=='function'){run.commit(false);return}
      document.body.classList.add('attack-busy');$('#btn-rules').disabled=true;
      run.accumulator=$('.fbox.result');
      const rawOrigin=this.center(run.accumulator),rawTarget=this.center($('#enemy-portrait'));
      if(!rawOrigin||!rawTarget){run.commit(false);return}
      const origin=this.visiblePoint(rawOrigin),target=this.visiblePoint(rawTarget);
      const forecast=combatForecast(result);
      const caption=this.node(run,'attack-caption',{x:origin.x,y:origin.y+29},result.total?'ЗАРЯД':'НЕТ УРОНА');
      const orb=this.node(run,'attack-orb',origin);
      const number=this.node(run,'attack-charge-number',{x:origin.x,y:origin.y-5},'0');
      run.accumulator.classList.add('attack-accumulator');
      let shard=0;
      result.tables.forEach((table,index)=>{
        if(table.empty)return;
        const lane=document.querySelector('#hand .tbl[data-t="'+index+'"]');if(!lane)return;
        run.tables.push(lane);lane.classList.add(table.bust?'attack-fizzle':'attack-charging');
        const cards=[...lane.querySelectorAll('.t-cards .card')];
        if(table.bust){
          const p=this.center(lane);
          for(let j=0;j<(MOBILE_FX?2:4);j++){
            const spark=this.node(run,'attack-spark attack-spark-red',p);
            this.animate(run,spark,[{transform:'translate(-50%,-50%) scale(1)',opacity:.8},{transform:'translate('+((RNG0()-.5)*65)+'px,'+(20+RNG0()*35)+'px) scale(0)',opacity:0}],{duration:320,delay:j*25,easing:'ease-out'});
          }
          return;
        }
        cards.forEach((card,ci)=>{
          if(MOBILE_FX&&ci>1)return;
          const p=this.center(card),delay=index*65+ci*22;
          const token=this.node(run,'attack-card-mote',p,card.dataset.s||'♠');
          token.classList.toggle('attack-exact-mote',!!table.exact);
          this.animate(run,token,[{transform:'translate(-50%,-50%) rotate(-8deg) scale(.8)',opacity:0},{transform:'translate(-50%,-65%) rotate(5deg) scale(1)',opacity:1,offset:.2},{transform:'translate('+(origin.x-p.x-8)+'px,'+(origin.y-p.y-11)+'px) rotate(100deg) scale(.15)',opacity:0}],{duration:310,delay,easing:'cubic-bezier(.4,0,.3,1)'});
          shard++;
        });
      });
      if(!result.total){orb.hidden=true;number.hidden=true;await pause(220);run.commit(false);return}
      const began=performance.now(),charge=forecast.hit.attack;
      let lastNumberFrame=0;
      const tick=now=>{
        if(this.active!==run)return;
        const progress=Math.min(1,(now-began)/480);
        if(!MOBILE_FX||now-lastNumberFrame>=33||progress===1){number.textContent=fmt(charge*progress);lastNumberFrame=now;}
        if(progress<1)run.frame=requestAnimationFrame(tick);
      };run.frame=requestAnimationFrame(tick);
      this.animate(run,orb,[{transform:'translate(-50%,-50%) scale(.2)',opacity:0},{transform:'translate(-50%,-50%) scale(1)',opacity:.9}],{duration:470,easing:'ease-out'});
      await pause(490);if(!this.valid(run))return;
      number.textContent=fmt(charge);caption.textContent=result.exact?'ТОЧНЫЙ УДАР':'УДАР';
      const dx=target.x-origin.x,dy=target.y-origin.y;
      const beam=this.node(run,'attack-beam',origin);beam.style.width=Math.hypot(dx,dy)+'px';beam.style.rotate=Math.atan2(dy,dx)+'rad';
      this.animate(run,beam,[{transform:'scaleX(0)',opacity:0},{transform:'scaleX(1)',opacity:.85,offset:.6},{transform:'scaleX(1)',opacity:0}],{duration:260,easing:'ease-out'});
      this.animate(run,orb,[{transform:'translate(-50%,-50%) scale(1)',opacity:1},{transform:'translate('+(dx-22)+'px,'+(dy-22)+'px) scale(.55)',opacity:.95}],{duration:220,easing:'cubic-bezier(.5,0,.9,.6)'});
      this.animate(run,number,[{opacity:1},{opacity:0,transform:'translate(-50%,-20px)'}],{duration:160});
      await pause(220);if(!this.valid(run))return;
      orb.style.visibility='hidden';caption.textContent=forecast.hit.hp?'ПОПАДАНИЕ':forecast.hit.absorbed?'В ЩИТ':'БЕЗ ПРОБИТИЯ';
      const ring=this.node(run,'attack-impact-ring'+(forecast.hit.absorbed?' shield-impact':''),target);
      this.animate(run,ring,[{transform:'translate(-50%,-50%) scale(.3)',opacity:1},{transform:'translate(-50%,-50%) scale(2.3)',opacity:0}],{duration:350,easing:'ease-out'});
      for(let j=0;j<Math.min(MOBILE_FX?5:14,6+shard);j++){
        const angle=RNG0()*Math.PI*2,distance=22+RNG0()*50;
        const spark=this.node(run,'attack-spark',target);
        this.animate(run,spark,[{transform:'translate(-50%,-50%) scale(1)',opacity:1},{transform:'translate('+(Math.cos(angle)*distance)+'px,'+(Math.sin(angle)*distance)+'px) scale(0)',opacity:0}],{duration:240+RNG0()*160,easing:'ease-out'});
      }
      if(forecast.hit.absorbed)this.node(run,'attack-shield-label',{x:target.x,y:target.y+34},'ЩИТ −'+fmt(forecast.hit.absorbed));
      run.commit(true);
      await pause(430);
    }catch(_){
      // Rendering failures must never block a turn or duplicate an attack.
      if(this.valid(run)){if(!run.committed)run.commit(false);else run.response?.()}
    }finally{this.cleanup(run)}
  }
};
document.addEventListener('visibilitychange',()=>{if(document.hidden){AttackFX.flush();AttackFX.clearReceipt()}});
