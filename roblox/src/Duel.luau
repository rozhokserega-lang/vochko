-- Server-only training duel. Bot decisions use revealed cards and unordered deck counts.
local Battle=require(script.Parent.Battle)
local Duel={}
local Tarot=require(game.ReplicatedStorage.VochkoPrototype.Tarot)
local Loadout=require(game.ReplicatedStorage.VochkoPrototype.Loadout)
local function rounded(n)return math.floor(n+.5)end
local function zoneDamage(r,target)
 if r.bust or r.damage==0 then return 0 end
 local d=math.abs(target-r.sum)
 local damage=if d==0 then 8 elseif d==1 then 6 elseif d==2 then 5 elseif d==3 then 4 elseif d<=5 then 3 elseif d<=9 then 2 else 1
 if r.critical then damage*=2 end
 if r.colorBonus and r.colorBonus>0 then damage=rounded(damage*(1+r.colorBonus/100))end
 return damage
end
function Duel.Evaluate(side)
 local result={damage=0,heal=0,busts=0,exact=0,cards=0,zones={},received=0}
 for i,z in side.zones do
  local r=Battle.Zone(z,side.config.Target,true)
  r.damage=zoneDamage(r,side.config.Target)
  r.heal=rounded(r.heal*side.config.DuelHealScale/100)
  result.damage+=r.damage;result.heal+=r.heal;result.cards+=#z.cards
  if r.bust then result.busts+=1 end;if r.exact then result.exact+=1 end
  result.zones[i]=r
 end
 Loadout.Apply(side,result)
 for i,z in side.zones do Tarot.Boost(z,result.zones[i],true)end
 result.damage=result.jokerBonus;for _,r in result.zones do result.damage+=r.damage end
 result.tarot=Tarot.Effects(side,result,true);result.heal+=result.tarot.heal
 result.tarot.shield=math.min(Loadout.ArmorMax,result.tarot.shield+result.armor);result.armor=result.tarot.shield
 return result
end
local function improveBust(side,acted)
 for index,z in side.zones do
  local old=Battle.Zone(z,side.config.Target,true)
  if old.bust then
   local best,bestValue
   for _,entry in {{'minus2',-2},{'minus4',-4}}do
    if side.supplies[entry[1]]>0 then
     local trial={cards=z.cards,delta=z.delta+entry[2],chipDelta=z.chipDelta,stood=z.stood}
     local r=Battle.Zone(trial,side.config.Target,true)
     local value=zoneDamage(r,side.config.Target)
     if not r.bust and (not bestValue or value>bestValue)then best=entry[1];bestValue=value end
    end
   end
   if best then Battle.Consume(side,best,index);if acted then acted()end end
  end
 end
