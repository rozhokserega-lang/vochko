/* Healing is an event, not the net HP delta after the enemy counterattack. */
const HealingFX={
  pending:[],frame:0,active:null,
  point(element){
    if(!element)return null;
    const r=element.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};
  },
  record(game,amount,before,source='heal'){
    if(!(amount>0)||document.hidden)return;
    const options=typeof source==='string'?{kind:source}:source;
    const points=[];
    if(options.kind==='tables'&&game.seat){
      game.seat.tables.forEach((table,index)=>{
        const paint=paintOf(table);
        if(paint?.kind==='heal'&&!evalPlay(table.cards,table.adj).bust){
          const point=this.point(document.querySelector('#hand .tbl[data-t="'+index+'"] .t-cards'));
          if(point)points.push(point);
        }
      });
    }else{
      const element=options.element||(document.activeElement?.tagName==='BUTTON'?document.activeElement:null);
      const point=this.point(element);if(point)points.push(point);
    }
    this.pending.push({game,amount,before,after:game.player.hp,maxHp:game.player.maxHp,points,kind:options.kind});
    document.querySelector('.player-row')?.classList.add('hp-restoring');
    if(!this.frame)this.frame=requestAnimationFrame(()=>this.show());
  },
  node(run,className,point,text=''){
    const node=document.createElement('span');node.className=className;node.textContent=text;
    node.style.left=point.x+'px';node.style.top=point.y+'px';run.root.appendChild(node);return node;
  },
  animate(run,node,frames,options){
    if(typeof node.animate!=='function')return;
    const animation=node.animate(frames,{fill:'forwards',...options});run.animations.push(animation);return animation;
  },
  show(){
    this.frame=0;
    const events=this.pending.splice(0).filter(event=>event.game===G);
    if(!events.length||document.hidden)return;
    this.clearActive();
    const last=events[events.length-1],amount=events.reduce((sum,event)=>sum+event.amount,0);
    const shopTarget=document.querySelector('#shop-player-hp');
    const shop=!!shopTarget&&!document.querySelector('#overlay').classList.contains('hidden');
    const target=shop?shopTarget:document.querySelector('#player-hp');
    const rawPoint=this.point(target);if(!rawPoint)return;
    const rootStyle=getComputedStyle(document.body),top=parseFloat(rootStyle.paddingTop)||0,bottom=parseFloat(rootStyle.paddingBottom)||0;
    const point={x:Math.max(65,Math.min(innerWidth-65,rawPoint.x)),y:Math.max(top+35,Math.min(innerHeight-bottom-35,rawPoint.y))};
    const root=document.createElement('div');root.className='heal-fx-layer';root.setAttribute('aria-hidden','true');document.body.appendChild(root);
    const run={game:G,root,animations:[],barFrame:0,timer:0,shop,motes:[]};this.active=run;
    const announcement=document.querySelector('#heal-announcement')||Object.assign(document.createElement('div'),{id:'heal-announcement',className:'sr-only'});
    announcement.setAttribute('role','status');announcement.setAttribute('aria-live','polite');
    if(!announcement.isConnected)document.body.appendChild(announcement);
    announcement.textContent='Восстановлено '+amount+' здоровья. '+last.after+' из '+last.maxHp+'.';
    const row=shop?document.querySelector('.shop-health'):document.querySelector('.player-row');
    run.row=row;row?.classList.add('hp-restoring');
    const labelPoint=shop?{x:point.x,y:point.y-44}:{x:Math.min(innerWidth-65,point.x+110),y:point.y-18};
    const label=this.node(run,'heal-gain-label',labelPoint,'+'+amount+' HP');
    if(REDUCED){run.timer=setTimeout(()=>this.finish(run),850);return}
    this.animate(run,label,[{transform:'translate(-50%,7px) scale(.9)',opacity:0},{transform:'translate(-50%,-3px) scale(1.08)',opacity:1,offset:.18},{transform:'translate(-50%,-24px) scale(1)',opacity:0}],{duration:1050,easing:'ease-out'});
    const ring=this.node(run,'heal-impact-ring',point);
    this.animate(run,ring,[{transform:'translate(-50%,-50%) scale(.35)',opacity:.8},{transform:'translate(-50%,-50%) scale(1.8)',opacity:0}],{duration:650,easing:'ease-out'});
    const sources=events.flatMap(event=>event.points);
    if(!sources.length)sources.push({x:point.x+42,y:point.y+24});
    sources.slice(0,4).forEach((source,index)=>{
      for(let i=0;i<(MOBILE_FX?2:4);i++){
        const mote=this.node(run,'heal-mote',source,i===0?'♥':'');run.motes.push(mote);
        this.animate(run,mote,[{transform:'translate(-50%,-50%) scale(.6)',opacity:0},{transform:'translate(-50%,-50%) scale(1)',opacity:1,offset:.15},{transform:'translate('+(point.x-source.x-5)+'px,'+(point.y-source.y-5)+'px) scale(.3)',opacity:0}],{duration:400,delay:index*35+i*28,easing:'cubic-bezier(.25,.7,.4,1)'});
      }
    });
    // Shop panels are rebuilt after each purchase, so animate their new bar explicitly.
    const bar=shop?document.querySelector('#shop-player-health'):null;
    if(bar)this.animate(run,bar,[{width:100*events[0].before/last.maxHp+'%'},{width:100*last.after/last.maxHp+'%'}],{duration:600,easing:'cubic-bezier(.2,.7,.3,1)',fill:'none'});
    run.timer=setTimeout(()=>this.finish(run),1100);
  },
  onDamage(game){
    document.querySelector('.player-row')?.classList.remove('hp-restoring');
    if(this.active?.game===game&&!this.active.shop)this.active.motes.forEach(mote=>mote.hidden=true);
  },
  finish(run){
    clearTimeout(run.timer);run.animations.forEach(animation=>animation.cancel());run.root.remove();
    if(this.active===run){this.active=null;run.row?.classList.remove('hp-restoring')}
  },
  clearActive(){if(this.active)this.finish(this.active)},
  cancel(){
    if(this.frame)cancelAnimationFrame(this.frame);this.frame=0;this.pending=[];this.clearActive();
    document.querySelector('.player-row')?.classList.remove('hp-restoring');
    document.querySelector('.shop-health')?.classList.remove('hp-restoring');
  }
};
document.addEventListener('visibilitychange',()=>{if(document.hidden)HealingFX.cancel()});
