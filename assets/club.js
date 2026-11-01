/* Announced club tactics. Previews never mutate the battle or grant rewards. */
const Club={
 active(){return Campaign.club()&&G.enemy?.id?.startsWith('club_');},
 mechanic(){return this.active()?Campaign.level().mechanic:null;},
 plan(){
  if(!this.active())return false;
  const level=Campaign.level(),turn=G.battle.turn,mechanic=level.mechanic,lane=turn%tablesPerSeat();
  let intent={kind:'attack',amount:level.attack};
  if(mechanic==='previewBoss'){
   const open=turn%2===1;intent={kind:open?'attack':'guard',amount:open?level.attack:level.shield,clubOpen:open,clubLane:Math.floor(turn/2)%tablesPerSeat()};
  }else if(mechanic==='boss'){
   const stance=turn%3,marked=Math.floor(turn/3)%tablesPerSeat();
   intent=stance===0?{kind:'guard',amount:level.shield}:stance===1?{kind:'attack',amount:level.attack,clubOpen:true,clubLane:marked}:{kind:'heavy',amount:level.heavy,clubChallenge:'exact',clubLane:marked};
  }else if(mechanic==='pocket')Object.assign(intent,{clubChallenge:'pocket',clubLane:lane});
  else if(mechanic==='exact')Object.assign(intent,{kind:'heavy',clubChallenge:'exact',clubLane:lane});
  else if(mechanic==='long'&&turn%2===1)Object.assign(intent,{kind:'heavy',amount:level.heavy,clubChallenge:'long'});
  else if(mechanic==='red')intent.clubChallenge='red';
  if(mechanic==='deal'&&G.battle.clubDeal)intent.amount=Math.ceil(intent.amount*1.25);
  G.enemy.intent=intent;return true;
 },
 canEarn(result){
  if(!this.active()||G.battle.clubBonusEarned)return false;
  const mechanic=this.mechanic();
  if(mechanic==='debt')return result.exact>=1;
  return ['near','boss'].includes(mechanic)&&result.tables.filter(t=>!t.empty&&!t.bust&&t.sum>=limitNow()-2&&t.sum<=limitNow()).length>=2;
 },
 reward(result){
  if(!this.canEarn(result))return;
  G.battle.clubBonusEarned=true;G.seatsLeft++;
  log('Условие противника выполнено: +1 ход!','good');
 },
 counter(result,intent,amount){
  if(!this.active())return amount;
  if(intent.clubChallenge==='exact'&&result.tables[intent.clubLane]?.exact)return Math.floor(amount*.5);
  if(intent.clubChallenge==='long'&&result.tables.some((t,i)=>!t.empty&&!t.bust&&G.seat?.tables[i]?.cards.length>=4))return Math.floor(amount*.6);
  if(intent.clubChallenge==='red'&&result.tables.some(t=>!t.empty&&!t.bust&&t.paint?.kind==='heal'))return Math.floor(amount*.5);
  return amount;
 },
 afterResponse(result){
  const intent=G.enemy.intent;
  if(!this.active()||intent?.clubChallenge!=='pocket'||!result.tables[intent.clubLane]?.bust)return;
  const lost=Math.min(2,G.money);G.money-=lost;if(lost)log('Карманник: перебор на отмеченном столе, −$'+lost,'bad');
 },
 boostTables(tables){
  if(!this.active()||!G.enemy.intent?.clubOpen)return;
  const lane=tables[G.enemy.intent.clubLane];if(!lane||lane.empty||lane.bust)return;
  lane.score=Math.round(lane.score*1.6);lane.tags=(lane.tags||[]).concat('Уязвимость +60%');
 },
 trait(){
  if(!this.active())return '';
  const l=Campaign.level(),lead='Атака: '+l.attack+' HP. ';
  return ({
   host:lead+'Четыре хода на победу; красные столы помогут сохранить здоровье.',
   pocket:lead+'Заранее отмечает стол. Перебор на нём стоит $2, если враг пережил атаку. Карты и будущие ходы не отнимает.',
   near:lead+'Один раз за бой: два стола с суммой '+(limitNow()-2)+'–'+limitNow()+' за один розыгрыш дают +1 ход.',
   exact:lead+'Точный стол в отмеченном месте вдвое ослабляет объявленный удар. Отметка меняется до добора, карты после добора не меняются.',
   deal:lead+'Перед боем можно взять аванс $5: все атаки этого боя усилятся на 25%. Решение добровольное, только один раз.',
   long:lead+'Через ход — сильный удар '+l.heavy+' HP. Стол из четырёх или более карт без перебора ослабляет сильный удар на 40%.',
   red:lead+'Красный стол из трёх или более карт без перебора лечит и вдвое ослабляет ответный удар.',
   armor:lead+'Начальная броня 10%. Каждый точный стол снимает 2 процентных пункта брони до конца боя, начиная с текущей атаки.',
   debt:lead+'Один точный стол даёт +1 ход один раз за бой. Дополнительный розыгрыш также вызывает ответный удар.',
   boss:'Три стойки: щит +'+l.shield+' после твоего удара; атака '+l.attack+' и +60% урона отмеченного стола; сильный удар '+l.heavy+', который вдвое ослабляется точным отмеченным столом. Два стола у цели дают +1 ход один раз за бой.',
   previewBoss:'Чередует щит +260 и атаку 38 HP. В открытой стойке отмеченный стол наносит на 60% больше урона.'
  })[l.mechanic]||'';
 },
 introExtra(){
  if(this.mechanic()!=='deal')return '';
  return '<section class="passage-rule"><div><h3>Аванс Скупщика</h3><p>'+(G.battle.clubDeal?'Получено $5. Все атаки этого боя усилены на 25%.':'Можно войти без сделки или взять $5 сейчас ценой более сильных атак.')+'</p>'+(!G.battle.clubDeal?'<button type="button" class="ghost club-deal" data-club-deal>Взять $5 · атаки +25%</button>':'')+'</div></section>';
 },
 bindIntro(root){const button=root.querySelector('[data-club-deal]');if(button)button.onclick=()=>{if(G.phase!=='intro'||this.mechanic()!=='deal'||G.battle.clubDeal)return;G.battle.clubDeal=true;G.money+=5;render();showBlindIntro();};},
 renderIntent(element){
  if(!this.active()||G.enemy.hp<=0)return;
  const i=G.enemy.intent,mechanic=this.mechanic();
  if(i)element.textContent='Далее: '+(i.kind==='guard'?'щит +':'удар ')+fmt(i.amount);
  const info=document.createElement('span');info.className='club-tactic';
  if(['near','debt'].includes(mechanic))info.textContent=G.battle.clubBonusEarned?'Дополнительный ход получен':mechanic==='debt'?'+1 ход: один точный стол':'+1 ход: 2 стола '+(limitNow()-2)+'–'+limitNow();
  else if(i?.clubOpen)info.textContent='Стол '+(i.clubLane+1)+': урон +60%';
  else if(i?.clubChallenge==='exact')info.textContent='Стол '+(i.clubLane+1)+' точно → −50%';
  else if(i?.clubChallenge==='pocket')info.textContent='Стол '+(i.clubLane+1)+': перебор стоит $2';
  else if(mechanic==='long')info.textContent=i?.kind==='heavy'?'4+ карты на столе → удар −40%':'Следом сильный удар '+Campaign.level().heavy;
  else if(mechanic==='red')info.textContent='Красный стол 3+ → −50%';
  else if(mechanic==='armor')info.textContent='Точный стол: броня −2%';
  else if(mechanic==='deal')info.textContent=G.battle.clubDeal?'Аванс получен · атаки +25%':'Без аванса · обычные атаки';
  else if(['boss','previewBoss'].includes(mechanic))info.textContent='Затем откроется уязвимость';
  else info.textContent='Береги здоровье';
  element.append(info);element.title=this.trait();
 },
 showRules(){
  showOverlay('<div class="kicker">Подпольный клуб · десять боёв</div><h2>Обыграй хозяина</h2><div class="rules"><p>Четыре хода на бой. У Ловкача и хозяина два стола у цели дают дополнительный ход один раз за бой. У Сборщика долгов достаточно одного точного стола.</p><p>Приёмы показаны до добора. Точный отмеченный стол ослабляет удар Старшей шулерки и хозяина. Четыре карты без перебора ослабляют сильный удар Костяшника; красный стол из трёх карт — атаку Шулерки с печаткой. Точные столы снимают броню Вышибалы.</p><p>Карманник берёт $2 только за перебор на отмеченном столе, если выжил. Аванс Скупщика добровольный: $5 в обмен на усиление атак на 25% до конца боя.</p><p>Реликвии — после боёв 4 и 8. Лечение в магазине доступно после каждого боя, кроме финального; остановку отдыха можно встретить и раньше. Перед хозяином гарантирован выбор отдыха, мастерской или прямого пути. Старые трёхбоевые сохранения завершаются по прежним правилам.</p></div><button class="primary" id="ov-close">Понятно</button>');$('#ov-close').onclick=closeOverlay;
 }
};
