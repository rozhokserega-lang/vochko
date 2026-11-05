-- Pure server-side state transitions; animation never changes combat results.
local Battle = {}
local Tarot=require(game.ReplicatedStorage.VochkoPrototype.Tarot)
local ranks = { "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A" }
local suits = { "♠", "♥", "♦", "♣" }
local function rounded(n) return math.floor(n + 0.5) end
local function multiplier(distance)
 if distance == 0 then return 8 elseif distance == 1 then return 5 elseif distance == 2 then return 3
 elseif distance == 3 then return 2 elseif distance <= 5 then return 1.25 else return 0.6 end
end
local function emptyZones(count)
 local zones = {} for i = 1, count do zones[i] = { cards = {}, delta = 0, chipDelta = 0, stood = false } end
 return zones
end
function Battle.Deck()
 local deck = {}
 for si, suit in suits do for ri, rank in ranks do
  table.insert(deck, { id = si * 100 + ri, rank = rank, suit = suit, suitIndex = si,
   rankIndex = ri, value = if ri <= 9 then ri + 1 elseif ri == 13 then 11 else 10,
   red = si == 2 or si == 3 })
 end end
 return deck
end
function Battle.Shuffle(deck, random)
 for i = #deck, 2, -1 do local j = random:NextInteger(1, i); deck[i], deck[j] = deck[j], deck[i] end
end
function Battle.Zone(zone, target,duel)
 if #zone.cards == 0 then return { sum = 0, damage = 0, exact = false, bust = false, heal = 0 } end
 local raw, chips, aces, kings = zone.delta, zone.chipDelta * 10, 0, 0
 local allRed, allBlack = true, true
 local regular=0;local clock=Tarot.Has(zone,"hourglass")
 for _, card in zone.cards do
  if not card.tarot then
  regular+=1
  raw += card.value; chips += card.value * 10
  if card.rank == "A" then aces += 1 end
  if card.rank == "K" then kings += 1 end
  allRed = allRed and card.red; allBlack = allBlack and not card.red
  end
 end
 chips = math.max(0, chips)
 local best
 for lowAces = 0, aces do
  local candidate=raw-10*lowAces
  local sum = if clock and (not duel or math.abs(candidate-target)<=2)then target else candidate
  local bust = sum > target and kings < 3
  local score = if bust then 0 else rounded(chips * multiplier(math.abs(target - sum)))
  if regular == 2 and sum == target then score *= 2 end
  if aces >= 3 then score *= 2 end
  if not best or score > best.damage or (score == best.damage and ((best.bust and not bust)
   or (best.bust == bust and (if bust then sum < best.sum else sum > best.sum)))) then
   best = { sum = sum, damage = score, exact = sum == target, bust = bust, heal = 0,
    colorBonus = 0, royal = kings >= 3, critical = aces >= 3 }
  end
 end
 if not best.bust and regular >= 3 then
  if allRed then best.heal = if regular >= 4 then 15 else 10 end
  if allBlack then best.colorBonus = if regular >= 4 then 15 else 10;
   best.damage = rounded(best.damage * (1 + best.colorBonus / 100)) end
 end
 return best
end
function Battle.Active(state)
 for i, zone in state.zones do
  local r = Battle.Zone(zone, state.config.Target,state.config.PvP)
  if not zone.stood and #zone.cards < state.config.Slots and not r.bust and (not r.exact or Tarot.Has(zone,"hourglass"))then return i end
 end
 return nil
end
function Battle.New(config, seed, talent, id,loadout)
 local random = Random.new(seed)
 local deck = Battle.Deck()
 local extra={deck=deck,pvp=config.PvP};Tarot.Add(extra,loadout);Battle.Shuffle(deck,random)
 return {deckTotal=extra.deckTotal,tarotSpent={},tarotDrawn=0,sleeve={},sleeveUsed=0,money=0, id = id, config = table.clone(config), random = random, deck = deck, discard = {},
  zones = emptyZones(config.Zones), hp = config.PlayerHP, enemyHp = config.EnemyHP,
  roundsLeft = config.Rounds, round = 1, phase = "combat", talent = talent,
  supplies = { minus2 = 1, minus4 = 1 }, lastRequest = 0, revision = 0, journal = {}, rewardGranted = false }
