/* Club prototype: deterministic, announced tactics; previews never mutate battle state. */
const Club={
 active(){return Campaign.club()&&G.enemy?.id?.startsWith('club_');},
 plan(){
  if(!this.active())return false;
  const level=Campaign.level(),turn=G.battle.turn;
  if(G.enemy.id==='club_boss'){
   const open=turn%2===1;
   G.enemy.intent={kind:open?'attack':'guard',amount:open?level.attack:260,clubOpen:open,clubLane:Math.floor(turn/2)%tablesPerSeat()};
  }else G.enemy.intent={kind:'attack',amount:level.attack};
  return true;
 },
 canEarn(result){
  return this.active()&&G.enemy.id==='club_cheat'&&!G.battle.clubBonusEarned&&
   result.tables.filter(t=>!t.empty&&!t.bust&&t.sum>=limitNow()-2&&t.sum<=limitNow()).length>=2;
 },
 reward(result){
  if(!this.canEarn(result))return;
  G.battle.clubBonusEarned=true;G.seatsLeft++;
  log('Условие Ловкача выполнено: два стола у цели. +1 ход!','good');
 },
 boostTables(tables){
  if(!this.active()||!G.enemy.intent?.clubOpen)return;
  const lane=tables[G.enemy.intent.clubLane];
  if(!lane||lane.empty||lane.bust)return;
  lane.score=Math.round(lane.score*1.6);
  lane.tags=(lane.tags||[]).concat('Уязвимость +60%');
 },
 trait(){
  if(!this.active())return '';
  if(G.enemy.id==='club_host')return 'Атака: 23 HP каждый ход. Четыре хода на победу; красные столы помогут сохранить здоровье.';
  if(G.enemy.id==='club_cheat')return 'Атака: 30 HP. Один раз за бой: два стола с суммой '+(limitNow()-2)+'–'+limitNow()+' в одном розыгрыше дают +1 ход.';
  return 'Чередует защиту и открытый удар. Защита: щит +260 после твоего удара. Открытый удар: атака 38 HP, указанный стол наносит на 60% больше урона.';
 },
 renderIntent(element){
  if(!this.active()||G.enemy.hp<=0)return;
  const info=document.createElement('span');info.className='club-tactic';
  if(G.enemy.id==='club_cheat')info.textContent=G.battle.clubBonusEarned?'Дополнительный ход получен':'Два стола '+(limitNow()-2)+'–'+limitNow()+' → +1 ход (раз за бой)';
  else if(G.enemy.id==='club_boss')info.textContent=G.enemy.intent?.clubOpen?'Уязвим: стол '+(G.enemy.intent.clubLane+1)+' · урон +60%':'Защита → затем уязвимость';
  else info.textContent='Береги здоровье · 4 хода на бой';
  element.append(info);element.title=this.trait();
 }
};
