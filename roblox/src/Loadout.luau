-- Shared inventory definitions; the server validates and snapshots builds.
local L={ArmorMax=12,RaceTarotGood=2,RaceTarotBad=2}
local RaceTarot=require(script.Parent:WaitForChild("RaceTarot"))
L.Classes={
 {id="sharp",name="Картёжник",symbol="♠",desc="Точный стол: +1 урон."},
 {id="healer",name="Лекарь",symbol="♥",desc="Красное сочетание: +1 HP. До +3 за раунд."},
 {id="guardian",name="Хранитель",symbol="◇",desc="Без переборов: 2 брони на текущий обмен ударами."},
}
L.Jokers={
 {id="crimson",name="Красная рука",symbol="♥",desc="Красное сочетание: ещё +1 HP. До +3 за раунд."},
 {id="blot",name="Чёрная краска",symbol="♠",desc="Чёрное сочетание: +1 урон этому столу."},
 {id="triple",name="Тройной удар",symbol="Ⅲ",desc="Три обычные карты без перебора: +1 урон столу."},
 {id="tandem",name="Тандем",symbol="Ⅱ",desc="Две одинаковые безопасные суммы: +2 общего урона раз за раунд."},
 {id="ladder",name="Лесенка",symbol="↗",desc="Три последовательные безопасные суммы: +3 общего урона."},
 {id="xray",name="Сканер",symbol="◉",desc="Посмотреть следующую карту. Два использования на весь матч."},
}
L.TarotIds={"rose","guardian","sun","moon","tower","coin","echo","seal","scales","candle","hourglass"}
function L.Class(id)for _,d in L.Classes do if d.id==id then return d end end end
function L.Joker(id)for _,d in L.Jokers do if d.id==id then return d end end end
function L.Has(side,id)return table.find(side.jokers or {},id)~=nil end
local function validList(list,count,find)
 if type(list)~="table"or #list~=count then return false end
 local seen={};local n=0
 for k,id in list do
  if type(k)~="number"or k%1~=0 or k<1 or k>count or type(id)~="string"or seen[id]or not find(id)then return false end
  seen[id]=true;n+=1
 end
 return n==count
end
function L.Validate(class,jokers,tarot)
 if not L.Class(class)then return false,"Выбери класс"end
 if not validList(jokers,2,L.Joker)then return false,"Выбери двух разных джокеров"end
 if not validList(tarot,3,function(id)return table.find(L.TarotIds,id)end)then return false,"Выбери три разных таро для PvP"end
 return true
end
function L.ValidateRace(class,jokers,tarot)
 if not L.Class(class)then return false,"Выбери класс"end
 if not validList(jokers,2,L.Joker)then return false,"Выбери двух разных джокеров"end
 return RaceTarot.ValidateLoadout(tarot,L.RaceTarotGood,L.RaceTarotBad)
end
function L.DefaultRaceTarot(seed)
 return RaceTarot.NormalizeBuild(nil,Random.new(seed or 1),L.RaceTarotGood,L.RaceTarotBad).tarot
end
function L.RaceTarotDef(id)return RaceTarot.Def(id)end
function L.Apply(side,result)
 local red,black={},{};local sums={};local validSums={}
 for i,z in side.zones do
  local r=result.zones[i];local ordinary=0
  for _,c in z.cards do if not c.tarot then ordinary+=1 end end
  if not r.bust and ordinary>0 then
   if side.talent=="sharp"and r.exact then r.damage+=1 end
   if r.heal>0 then table.insert(red,i)end
   if (r.colorBonus or 0)>0 then table.insert(black,i)end
   if L.Has(side,"triple")and ordinary==3 then r.damage+=1 end
   sums[r.sum]=(sums[r.sum]or 0)+1;table.insert(validSums,r.sum)
  end
 end
 if L.Has(side,"blot")then for _,i in black do result.zones[i].damage+=1 end end
 if side.talent=="healer"then result.heal+=math.min(3,#red)end
 if L.Has(side,"crimson")then result.heal+=math.min(3,#red)end
 result.armor=if side.talent=="guardian"and result.busts==0 and result.cards>0 then 2 else 0
 result.jokerBonus=0
 if L.Has(side,"tandem")then for _,count in sums do if count>=2 then result.jokerBonus+=2;break end end end
 if L.Has(side,"ladder")and #validSums==3 then table.sort(validSums);if validSums[2]==validSums[1]+1 and validSums[3]==validSums[2]+1 then result.jokerBonus+=3 end end
 result.damage=result.jokerBonus;for _,r in result.zones do result.damage+=r.damage end
end
return L
