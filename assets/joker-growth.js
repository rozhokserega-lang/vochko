/* Run-owned progress survives selling; effects require owning the joker. */
const JOKER_GROWTH={
 crimson:{goal:4,task:'Сыграй 4 красных стола из 3+ карт без перебора.',branches:{bloom:{name:'Алая роза',desc:'Лечение красных столов ×2 вместо ×1,5.'},ward:{name:'Терновый щит',desc:'Каждый красный стол из 3+ карт без перебора даёт 4 щита перед ответом врага.'}}},
 precision:{goal:8,task:'Сыграй 8 столов с точной суммой.',branches:{master:{name:'Мастер точности',desc:'Каждый точный стол даёт +35% к урону хода вместо +25%.'},remedy:{name:'Верная рука',desc:'Каждый точный стол дополнительно восстанавливает 3 HP.'}}},
 insurer:{goal:6,task:'Сыграй 6 столов с перебором.',branches:{premium:{name:'Полная страховка',desc:'Каждый перебор приносит $3 вместо $2.'},cover:{name:'Мягкая посадка',desc:'Штраф за каждый перебор снижается с 2 до 1 урона. Атаки врага не ослабляются.'}}}
};
function growthState(id){const state=G?.jokerGrowth?.[id];return {progress:Math.min(JOKER_GROWTH[id]?.goal||0,Math.max(0,Number(state?.progress)||0)),branch:JOKER_GROWTH[id]?.branches[state?.branch]?state.branch:null};}
function growthIs(id,branch){return hasJoker(id)&&growthState(id).branch===branch;}
function growthTooltip(id){const def=JOKER_GROWTH[id];if(!def)return '';const s=growthState(id);return '<br><b>Развитие: '+(s.branch?def.branches[s.branch].name:s.progress+' / '+def.goal)+'</b><br>'+(s.branch?def.branches[s.branch].desc:def.task);}
function bustPenalty(){return growthIs('insurer','cover')?Math.max(0,COMBAT.bustPenalty-1):COMBAT.bustPenalty;}
function recordJokerGrowth(result,seat){
 if(seat.growthRecorded)return;seat.growthRecorded=true;G.jokerGrowth=G.jokerGrowth||{};
 const counts={crimson:result.tables.filter(t=>!t.empty&&!t.bust&&t.paint?.kind==='heal').length,precision:result.exact,insurer:result.bust};
 for(const [id,amount] of Object.entries(counts))if(amount&&hasJoker(id)){
  const state=growthState(id);if(!state.branch)G.jokerGrowth[id]={progress:Math.min(JOKER_GROWTH[id].goal,state.progress+amount),branch:null};
 }
}
function growthSummary(shop=false){
 const owned=G.jokers.filter(j=>JOKER_GROWTH[j.id]);if(!owned.length)return '';
 return '<section class="growth-panel"><h3>Развитие джокеров</h3>'+owned.map(j=>{
  const def=JOKER_GROWTH[j.id],state=growthState(j.id),ready=state.progress>=def.goal;
  return '<div class="growth-row"><b>'+j.name+(state.branch?' · '+def.branches[state.branch].name:'')+'</b>'+(state.branch?'<span class="growth-branch">'+def.branches[state.branch].desc+'</span>':'<span>'+state.progress+' / '+def.goal+' · '+(ready?'Улучшение доступно':def.task)+'</span><progress value="'+state.progress+'" max="'+def.goal+'" aria-label="Прогресс развития '+j.name+'"></progress>'+(ready&&shop?'<button class="primary" data-growth="'+j.id+'">Выбрать улучшение</button>':ready?'<small>Выбери улучшение в следующем магазине.</small>':''))+'</div>';
 }).join('')+'</section>';
}
function bindGrowthButtons(){document.querySelectorAll('[data-growth]').forEach(b=>b.onclick=()=>showGrowthChoice(b.dataset.growth));}
function showGrowthChoice(id){
 const def=JOKER_GROWTH[id],state=growthState(id);if(G.phase!=='shop'||!hasJoker(id)||!def||state.branch||state.progress<def.goal)return;
 G.evolutionChoice=id;saveRun();const j=JOKERS.find(j=>j.id===id);
 showOverlay('<div class="kicker">Развитие джокера · до конца забега</div><h2>'+j.name+'</h2><p class="sub">Выбери одну ветку. Основной эффект сохраняется; замена множителя указана в описании. Выбор окончательный.</p><div class="growth-choices">'+Object.entries(def.branches).map(([key,b])=>'<section class="growth-row"><h3>'+b.name+'</h3><p>'+b.desc+'</p><button class="primary" data-growth-branch="'+key+'">Выбрать «'+b.name+'»</button></section>').join('')+'</div><div class="row-btns"><button class="ghost" id="growth-later">Решить позже</button></div>');
 document.querySelectorAll('[data-growth-branch]').forEach(b=>b.onclick=()=>chooseGrowth(id,b.dataset.growthBranch));$('#growth-later').onclick=()=>{G.evolutionChoice=null;renderShop();saveRun();};
}
function chooseGrowth(id,branch){
 const def=JOKER_GROWTH[id],state=growthState(id);if(G.phase!=='shop'||G.evolutionChoice!==id||!hasJoker(id)||!def?.branches[branch]||state.branch||state.progress<def.goal)return;
 G.jokerGrowth=G.jokerGrowth||{};G.jokerGrowth[id]={progress:def.goal,branch};G.evolutionChoice=null;log('Развитие: '+def.branches[branch].name,'gold');render();renderShop();saveRun();
}