end
function Battle.Draw(state)
 if state.phase ~= "combat" then return false, "Подожди окончания удара" end
 local i = Battle.Active(state); if not i then return false, "Зоны закрыты. Разыграй ход или примени срез." end
 if #state.deck == 0 then
  state.deck, state.discard = state.discard, {}; Battle.Shuffle(state.deck, state.random)
 end
 if #state.deck == 0 then return false, "Колода пуста" end
 local c=table.remove(state.deck);if c.tarot then state.tarotDrawn+=1 end;local z=state.zones[i];table.insert(z.cards,c)
 if c.tarot=="tower"then
  local kept={}for _,card in z.cards do if card.tarot then table.insert(kept,card)else table.insert(state.discard,card)end end
  z.cards=kept;z.delta=0;z.chipDelta=0;z.stood=false
 end
 state.revision += 1
 return true
end
function Battle.Stop(state)
 if state.phase ~= "combat" then return false, "Ход уже разыгрывается" end
 local i = Battle.Active(state)
 if not i or #state.zones[i].cards == 0 then return false, "Сначала возьми карту" end
 state.zones[i].stood = true; state.revision += 1; return true
end
function Battle.Consume(state, item, index)
 if state.phase ~= "combat" then return false, "Ход уже разыгрывается" end
 if item=="hide"or item=="release"then
  local i=Battle.Active(state);local z=i and state.zones[i]
  if not z then return false,"Нет открытого стола"end
  if item=="hide"then
   local c=z.cards[#z.cards]
   if not c or c.tarot or state.sleeveUsed>=1 or #state.sleeve>0 then return false,"Рукав недоступен"end
   table.insert(state.sleeve,table.remove(z.cards));state.sleeveUsed+=1;state.sleeveCount=(state.sleeveCount or 0)+1
  else
   if #state.sleeve==0 then return false,"Рукав пуст"end
   table.insert(z.cards,table.remove(state.sleeve))
  end
  state.revision+=1;return true
 end
 if (item ~= "minus2" and item ~= "minus4") or (state.supplies[item] or 0) <= 0 then return false, "Предмет закончился" end
 if type(index) ~= "number" or index % 1 ~= 0 then return false, "Выбери зону" end
 local zone = state.zones[index]
 if not zone or #zone.cards == 0 then return false, "Выбери зону с картами" end
 local delta = if item == "minus2" then -2 else -4
 zone.delta += delta; state.supplies[item] -= 1; state.revision += 1
 return true
end
function Battle.Forecast(state)
 local result = { damage = 0, heal = 0, busts = 0, exact = 0, cards = 0, zones = {} }
 for i, zone in state.zones do
  local r = Battle.Zone(zone, state.config.Target)
  if state.talent == "sharp" and r.exact then r.damage = rounded(r.damage * 1.15) end
  if state.talent == "healer" then r.heal = rounded(r.heal * 1.5) end
  Tarot.Boost(zone,r)
  result.zones[i] = r; result.damage += r.damage; result.heal += r.heal
  result.cards += #zone.cards
  if r.bust then result.busts += 1 end; if r.exact then result.exact += 1 end
 end
 if state.talent == "daring" and result.busts == 1 then result.damage = rounded(result.damage * 1.3) end
 result.tarot=Tarot.Effects(state,result,false);result.heal+=result.tarot.heal
 result.received = if result.damage >= state.enemyHp then 0 else state.config.EnemyAttack + result.busts * state.config.BustPenalty
 result.received=Tarot.Incoming(result.received,result.tarot,false)
 return result
end
function Battle.Play(state)
 if state.phase ~= "combat" then return false, "Ход уже разыгран" end
 local r = Battle.Forecast(state); if r.cards == 0 then return false, "Сначала возьми карту" end
 Tarot.Commit(state,r.tarot)
 local enemyBefore=state.enemyHp
 local ownBefore=state.hp
 local ownHealed=math.min(state.config.PlayerHP,state.hp+r.heal)
 state.roundsLeft -= 1; state.enemyHp = math.max(0, state.enemyHp - r.damage)
 state.hp = math.min(state.config.PlayerHP, state.hp + r.heal); state.hp = math.max(0, state.hp - r.received)
 -- Attribute the actual HP loss to revealed cards. Rounded shares add up exactly,
 -- including global talent multipliers and lethal overkill.
 local hits,weightTotal={},0
 for i,zone in state.zones do
  local weight=r.zones[i].damage
  if weight>0 then
   local ordinary={}for _,card in zone.cards do if not card.tarot then table.insert(ordinary,card)end end
   for _,card in ordinary do table.insert(hits,{card=table.clone(card),zone=i,weight=weight/#ordinary})end
   weightTotal+=weight
  end
 end
 local cumulative,assigned=0,0
 for _,hit in hits do
  cumulative+=hit.weight
  local total=rounded((enemyBefore-state.enemyHp)*cumulative/weightTotal)
  hit.damage=total-assigned;hit.weight=nil;assigned=total
 end
 local returns={}
 for i,zone in state.zones do if r.zones[i].bust then for _,card in zone.cards do table.insert(returns,{card=table.clone(card),zone=i})end end end
 state.receipt = { damage = r.damage, heal = r.heal, received = r.received, round = state.round,returns=returns,ownBefore=ownBefore,ownHealed=ownHealed,
  enemyBefore=enemyBefore,enemyAfter=state.enemyHp,hits=hits }
 table.insert(state.journal, string.format("Ход %d: урон %d · лечение %d · получено %d", state.round, r.damage, r.heal, r.received))
 if #state.journal > 20 then table.remove(state.journal, 1) end
 state.phase = if state.enemyHp <= 0 then "won" elseif state.hp <= 0 or state.roundsLeft <= 0 then "lost" else "resolving"
 state.revision += 1; return true
end
function Battle.Next(state)
 if state.phase ~= "resolving" then return end
 for _, zone in state.zones do for _, card in zone.cards do table.insert(if card.tarot then state.tarotSpent else state.discard,card)end end
 state.scout=state.scoutPending;state.scoutPending=false
 state.zones = emptyZones(state.config.Zones); state.round += 1; state.phase = "combat"; state.revision += 1
end
function Battle.View(state)
 local peek={}if state.scout then for i=#state.deck,math.max(1,#state.deck-2),-1 do table.insert(peek,table.clone(state.deck[i]))end end
 local zones = {} for i, zone in state.zones do zones[i] = { cards = table.clone(zone.cards), stood = zone.stood } end
 return { id = state.id, phase = state.phase, revision = state.revision, target = state.config.Target,
  tarotUsed=state.tarotDrawn,tarotLimit=4,deckTotal=state.deckTotal,peek=peek,sleeveCount=#state.sleeve,sleeveUsed=state.sleeveUsed,
  slots = state.config.Slots, roundsLeft = state.roundsLeft, roundsTotal = state.config.Rounds, round = state.round,
  hp = state.hp, maxHp = state.config.PlayerHP, enemyHp = state.enemyHp, enemyMaxHp = state.config.EnemyHP,
  enemyAttack = state.config.EnemyAttack, enemyName = "Крысолов", talent = state.talent,
  zones = zones, active = Battle.Active(state), deckCount = #state.deck, discardCount = #state.discard,
  supplies = table.clone(state.supplies), forecast = Battle.Forecast(state), receipt = state.receipt,
  journal = table.clone(state.journal) }
end
return Battle
