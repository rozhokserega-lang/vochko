/* Suit editing changes colour consistently; never replaces card identity. */
function forgeSuitChoice(id){
 const c=G.runDeck.find(c=>c.id===id);if(G.phase!=='path'||G.pending!=='forge'||G.forgeMode!=='suit'||!c)return;
 G.forgeSelection=id;
 if(c.mod==='curse'){flashHint('Проклятую карту нельзя перекрасить. Её можно удалить.');return;}
 if(SUITS.some(s=>s.sym===G.forgeSuit&&s.sym!==c.suit)){forgeSuitConfirm(id);return;}
 saveRun();showOverlay(GameMenu.sceneHeader('campfire','Кузница · смена масти','Выбери новую масть','Значение, чипы, печать и улучшения карты сохранятся. Цвет изменится вместе с мастью.')+'<div class="forge-preview">'+cardElement(c,{mini:1})+'</div><div class="suit-options">'+SUITS.map(s=>'<button class="ghost suit-option '+s.color+'" data-forge-suit="'+s.sym+'" '+(s.sym===c.suit?'disabled':'')+' aria-label="'+({'♠':'Пики','♥':'Червы','♦':'Бубны','♣':'Трефы'})[s.sym]+'">'+s.sym+'</button>').join('')+'</div><div class="row-btns"><button class="ghost" id="suit-back">Назад к картам</button></div>');
 document.querySelectorAll('[data-forge-suit]').forEach(b=>b.onclick=()=>{G.forgeSuit=b.dataset.forgeSuit;forgeSuitConfirm(id);});$('#suit-back').onclick=()=>forgeAction('suit');
}
function forgeSuitConfirm(id){
 const c=G.runDeck.find(c=>c.id===id),suit=SUITS.find(s=>s.sym===G.forgeSuit);if(!c||!suit||c.suit===suit.sym)return;
 saveRun();showOverlay(GameMenu.sceneHeader('campfire','Кузница · подтверждение','Изменить масть?')+'<div class="forge-preview">'+cardElement(c,{mini:1})+'<span aria-hidden="true">→</span>'+cardElement({...c,suit:suit.sym,color:suit.color},{mini:1})+'</div><p class="forge-preview-label">'+c.rank+c.suit+' → '+c.rank+suit.sym+'. Цвет: '+(suit.color==='red'?'красный':'чёрный')+'. Значение и чипы не меняются. Это единственное действие в кузнице.</p><div class="row-btns"><button class="ghost" id="suit-back">Другая масть</button><button class="primary" id="suit-accept">Подтвердить</button></div>');
 $('#suit-back').onclick=()=>{G.forgeSuit=null;forgeSuitChoice(id);};$('#suit-accept').onclick=()=>applySuitChange(id);
}
function applySuitChange(id){
 if(G.phase!=='path'||G.pending!=='forge'||G.forgeMode!=='suit'||G.forgeSelection!==id)return;
 const c=G.runDeck.find(c=>c.id===id),suit=SUITS.find(s=>s.sym===G.forgeSuit);if(!c||c.mod==='curse'||!suit||suit.sym===c.suit)return;
 const before=c.rank+c.suit;c.suit=suit.sym;c.color=suit.color;G.suitsChanged=(G.suitsChanged||0)+1;
 unlockAch('repaint');if(G.suitsChanged>=3)unlockAch('palette');
 G.forgeSuit=null;log('Кузница: '+before+' → '+c.rank+c.suit,'gold');nodeResult('Новая масть',before+' → '+c.rank+c.suit+'. Значение и чипы сохранены.','forgeDone');
}
function syncProgressionUnlocks(){
 const saved=readSavedRun();
 if(META.ach.blackout){META.ach.nightdeck=true;META.unlocked['deck:nocturne']=true;}
 if(Object.values(saved?.game?.jokerGrowth||{}).some(s=>s.branch)){META.ach.evolution=true;META.unlocked['talent:warden']=true;}
 metaSave();
}
