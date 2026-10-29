/* Keep dealt cards in place. No input queue and no frame loop. */
const FastDraw={timer:0,game:null,lastVisual:-Infinity,fade:null,
 html(el,html){if(el.innerHTML!==html)el.innerHTML=html;},
 save(){clearTimeout(this.timer);this.game=G;this.timer=setTimeout(()=>this.flush(),120);},
 flush(){clearTimeout(this.timer);this.timer=0;const game=this.game;this.game=null;if(game&&game===G)saveRun();},
 remember(html){document.querySelectorAll('#hand .tbl').forEach((el,i)=>el._drawHTML=html[i]);},
 hand(seat,scores,html){
  const root=document.querySelector('#hand .tables');if(!root||root.children.length!==seat.tables.length)return false;
  seat.tables.forEach((table,i)=>{
   const old=root.children[i],markup=html[i];if(old._drawHTML===markup)return;old._drawHTML=markup;
   const template=document.createElement('template');template.innerHTML=markup;const next=template.content.firstElementChild;
   old.className=next.className;old.setAttribute('aria-label',next.getAttribute('aria-label'));
   const keep=new Set();[...next.children].forEach((child,index)=>{
    const key=child.classList[0];let current=[...old.children].find(e=>e.classList[0]===key&&!keep.has(e));
    if(!current){current=child;old.insertBefore(current,old.children[index]||null);}
    else if(key==='t-cards'){
     const cards=new Map([...current.children].map(e=>[e.dataset.id,e]));
     [...child.children].forEach((card,ci)=>{let node=cards.get(card.dataset.id);if(node){node.className=card.className;cards.delete(card.dataset.id);}else node=card;if(current.children[ci]!==node)current.insertBefore(node,current.children[ci]||null);});
     cards.forEach(card=>card.remove());
    }else{[...child.attributes].forEach(a=>{if(current.getAttribute(a.name)!==a.value)current.setAttribute(a.name,a.value);});this.html(current,child.innerHTML);}
    if(old.children[index]!==current)old.insertBefore(current,old.children[index]||null);keep.add(current);
   });
   [...old.children].forEach(child=>{if(!keep.has(child))child.remove();});
  });return true;
 },
 appear(el){
  this.fade?.cancel();const now=performance.now(),rapid=now-this.lastVisual<180;this.lastVisual=now;
  if(!rapid&&el.animate)this.fade=el.animate([{opacity:.65},{opacity:1}],{duration:80});
 }
};
document.addEventListener('visibilitychange',()=>{if(document.hidden)FastDraw.flush()});
window.addEventListener('pagehide',()=>FastDraw.flush());