end
function Duel.PlanBot(side,acted)
 if Loadout.Has(side,'xray')and side.scanCharges>0 and not side.scout and #side.deck>0 and side.scanRound~=side.round then
  side.scanCard=table.clone(side.deck[#side.deck]);side.scanCharges-=1;side.scanRound=side.round;if acted then acted()end
 end
 local actions=0
 while actions<80 do
  actions+=1;improveBust(side,acted)
  local index=Battle.Active(side);if not index then break end
  local z=side.zones[index];local r=Battle.Zone(z,side.config.Target,true)
  local draw=#z.cards==0 or r.sum<side.config.Target-7
  if not draw then
   -- Expected utility of one more card; never inspect the next card's identity.
   local total,count=0,0
   local pool=if #side.deck>0 then side.deck else side.discard
   for _,candidate in pool do
    local cards=table.clone(z.cards);table.insert(cards,candidate)
    local evaluated=Battle.Zone({cards=cards,delta=z.delta,chipDelta=z.chipDelta},side.config.Target,true)
    total+=zoneDamage(evaluated,side.config.Target)+evaluated.heal*side.config.DuelHealScale/100*.45
    count+=1
   end
   local current=zoneDamage(r,side.config.Target)+r.heal*side.config.DuelHealScale/100*.45
   draw=count>0 and total/count>current+.05
  end
  local known=side.scanCard or (side.scout and side.deck[#side.deck])
  if known and #z.cards>0 then
   local cards=table.clone(z.cards);table.insert(cards,known)
   local nextResult=Battle.Zone({cards=cards,delta=z.delta,chipDelta=z.chipDelta},side.config.Target,true)
   draw=not nextResult.bust and zoneDamage(nextResult,side.config.Target)>zoneDamage(r,side.config.Target)
  end
  if draw then if not Battle.Draw(side)then break end;side.scanCard=nil else Battle.Stop(side)end
  if acted then acted()end
 end
 improveBust(side,acted)
 -- Also use a cut for an exact hit when it improves a completed safe zone.
 for index,z in side.zones do
  local old=Battle.Zone(z,side.config.Target,true)
  for _,entry in {{'minus2',-2},{'minus4',-4}}do
   if side.supplies[entry[1]]>0 then
    local r=Battle.Zone({cards=z.cards,delta=z.delta+entry[2],chipDelta=z.chipDelta},side.config.Target,true)
    if r.exact and not old.exact and zoneDamage(r,side.config.Target)>zoneDamage(old,side.config.Target)then Battle.Consume(side,entry[1],index);if acted then acted()end;break end
   end
  end
 end
 return actions
end
function Duel.ChooseTarot(seed)
 local ids=table.clone(Loadout.TarotIds)
 Battle.Shuffle(ids,Random.new(seed));return {ids[1],ids[2],ids[3]}
end
function Duel.ChooseBuild(seed)
 local random=Random.new(seed);local ids={}for _,d in Loadout.Jokers do table.insert(ids,d.id)end
 Battle.Shuffle(ids,random);return {class=Loadout.Classes[random:NextInteger(1,#Loadout.Classes)].id,jokers={ids[1],ids[2]}}
end
function Duel.New(config,seed,talent,id,loadout,botLoadout,jokers,botBuild)
 local c=table.clone(config);c.Rounds=c.DuelRounds;c.PlayerHP=c.DuelHP;c.EnemyHP=c.DuelHP;c.EnemyAttack=0;c.ResolveSeconds=c.DuelResolveMs/1000
 c.PvP=true
 local state={baseTarget=c.Target,seed=seed,id=id,mode='duel',config=c,phase='intro',round=1,roundsLeft=c.Rounds,revision=0,journal={},rewardGranted=false}
 state.player=Battle.New(c,seed,talent,id..':player',loadout)
 botBuild=botBuild or Duel.ChooseBuild((seed+271)%1000000000)
 state.bot=Battle.New(c,(seed+107367)%1000000000,botBuild.class,id..':bot',botLoadout or loadout)
 state.player.jokers=table.clone(jokers or {});state.bot.jokers=table.clone(botBuild.jokers)
 for _,side in {state.player,state.bot}do side.scanCharges=if Loadout.Has(side,'xray')then 2 else 0 end
 return state
end
local function startBot(state)
 state.botReady=false
 state.botTurn=coroutine.create(function()Duel.PlanBot(state.bot,function()coroutine.yield()end)end)
end
function Duel.StepBot(state)
 if state.phase~="combat"or state.botReady then return false end
 local ok,err=coroutine.resume(state.botTurn);assert(ok,err)
 state.botReady=coroutine.status(state.botTurn)=="dead"
 state.revision+=1;return true
end
function Duel.Begin(state)
 if state.phase~='intro'then return false,'Дуэль уже началась'end
 state.phase='combat';startBot(state);state.revision+=1;return true
end
function Duel.Draw(state)if state.phase~='combat'then return false,'Дождись раскрытия карт'end;local ok,msg=Battle.Draw(state.player);if ok then state.player.scanCard=nil;state.revision+=1 end;return ok,msg end
function Duel.Stop(state)if state.phase~='combat'then return false,'Ход уже подтверждён'end;local ok,msg=Battle.Stop(state.player);if ok then state.revision+=1 end;return ok,msg end
function Duel.Consume(state,item,index)
 if state.phase~='combat'then return false,'Ход уже подтверждён'end
 if item=='scan'then
  local side=state.player
  if not Loadout.Has(side,'xray')or side.scanCharges<=0 or side.scanCard or side.scout or not Battle.Active(side)or #side.deck==0 then return false,'Сканер сейчас недоступен'end
  side.scanCard=table.clone(side.deck[#side.deck]);side.scanCharges-=1;state.revision+=1;return true
 end
 if item=='hide'or item=='release'then return false,'Рукав отключён в PvP'end
 local ok,msg=Battle.Consume(state.player,item,index);if ok then state.revision+=1 end;return ok,msg
end
local function hits(side,result,loss)
 local out,total={},0
 for i,z in side.zones do
  if result.zones[i].damage>0 then
   total+=result.zones[i].damage
   local ordinary={}for _,card in z.cards do if not card.tarot then table.insert(ordinary,card)end end
   for _,card in ordinary do table.insert(out,{card=table.clone(card),zone=i,weight=result.zones[i].damage/#ordinary})end
  end
 end
 local cumulative,assigned=0,0
 for _,hit in out do cumulative+=hit.weight;local share=rounded(loss*cumulative/total);hit.damage=share-assigned;assigned=share;hit.weight=nil end
 return out
end
function Duel.Play(state)
 if state.phase~='combat'then return false,'Ход уже подтверждён'end
 if not state.botReady then return false,'Соперник ещё набирает карты'end
 local a,b=Duel.Evaluate(state.player),Duel.Evaluate(state.bot)
 if a.cards==0 then return false,'Сначала возьми карту'end
 local p,e=state.player,state.bot
 local ownBefore,enemyHealBefore=p.hp,e.hp
 local playerHealed=math.min(state.config.DuelHP,p.hp+a.heal)
 local enemyHealed=math.min(state.config.DuelHP,e.hp+b.heal)
 local function defend(raw,effects)
  local reductions=table.clone(effects);reductions.shield=0
  local reduced=Tarot.Incoming(raw,reductions,true)
  local absorbed=math.min(reduced,effects.shield)
  return math.max(0,reduced-absorbed),absorbed,math.max(0,effects.shield-absorbed)
 end
 local incoming,ownBlocked,ownArmorAfter=defend(b.damage,a.tarot)
 local outgoing,enemyBlocked,enemyArmorAfter=defend(a.damage,b.tarot)
 local ownArmorBefore,enemyArmorBefore=a.armor,b.armor
 a.damage=outgoing;b.damage=incoming
 Tarot.Commit(p,a.tarot);Tarot.Commit(e,b.tarot)
 p.hp=math.max(0,playerHealed-b.damage);e.hp=math.max(0,enemyHealed-a.damage)
 state.roundsLeft-=1
 local function returns(side,result)
  local out={};for i,z in side.zones do if result.zones[i].bust then for _,card in z.cards do table.insert(out,{card=table.clone(card),zone=i})end end end;return out
 end
 state.receipt={round=state.round,damage=a.damage,heal=a.heal,received=b.damage,ownBefore=ownBefore,ownHealed=playerHealed,enemyHealBefore=enemyHealBefore,returns=returns(p,a),ownArmorBefore=ownArmorBefore,ownArmorAfter=ownArmorAfter,ownBlocked=ownBlocked,enemyArmorBefore=enemyArmorBefore,enemyArmorAfter=enemyArmorAfter,enemyBlocked=enemyBlocked,enemyBefore=enemyHealed,enemyAfter=e.hp,hits=hits(p,a,enemyHealed-e.hp),
  incoming={enemyBefore=playerHealed,enemyAfter=p.hp,hits=hits(e,b,playerHealed-p.hp),returns=returns(e,b)}}
 table.insert(state.journal,string.format('Раунд %d: нанесено %d · получено %d · броня поглотила %d:%d · HP %d:%d',state.round,a.damage,b.damage,ownBlocked,enemyBlocked,p.hp,e.hp))
 if p.hp==0 or e.hp==0 or state.roundsLeft==0 then
  state.phase=if p.hp==e.hp then 'draw'elseif p.hp>e.hp then 'won'else 'lost'
 else state.phase='resolving'end
 state.revision+=1;return true
end
function Duel.Next(state)
 if state.phase~='resolving'then return end
 for _,side in {state.player,state.bot}do side.scanCard=nil;side.phase='resolving';Battle.Next(side)end
 state.round+=1;state.config.Target=state.baseTarget+state.round-1
 state.player.config.Target=state.config.Target;state.bot.config.Target=state.config.Target
 state.phase='combat';state.revision+=1;startBot(state)
end
function Duel.View(state)
 local view=Battle.View(state.player)
 view.id=state.id;view.mode='duel';view.phase=state.phase;view.revision=state.revision;view.round=state.round;view.roundsLeft=state.roundsLeft;view.roundsTotal=state.config.Rounds
 view.hp=state.player.hp;view.enemyHp=state.bot.hp;view.enemyMaxHp=state.config.DuelHP;view.enemyName='Тренировочный шулер';view.enemyAttack=0
 view.forecast=Duel.Evaluate(state.player);view.receipt=state.receipt;view.journal=table.clone(state.journal)
 view.tarotLimit=3;view.class=state.player.talent;view.jokers=table.clone(state.player.jokers or {});view.scanCharges=state.player.scanCharges
 if state.player.scanCard and #view.peek==0 then view.peek={table.clone(state.player.scanCard)}end
 local revealed=true
 local evaluated=Duel.Evaluate(state.bot)
 local zones={}
 for i,z in state.bot.zones do
  local cards={}
  for j,card in z.cards do table.insert(cards,table.clone(card))end
  zones[i]={cards=cards,stood=z.stood,result=evaluated.zones[i]}
 end
 view.armor=if state.receipt and state.phase~='combat'then state.receipt.ownArmorAfter else view.forecast.armor
 view.enemyArmor=if state.receipt and state.phase~='combat'then state.receipt.enemyArmorAfter else evaluated.armor
 view.armorMax=Loadout.ArmorMax
 view.duel={enemyClass=state.bot.talent,enemyJokers=table.clone(state.bot.jokers),enemyScanCharges=state.bot.scanCharges,enemyZones=zones,enemyReady=state.botReady==true,enemyDeckTotal=state.bot.deckTotal,enemyDeckCount=#state.bot.deck,enemySupplies=table.clone(state.bot.supplies),revealed=revealed,opponentKind='bot'}
 return view
end
return Duel
