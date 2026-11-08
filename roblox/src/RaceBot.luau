-- Server-side training opponent for SharedDuel. It uses only public rules and
-- the same actions a player can send; it never inspects the hidden deck.
local SharedDuel = require(script.Parent.SharedDuel)
local RaceTarot = require(game.ReplicatedStorage.VochkoPrototype.RaceTarot)
local Loadout = require(game.ReplicatedStorage.VochkoPrototype.Loadout)

local RaceBot = {}

local function shuffled(list, random)
 local out = table.clone(list)
 for i = #out, 2, -1 do
  local j = random:NextInteger(1, i)
  out[i], out[j] = out[j], out[i]
 end
 return out
end

function RaceBot.Build(seed)
 local random = Random.new(seed or 1)
 local good = shuffled(RaceTarot.GoodIds, random)
 local bad = shuffled(RaceTarot.BadIds, random)
 local classes = Loadout.Classes
 local jokers = shuffled(Loadout.Jokers, random)
 local tarot = {}
 for i = 1, Loadout.RaceTarotGood do table.insert(tarot, good[i]) end
 for i = 1, Loadout.RaceTarotBad do table.insert(tarot, bad[i]) end
 return {
  id = "training-ai", class = classes[random:NextInteger(1, #classes)].id,
  jokers = { jokers[1].id, jokers[2].id },
  good = { good[1], good[2] }, bad = { bad[1], bad[2] }, tarot = tarot,
 }
end

local function candidateSum(base, card)
 if card.kind ~= "normal" then return base end
 local high = base + card.value
 if card.rank == "A" then
  local low = base + 1
  return math.min(high, low)
 end
 return high
end

local function wantsGrab(state, seat, zone, current, card)
 if card.kind == "tarot" then
  return RaceTarot.IsGood(card.tarot)
 end
 if current.regular == 0 then return true end
 local sum = candidateSum(current.sum, card)
 if sum > state.target then return false end
 if sum == state.target then return true end
 local distance = state.target - sum
 local oldDistance = state.target - current.sum
 if #zone.cards < 2 then return true end
 return distance < oldDistance and distance <= 8
end

-- Difficulty model. Skill scales every pause and adds reaction misses so a
-- human keeps the first-move advantage window. 0 easy, 1 normal, 2 strong.
local SKILLS = {
	{ delay = 2.1, miss = .40 },
	{ delay = 1.4, miss = .18 },
	{ delay = 1.0, miss = 0 },
}
local function skill(state)
	local index = math.clamp(math.floor((state.config.BotSkill or 1) + 0.5), 0, 2)
	return SKILLS[index + 1]
end
local function think(state, seconds)
	return seconds * skill(state).delay
end

local function tryStand(state, seat, now)
 if not SharedDuel.Stand(state, 2, now) then return false end
 state.botNextAt = now + think(state, 0.45)
 return true
end

function RaceBot.Step(state, now)
 if state.phase ~= "round" or state.pending then return false end
 if not state.open or state.nextRevealAt then return false end
 -- Read time at the start of every round: the bot waits before its first look.
 if state.roundBeganAt and now - state.roundBeganAt < 1.1 then
  state.botNextAt = math.max(state.botNextAt or 0, state.roundBeganAt + 1.1)
  return false
 end
 if now < (state.botNextAt or 0) then return false end
 local seat = state.seats[2]
 if not seat then return false end
 local zoneIndex = SharedDuel.ActiveZone(seat, state.target, state.config.Slots)
 if not zoneIndex then return false end
 local zone = seat.zones[zoneIndex]
 local current = SharedDuel.Zone(zone, state.target)
 local card = state.open
 local roll = state.random:NextNumber()
 local pause = skill(state)

 if card.kind == "tarot" and RaceTarot.IsBad(card.tarot) then
  if seat.discardsLeft > 0 and roll < 0.55 then
   if SharedDuel.Discard(state, 2, now) then
    state.botNextAt = now + think(state, 0.45) + state.random:NextNumber() * think(state, 0.25)
    return true
   end
  end
  if #zone.cards > 0 and current.sum >= state.target - 4 then return tryStand(state, seat, now) end
  state.botNextAt = now + think(state, 0.3) + state.random:NextNumber() * think(state, 0.35)
  return false
 end

 -- One-in-(miss chance) hesitation: the bot "does not notice" the card in time.
 if state.random:NextNumber() < pause.miss then
  state.botNextAt = now + (0.7 + state.random:NextNumber() * 0.7) * pause.delay
  return false
 end

 if wantsGrab(state, seat, zone, current, card) then
  if SharedDuel.Grab(state, 2, now) then
   state.botNextAt = now + think(state, 0.32) + state.random:NextNumber() * think(state, 0.35)
   return true
  end
  state.botNextAt = now + think(state, 0.2)
  return false
 end

 local sum = candidateSum(current.sum, card)
 local bust = sum > state.target
 if card.kind == "normal" and bust and seat.discardsLeft > 0 and roll < 0.5 then
  if SharedDuel.Discard(state, 2, now) then
   state.botNextAt = now + think(state, 0.45) + state.random:NextNumber() * think(state, 0.25)
   return true
  end
 end
 if #zone.cards >= 2 and (current.sum >= state.target - 4 or #zone.cards >= 3) then
  return tryStand(state, seat, now)
 end
 state.botNextAt = now + think(state, 0.28) + state.random:NextNumber() * think(state, 0.32)
 return false
end

return RaceBot
