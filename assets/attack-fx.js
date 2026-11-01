/* Cosmetic-only choreography. All game mutations still go through finishSeat. */
const AttackFX = {
  active:null,receipt:null,receiptTimer:0,deals:new Set(),
  styleProps:('display position inset top right bottom left box-sizing width height min-width min-height max-width max-height '+
    'margin padding border border-radius outline outline-offset box-shadow background background-color background-image background-size '+
    'background-position background-repeat background-clip background-origin background-blend-mode color opacity filter mix-blend-mode text-shadow '+
    '-webkit-text-stroke -webkit-text-fill-color -webkit-background-clip font font-family font-size font-style font-weight '+
    'font-variant font-stretch line-height letter-spacing word-spacing text-align text-transform white-space text-overflow '+
    'text-decoration flex flex-direction flex-wrap flex-grow flex-shrink flex-basis align-items align-content align-self '+
    'justify-content justify-items justify-self order gap row-gap column-gap grid-template-columns grid-template-rows '+
    'grid-auto-flow grid-column grid-row place-items place-content transform transform-origin rotate translate scale '+
    'visibility z-index overflow clip-path').split(' '),
  cardCopy(card,root){
    const clone=card.cloneNode(true),source=[card,...card.querySelectorAll('*')],copies=[clone,...clone.querySelectorAll('*')];
    // Read everything first: one style recalculation instead of one per node.
    const styles=source.map(el=>{const cs=getComputedStyle(el),map={};for(const key of this.styleProps)map[key]=cs.getPropertyValue(key);return map;});
    copies.forEach((el,i)=>{const map=styles[i];for(const key in map)el.style.setProperty(key,map[key]);el.removeAttribute('id');});
    const r=card.getBoundingClientRect(),w=card.offsetWidth||r.width,h=card.offsetHeight||r.height;
    if(card.classList.contains('face')&&!card.classList.contains('m-curse')){
      // Court artwork is painted by ::before, which is scoped to .t-cards; move its box onto the clone.
      const art=getComputedStyle(card,'::before');
      if(art.display!=='none'&&art.top!=='auto')['top','right','bottom','left'].forEach(side=>clone.style.setProperty('--fx-art-'+side,art[side]));
    }
    Object.assign(clone.style,{position:'absolute',left:(r.left+(r.width-w)/2)+'px',top:(r.top+(r.height-h)/2)+'px',width:w+'px',height:h+'px',margin:'0',transform:'none',rotate:'0deg',translate:'none',animation:'none',transition:'none',pointerEvents:'none'});
    clone.setAttribute('aria-hidden','true');root.appendChild(clone);return clone;
  },
  deal(card,pile){
    if(REDUCED||document.hidden||!card?.animate||!pile)return;
    const root=document.createElement('div');root.className='attack-fx-layer';root.setAttribute('aria-hidden','true');document.body.appendChild(root);
    const clone=this.cardCopy(card,root),a=this.center(pile),b=this.center(card),dx=a.x-b.x,dy=a.y-b.y;
    const original=card.style.visibility;card.style.visibility='hidden';
    const animation=clone.animate([{transform:'translate('+dx+'px,'+dy+'px) rotate(-16deg) scale(.65)',opacity:.8},{transform:'translate('+(dx*.35)+'px,'+(dy*.35-20)+'px) rotate(6deg) scale(1.03)',opacity:1,offset:.65},{transform:'none',opacity:1}],{duration:300,easing:'cubic-bezier(.2,.65,.3,1)'});
    const clean=()=>{animation.cancel();root.remove();card.style.visibility=original;this.deals.delete(clean)};this.deals.add(clean);animation.finished.then(clean,clean);
  },
  visiblePoint(point){
    const style=getComputedStyle(document.body),top=parseFloat(style.paddingTop)||0,bottom=parseFloat(style.paddingBottom)||0;
    return {x:Math.max(40,Math.min(innerWidth-40,point.x)),y:Math.max(top+55,Math.min(innerHeight-bottom-135,point.y))};
  },
  clearReceipt(){clearTimeout(this.receiptTimer);this.receipt?.getAnimations().forEach(a=>a.cancel());this.receipt?.remove();this.receipt=null},
  showReceipt(hit,result){
    if(document.hidden||(!REDUCED&&(hit.hp||hit.absorbed)))return;this.clearReceipt();
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
  previewHealth(run,hpDamage,shieldDamage){
    run.healthPreview=true;
    const enemy=run.game.enemy,hp=Math.max(0,run.startHp-hpDamage),shield=Math.max(0,run.startShield-shieldDamage);
    $('#enemy-hp').textContent=fmt(hp)+' / '+fmt(enemy.maxHp);
    $('#enemy-health').style.width=(100*hp/enemy.maxHp)+'%';
    $('#enemy-health').parentElement.setAttribute('aria-valuenow',hp);
    $('#enemy-defense').textContent='щит '+fmt(shield)+(enemy.armor?' · броня '+Math.round(enemy.armor*100)+'%':'');
  },
  cardImpact(run,point,progress){
    if(!this.valid(run))return;
    // Apportion the already-computed attack, shield first. Only finishSeat changes game state.
    const work=Math.floor((run.hit.hp+run.hit.absorbed)*progress);
    const shield=Math.min(run.hit.absorbed,work),hp=Math.min(run.hit.hp,Math.max(0,work-run.hit.absorbed));
    const hpDelta=hp-run.shownHp,shieldDelta=shield-run.shownShield;
    run.shownHp=hp;run.shownShield=shield;run.cardImpacts++;
    this.previewHealth(run,hp,shield);
    const flash=this.node(run,'attack-card-impact'+(shieldDelta&&!hpDelta?' shield-impact':''),point);
    flash.dataset.hp=hpDelta;flash.dataset.shield=shieldDelta;
    this.animate(run,flash,[{opacity:1,transform:'translate(-50%,-50%) scale(.4)'},{opacity:1,transform:'translate(-50%,-50%) scale(1.15)',offset:.25},{opacity:0,transform:'translate(-50%,-50%) scale(1.7)'}],{duration:230,easing:'ease-out'});
    const label=run.damageLabel||(run.damageLabel=this.node(run,'attack-card-damage',{x:Math.max(80,Math.min(innerWidth-80,point.x+24)),y:Math.max(32,point.y-24)}));
    label.classList.toggle('shield-damage',!hp&&shield>0);
    label.textContent=hp?'−'+fmt(hp)+' HP':shield?'ЩИТ −'+fmt(shield):'БЛОК';
    run.damagePulse?.cancel();
    run.damagePulse=this.animate(run,label,[{opacity:1,transform:'translate(-50%,0) scale(1.12)'},{opacity:1,transform:'translate(-50%,-8px) scale(1)',offset:.5},{opacity:0,transform:'translate(-50%,-24px) scale(.95)'}],{duration:400,easing:'ease-out'});
    run.recoil?.cancel();
    run.recoil=this.animate(run,run.portrait,[{translate:'0 0',filter:run.portraitFilter},{translate:'4px -2px',filter:run.portraitFilter+' brightness(1.8)',offset:.25},{translate:'-2px 1px',filter:run.portraitFilter,offset:.6},{translate:'0 0',filter:run.portraitFilter}],{duration:140,easing:'ease-out',fill:'none'});
    if(typeof tgHaptic==='function')tgHaptic('light');
  },
  async strikeCards(run,cards){
    const weight=cards.reduce((sum,card)=>sum+card.weight,0);let delivered=0;
    const flights=cards.map((entry,index)=>{
      const {card}=entry,p=this.center(card),token=this.cardCopy(card,run.root);
      run.sources.push({card,visibility:card.style.visibility});card.style.visibility='hidden';
      const point={x:run.target.x+(index%3-1)*8,y:run.target.y+(index%2?5:-5)};
      const dx=point.x-p.x,dy=point.y-p.y,end='translate('+dx+'px,'+dy+'px) rotate(18deg)';
      delivered+=entry.weight;const progress=index===cards.length-1?1:delivered/weight;
      const flight=this.animate(run,token,[{transform:'translate(0,0) rotate(0deg) scale(1)',opacity:1},{transform:'translate('+(dx*.2)+'px,'+(dy*.2-20)+'px) rotate(-10deg) scale(1.04)',opacity:1,offset:.25},{transform:end+' scale(.5)',opacity:1}],{duration:MOBILE_FX?340:390,delay:index*95,easing:'cubic-bezier(.35,0,.8,.55)'});
      return flight.finished.then(()=>{
        if(!this.valid(run))return;
        this.cardImpact(run,point,progress);
        this.animate(run,token,[{transform:end+' scale(.5)',opacity:1},{transform:end+' scale(.15)',opacity:0}],{duration:120,easing:'ease-out'});
      });
    });
    await Promise.all(flights);
  },
  valid(run) {return this.active===run&&G===run.game&&G.seat===run.seat&&G.phase==='play'},
  cleanup(run) {
    run.animations.forEach(animation=>animation.cancel());
    if(run.frame)cancelAnimationFrame(run.frame);
    if(run.countResolve){const resolve=run.countResolve;run.countResolve=null;resolve()}
    run.root.remove();
    (run.sources||[]).forEach(({card,visibility})=>{card.style.visibility=visibility});
    if(this.active===run){this.active=null;document.body.classList.remove('attack-busy');$('#btn-rules').disabled=false}
    if(run.healthPreview&&!run.committed&&G===run.game&&!this.active){BattleUI.prev=null;BattleUI.render();}
    run.tables.forEach(element=>element.classList.remove('attack-charging','attack-fizzle','attack-tally'));
    if(run.previewNote&&run.previewNoteHome!=null&&run.previewNote.textContent==='Считаем очки…'){run.previewNote.textContent=run.previewNoteHome;run.previewNoteHome=null;}
    if(run.accumulator&&(!this.active||this.active===run))run.accumulator.classList.remove('attack-accumulator');
  },
  cancel() {this.deals.forEach(clean=>clean());if(this.active)this.cleanup(this.active);this.clearReceipt()},
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
  isMult(text){return /(?:[x×]\s*\d|\+\s*\d)/.test(text)},
  isGlobalMult(text){return /^(?:точность|масти|риск|синхронизация|равновесие|лесенка|всё или ничего|Авантюрист|Ярость должника)/.test(text)||/^возврат \+/.test(text)},
  pulseNumber(run,element,scale=1.16){
    if(!element?.animate)return;
    this.animate(run,element,[
      {transform:'translate(-50%,-50%) scale(1)'},
      {transform:'translate(-50%,-50%) scale('+scale+')',offset:.4},
      {transform:'translate(-50%,-50%) scale(1)'}
    ],{duration:200,easing:'ease-out',fill:'none'});
  },
  pulseTag(text){
    const chip=[...document.querySelectorAll('#tags .tag')].find(el=>el.textContent.trim()===String(text).trim());
    if(!chip)return;
    chip.classList.remove('punch');void chip.offsetWidth;chip.classList.add('punch');
    setTimeout(()=>chip.classList.remove('punch'),330);
  },
  multBadge(run,point,text){
    if(run.multBadge)run.multBadge.remove();
    const badgePoint={x:Math.max(24,Math.min(innerWidth-24,point.x)),y:Math.max(28,point.y-40)};
    const badge=this.node(run,'attack-mult-badge',badgePoint,text);
    run.multBadge=badge;
    const animation=this.animate(run,badge,[
      {opacity:0,transform:'translate(-50%,-50%) scale(.6)'},
      {opacity:1,transform:'translate(-50%,-50%) scale(1.06)',offset:.25},
      {opacity:1,transform:'translate(-50%,-50%) scale(1)',offset:.62},
      {opacity:0,transform:'translate(-50%,-62%) scale(.95)'}
    ],{duration:420,easing:'ease-out',fill:'none'});
    animation.finished.then(()=>{if(run.multBadge===badge){badge.remove();run.multBadge=null}},()=>{});
  },
  countTo(run,element,from,to,duration){
    return new Promise(resolve=>{
      if(!element){resolve();return}
      if(this.active!==run||!element.animate){element.textContent=fmt(to);resolve();return}
      const finish=()=>{run.countResolve=null;resolve()};
      run.countResolve=finish;
      const start=performance.now();let lastText=0;
      const step=now=>{
        if(this.active!==run){finish();return}
        const progress=Math.min(1,(now-start)/Math.max(1,duration));
        if(!MOBILE_FX||now-lastText>=33||progress===1){element.textContent=fmt(Math.round(from+(to-from)*progress));lastText=now;}
        if(progress<1)run.frame=requestAnimationFrame(step);else finish();
      };
      run.frame=requestAnimationFrame(step);
    });
  },
  async play(game,seat,result) {
    this.cancel();
    const root=document.createElement('div');root.className='attack-fx-layer';root.setAttribute('aria-hidden','true');document.body.appendChild(root);
    const run={game,seat,root,animations:[],tables:[],sources:[],committed:false,frame:0,cardImpacts:0,shownHp:0,shownShield:0};this.active=run;
    run.commit=animated=>{if(this.valid(run)&&!run.committed){run.committed=true;const hit=attackPreview(result);finishSeat(result,animated);this.showReceipt(hit,result)}};
    const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
    try{
      if(REDUCED||document.hidden||typeof root.animate!=='function'){run.commit(false);return}
      document.body.classList.add('attack-busy');$('#btn-rules').disabled=true;
      run.accumulator=$('.fbox.result');
      run.portrait=$('#enemy-portrait');
      const portraitRect=run.portrait?.getBoundingClientRect();
      const safeTop=parseFloat(getComputedStyle(document.body).paddingTop)||0;
      if(portraitRect&&(portraitRect.top<safeTop||portraitRect.bottom>innerHeight))window.scrollBy({top:portraitRect.top-safeTop-8,behavior:'instant'});
      const rawOrigin=this.center(run.accumulator),rawTarget=this.center(run.portrait);
      if(!rawOrigin||!rawTarget){run.commit(false);return}
      const origin=this.visiblePoint(rawOrigin),target=rawTarget;
      const forecast=combatForecast(result);
      run.hit=forecast.hit;run.target=target;run.startHp=game.enemy.hp;run.startShield=game.enemy.shield;
      const filter=getComputedStyle(run.portrait).filter;run.portraitFilter=filter==='none'?'brightness(1)':filter;
      const caption=this.node(run,'attack-caption',{x:origin.x,y:origin.y+29},result.total?'ОЧКИ':'НЕТ УРОНА');
      const number=this.node(run,'attack-charge-number',{x:origin.x,y:origin.y},'0');
      run.accumulator.classList.add('attack-accumulator');
      run.previewNote=$('#preview-note');
      run.previewNoteHome=run.previewNote?.textContent;
      if(run.previewNote)run.previewNote.textContent='Считаем очки…';
      const attackingCards=[];
      result.tables.forEach((table,index)=>{
        if(table.empty)return;
        const lane=document.querySelector('#hand .tbl[data-t="'+index+'"]');if(!lane)return;
        run.tables.push(lane);
        const cards=[...lane.querySelectorAll('.t-cards .card:not(.tarot-card)')];
        if(table.bust){
          lane.classList.add('attack-fizzle');
          const p=this.center(lane);
          for(let j=0;j<(MOBILE_FX?2:4);j++){
            const spark=this.node(run,'attack-spark attack-spark-red',p);
            this.animate(run,spark,[{transform:'translate(-50%,-50%) scale(1)',opacity:.8},{transform:'translate('+((RNG0()-.5)*65)+'px,'+(20+RNG0()*35)+'px) scale(0)',opacity:0}],{duration:320,delay:j*25,easing:'ease-out'});
          }
          return;
        }
        if(table.score>0)cards.forEach(card=>attackingCards.push({card,weight:table.score/cards.length}));
      });
      if(!result.total){number.hidden=true;await pause(220);run.commit(false);return}
      // Score the tables one at a time so the number climbs instead of appearing at once.
      let shown=0;
      for(let index=0;index<result.tables.length;index++){
        const table=result.tables[index];
        if(table.empty||table.bust)continue;
        const lane=run.tables.find(element=>element.dataset.t===String(index));
        if(lane)lane.classList.add('attack-charging');
        caption.textContent='СТОЛ '+(index+1);
        await this.countTo(run,number,shown,shown+table.score,MOBILE_FX?150:190);
        if(!this.valid(run))return;
        shown+=table.score;
        if(lane){
          const point=this.center(lane);
          if(point){
            const pop=this.node(run,'attack-lane-score',point,'+'+fmt(table.score));
            this.animate(run,pop,[{opacity:0,transform:'translate(-50%,-50%) scale(.7)'},{opacity:1,transform:'translate(-50%,-50%) scale(1.08)',offset:.3},{opacity:0,transform:'translate(-50%,-72%) scale(.95)'}],{duration:560,easing:'ease-out',fill:'none'});
          }
        }
        this.pulseNumber(run,number);
        const mults=(table.tags||[]).filter(text=>this.isMult(text)).slice(0,MOBILE_FX?2:4);
        for(const text of mults){
          this.multBadge(run,origin,text);
          this.pulseTag(text);
          this.pulseNumber(run,number,1.22);
          if(typeof tgHaptic==='function')tgHaptic('light');
          await pause(MOBILE_FX?70:95);
          if(!this.valid(run))return;
        }
        if(lane){lane.classList.remove('attack-charging');lane.classList.add('attack-tally');}
        await pause(60);
        if(!this.valid(run))return;
      }
      // Global bonuses land as separate hits while the total finishes climbing.
      const globals=result.tags.filter(text=>this.isGlobalMult(text));
      if(globals.length)caption.textContent='БОНУСЫ';
      const tally=this.countTo(run,number,shown,result.total,Math.max(MOBILE_FX?180:240,globals.length*(MOBILE_FX?110:135)));
      for(const text of globals){
        this.multBadge(run,origin,text);
        this.pulseTag(text);
        this.pulseNumber(run,number,1.24);
        if(typeof tgHaptic==='function')tgHaptic('light');
        await pause(MOBILE_FX?85:110);
        if(!this.valid(run))return;
      }
      await tally;
      if(!this.valid(run))return;
      number.textContent=fmt(result.total);
      this.pulseNumber(run,number,1.3);
      if(run.previewNote&&run.previewNoteHome!=null){run.previewNote.textContent=run.previewNoteHome;run.previewNoteHome=null;}
      caption.textContent=result.exact?'ТОЧНЫЙ УДАР':'УДАР';
      // The tally finishes before cards launch; each collision drains the displayed HP or shield.
      this.animate(run,number,[{opacity:1},{opacity:0}],{duration:120});
      caption.textContent='КАРТЫ АТАКУЮТ';
      await this.strikeCards(run,attackingCards);
      if(!this.valid(run))return;
      caption.textContent='';
      run.commit(true);
      await pause(430);
    }catch(_){
      // Rendering failures must never block a turn or duplicate an attack.
      if(this.valid(run)){if(!run.committed)run.commit(false);else run.response?.()}
    }finally{this.cleanup(run)}
  }
};
document.addEventListener('visibilitychange',()=>{if(document.hidden){AttackFX.deals.forEach(clean=>clean());AttackFX.flush();AttackFX.clearReceipt()}});
