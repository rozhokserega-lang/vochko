/* Four contextual hints, restricted to the first new dungeon attempt. */
const Tutorial={
 eligible(){return !META.onboarding?.seen&&!(META.stats.runs>0)&&!(META.campaign?.bestLevels?.[0]>0)&&!readSavedRun();},
 begin(){META.onboarding={seen:true,status:'started'};G.tutorialStep='draw';metaSave();},
 clear(){document.querySelector('#tutorial-coach')?.remove();document.querySelectorAll('.tutorial-target').forEach(el=>el.classList.remove('tutorial-target'));},
 finish(status='completed'){if(!G?.tutorialStep)return;G.tutorialStep=null;META.onboarding={seen:true,status};metaSave();this.clear();},
 action(action){
  if(!G?.tutorialStep||!G.campaign||G.level!==1)return;
  if(action==='play'){this.finish();return;}
  if(action==='stop'){G.tutorialStep='play';return;}
  if(action==='draw'){
   if(G.tutorialStep==='draw')G.tutorialStep='build';
   else if(G.tutorialStep==='build')G.tutorialStep=tableOpen(G.seat.tables[0])?'stop':'play';
  }
 },
 render(){
  if(!G?.tutorialStep||!G.campaign||G.level!==1||G.phase!=='play'||G.seat?.locked){this.clear();return;}
  if(G.tutorialStep==='stop'&&activeTableIndex(G.seat)!==0)G.tutorialStep='play';
  const step=G.tutorialStep,copy={
   draw:['1 / 4','Возьми первую карту','«Взять карту» кладёт карту на первый открытый стол.','#btn-draw'],
   build:['2 / 4','Приблизься к цели','Цель — '+limitNow()+'. Возьми ещё карту. Выше цели — перебор и 0 урона со стола.','#btn-draw'],
   stop:['3 / 4','Останови первый стол','«Стоп на столе» переводит добор на следующий стол. Это не тратит ход.','#btn-stop-table'],
   play:['4 / 4','Ударь по противнику','Наполни другие столы. «Сыграть ход» превращает очки в урон и тратит один ход.','#btn-stand']
  }[step];if(!copy){this.finish();return;}
  if(step==='stop'&&evalPlay(G.seat.tables[0].cards,G.seat.tables[0].adj).bust){copy[1]='Первый стол перебрал';copy[2]='Выбери срез, затем нажми на стол. Или останови стол без урона.';copy[3]='.cons-btn';}
  this.clear();const panel=document.createElement('section');panel.id='tutorial-coach';panel.setAttribute('role','status');panel.setAttribute('aria-live','polite');
  panel.innerHTML='<div><small>Первые шаги · '+copy[0]+'</small><b>'+copy[1]+'</b><p>'+copy[2]+'</p></div><button type="button" aria-label="Пропустить обучение" title="Больше не показывать автоматически">×</button>';
  document.querySelector('#table-top').insertAdjacentElement('beforebegin',panel);panel.querySelector('button').onclick=()=>{this.finish('skipped');FastDraw.flush();saveRun();};document.querySelector(copy[3])?.classList.add('tutorial-target');
 }
};
