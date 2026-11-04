-- Shared definitions; server owns unlocks and loadout validation.
local Tarot={}
Tarot.TestUnlockAll=true -- Temporary testing switch; normal unlock rules remain below.
Tarot.List={
 {id='rose',name='Роза',symbol='❀',desc='+20 HP · PvP: +8 HP',open='start'},
 {id='guardian',name='Страж',symbol='◇',desc='15 защиты · PvP: 6 защиты',open='start'},
 {id='sun',name='Солнце',symbol='☀',desc='Урон своего стола +40%',open='start'},
 {id='moon',name='Луна',symbol='☾',desc='Входящий урон −30%',open='win'},
 {id='tower',name='Башня',symbol='♜',desc='Сразу сбрасывает обычные карты своего стола',open='win'},
 {id='coin',name='Монета',symbol='$',desc='+10 монет за розыгрыш без перебора',open='win'},
 {id='echo',name='Эхо',symbol='∞',desc='Урон своего стола ×2',price=70},
 {id='seal',name='Печать',symbol='✧',desc='Отмена входящего удара · PvP: урон −50%',price=100},
 {id='scales',name='Весы',symbol='⚖',desc='Точная сумма: урон стола +50%',ach='exact3',hint='Три точных стола за один ход'},
 {id='candle',name='Свеча',symbol='♧',desc='Показывает следующие три карты на новом ходу',ach='scout',hint='Сыграть пять раундов'},
 {id='thread',name='Нить',symbol='⌁',desc='Возвращает использование рукава',ach='sleeve',hint='Спрятать три карты в рукав'},
 {id='hourglass',name='Песочные часы',symbol='⌛',desc='Сумма всегда равна цели, даже при переборе',ach='last',hint='Победить на последнем ходу'}
}
function Tarot.Caption(id,duel,target)
 local captions={rose=if duel then "+8 HP"else "+20 HP",guardian=if duel then "Защита 6"else "Защита 15",moon="Входящий урон −30%",sun="Урон стола +40%",tower="Стол очищен",echo="Урон стола ×2",scales="Точно: урон +50%",coin="+10 монет",candle="Разведка на новый ход",thread="+1 использование рукава",hourglass="Всегда "..(target or 21).." очко",seal=if duel then "Входящий урон −50%"else "Отмена атаки"}
 return captions[id]or ""
end
function Tarot.Def(id)for _,d in Tarot.List do if d.id==id then return d end end end
function Tarot.Unlocked(profile,d)return Tarot.TestUnlockAll or d.open=='start'or d.open=='win'and profile.wins>0 or profile.owned[d.id]==true or d.ach and profile.ach[d.ach]==true end
function Tarot.Has(zone,id)for _,c in zone.cards do if c.tarot==id then return true end end;return false end
function Tarot.Add(state,loadout)
 local seen,count={},0
 for _,id in loadout or {}do local d=Tarot.Def(id);if d and not seen[id]and count<4 then seen[id]=true;count+=1; table.insert(state.deck,{id='tarot-'..id,tarot=id,rank=d.name,suit='',value=0,red=false})end end
 state.deckTotal=#state.deck;state.tarotSpent={};state.tarotDrawn=0;state.sleeve={};state.sleeveUsed=0;state.money=0
end
function Tarot.Boost(zone,r)
 if r.bust then return end
 local factor=1
 if Tarot.Has(zone,'sun')then factor*=1.4 end
 if Tarot.Has(zone,'echo')then factor*=2 end
 if r.exact and Tarot.Has(zone,'scales')then factor*=1.5 end
 r.damage=math.floor(r.damage*factor+.5)
end
function Tarot.Effects(state,result,duel)
 local e={heal=0,shield=0,money=0,moon=false,seal=false,candle=false,thread=false}
 for i,z in state.zones do if not result.zones[i].bust then
  for _,c in z.cards do
   if c.tarot=='rose'then e.heal+=if duel then state.config.DuelRoseHeal else 20
   elseif c.tarot=='guardian'then e.shield+=if duel then state.config.DuelGuardianShield else 15
   elseif c.tarot=='coin'then e.money+=10
   elseif c.tarot then e[c.tarot]=true end
  end
 end end
 return e
end
function Tarot.Incoming(damage,e,duel)
 if e.seal then damage=if duel then math.floor(damage*.5)else 0 end
 if e.moon then damage=math.floor(damage*.7)end
 return math.max(0,damage-e.shield)
end
function Tarot.Commit(state,e)
 state.money=(state.money or 0)+e.money
 if e.candle then state.scoutPending=true end
 if e.thread then state.sleeveUsed=math.max(0,(state.sleeveUsed or 0)-1)end
end
return Tarot
