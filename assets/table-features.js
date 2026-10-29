/* Assigned once per battle; no draw-order access or passive timers. */
const TABLE_FEATURES={
 duo:{name:'Дуэт',short:'2 карты',bonus:15,desc:'Ровно 2 карты без перебора: урон этого стола +15%.',test:(t,r)=>t.cards.length===2},
 trio:{name:'Тройка',short:'3 карты',bonus:20,desc:'Ровно 3 карты без перебора: урон этого стола +20%.',test:(t,r)=>t.cards.length===3},
 long:{name:'Добор',short:'4+ карты',bonus:20,desc:'Не менее 4 карт без перебора: урон этого стола +20%.',test:(t,r)=>t.cards.length>=4},
 low:{name:'Мелочь',short:'2 малые',bonus:25,desc:'Не менее двух карт рангов 2–5 без перебора: урон этого стола +25%. Остальные карты могут быть любыми.',test:(t,r)=>t.cards.filter(c=>['2','3','4','5'].includes(c.rank)).length>=2},
 near:{name:'Рядом',short:'Цель −1',bonus:20,desc:'Сумма на единицу ниже текущей цели, без перебора: урон этого стола +20%.',test:(t,r)=>r.sum===limitNow()-1}
};
function assignTableFeatures(){
 if(G.ante===1&&G.blind===0&&!G.elite){G.tableFeatures=[];return;}
 const max3=[G.boss,G.boss2].includes('max3');
 G.tableFeatures=shuffle(Object.keys(TABLE_FEATURES).filter(id=>!max3||id!=='long')).slice(0,tablesPerSeat());
}
function tableFeature(ti){return TABLE_FEATURES[G.tableFeatures?.[ti]]||null;}
function featureActive(t,ti,r=evalPlay(t.cards,t.adj)){const def=tableFeature(ti);return !!(def&&!t.blocked&&t.cards.length&&!r.bust&&def.test(t,r));}
function featureMultiplier(t,ti,r){return featureActive(t,ti,r)?1+tableFeature(ti).bonus/100:1;}
function tableFeatureBadge(t,ti,r){const def=tableFeature(ti);if(!def)return '';const active=r&&featureActive(t,ti,r);return '<div class="table-feature'+(active?' feature-active':'')+'" title="'+def.desc+'" aria-label="'+def.name+'. '+def.desc+(active?' Бонус активен.':' Бонус пока не активен.')+'"><b>'+def.name+'<i aria-hidden="true">'+(active?'✓':'·')+'</i></b><span>'+def.short+' · +'+def.bonus+'%</span></div>';}
function tableFeaturesSummary(expanded=false){
 if(!G.tableFeatures?.length)return '';
 return '<details class="run-talent table-feature-summary" data-run-panel="tables"'+(expanded?' open':'')+'><summary>Особенности столов · этот бой</summary>'+G.tableFeatures.map((id,i)=>TABLE_FEATURES[id]?'<p><b>Стол '+(i+1)+' · '+TABLE_FEATURES[id].name+'</b><br>'+TABLE_FEATURES[id].desc+'</p>':'').join('')+'<small>Не меняют сумму карт. Условия проверяются при розыгрыше. Бонусы разных столов не складываются друг с другом.</small></details>';
}
