-- Server-only real-time shared-deck duel.
-- One 60-card deck, one open card, one shared discard. Every seat owns three zones.
-- All public state is exposed through View; deck order and tarot identity are never sent.
local SharedDuel = {}

local RaceTarot = require(game.ReplicatedStorage.VochkoPrototype.RaceTarot)
local Loadout = require(game.ReplicatedStorage.VochkoPrototype.Loadout)
local ARMOR_MAX = Loadout.ArmorMax or 12

local RANKS = { "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A" }
local SUITS = { "♠", "♥", "♦", "♣" }

local function rounded(n) return math.floor(n + 0.5) end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
local function copy(value)
 if value == nil then return nil end
 return table.clone(value)
end
local function resultFor(winner, seat)
 if winner == seat then return "won" elseif winner then return "lost" else return "draw" end
end

local function shuffle(list, random)
 for i = #list, 2, -1 do
  local j = random:NextInteger(1, i)
  list[i], list[j] = list[j], list[i]
 end
end

local function normalCards()
 local deck = {}
 for si, suit in SUITS do
  for ri, rank in RANKS do
   local value = if ri <= 9 then ri + 1 elseif ri == 13 then 11 else 10
   table.insert(deck, {
    id = "n" .. si .. "_" .. ri, kind = "normal", rank = rank, suit = suit,
    suitIndex = si, rankIndex = ri, value = value, red = si == 2 or si == 3,
   })
  end
 end
 return deck
end

local function emptyZone()
 return { cards = {}, stood = false, bonusSum = 0, dmgMult = 1, zero = false, pull = 0, scales = false }
end

local function emptyZones(count)
 local zones = {}
 for i = 1, count do zones[i] = emptyZone() end
 return zones
end

local function newStats()
 return { cards = 0, tarot = 0, good = 0, bad = 0, discards = 0, timeouts = 0, armor = 0,
  busts = 0, zones2 = 0, scored = 0 }
end

local function targetFor(config, round)
 return math.min(config.TargetCap, config.Target + (round - 1) * config.TargetStep)
end

-- ------------------------------------------------------------------ deck

local function makeBuild(build, random, config)
 local goodCount = math.max(0, config.TarotGood or 2)
 local badCount = math.max(0, config.TarotBad or 2)
 local normalized = RaceTarot.NormalizeBuild(build, random, goodCount, badCount)
 normalized.class = if type(build) == "table" and Loadout.Class(build.class) then build.class else "sharp"
 normalized.jokers = if type(build) == "table" and type(build.jokers) == "table" then copy(build.jokers) else {}
 normalized.id = if type(build) == "table" and type(build.id) == "string" then build.id else normalized.class
 return normalized
end

local function autoBuilds(random, config)
 local good = copy(RaceTarot.GoodIds)
 local bad = copy(RaceTarot.BadIds)
 shuffle(good, random)
 shuffle(bad, random)
 local goodCount = math.max(0, config.TarotGood or 2)
 local badCount = math.max(0, config.TarotBad or 2)
 local builds = {}
 for seat = 1, 2 do
  local b = { good = {}, bad = {}, class = "sharp", jokers = {} }
  for k = 1, goodCount do
   local index = ((seat - 1) * goodCount + k - 1) % #good + 1
   table.insert(b.good, good[index])
  end
  for k = 1, badCount do
   local index = ((seat - 1) * badCount + k - 1) % #bad + 1
   table.insert(b.bad, bad[index])
  end
  b.tarot = {}
  for _, id in b.good do table.insert(b.tarot, id) end
  for _, id in b.bad do table.insert(b.tarot, id) end
  builds[seat] = b
 end
 return builds
end

local function buildDeck(config, random, builds)
 local deck = normalCards()
 local serial = 0
 for seat = 1, 2 do
  local build = builds[seat]
  for _, id in build.good or {} do
   serial += 1
   table.insert(deck, { id = "t" .. serial .. "_" .. id, kind = "tarot", tarot = id,
    rank = RaceTarot.Name(id), suit = "", value = 0, red = false, good = true })
  end
  for _, id in build.bad or {} do
   serial += 1
   table.insert(deck, { id = "t" .. serial .. "_" .. id, kind = "tarot", tarot = id,
    rank = RaceTarot.Name(id), suit = "", value = 0, red = false, good = false })
  end
 end
 shuffle(deck, random)
 return deck
end

-- --------------------------------------------------------------- evaluate

local function evalZone(zone, target)
 local normals = 0
 local raw = zone.bonusSum or 0
 local aces, kings = 0, 0
 local allRed, allBlack = true, true
 for _, card in zone.cards do
  if card.kind ~= "tarot" then
   normals += 1
   raw += card.value
   if card.rank == "A" then aces += 1 end
   if card.rank == "K" then kings += 1 end
   if not card.red then allRed = false end
   if card.red then allBlack = false end
  end
 end
 if normals == 0 then
  return { sum = 0, damage = 0, exact = false, bust = false, heal = 0, colorBonus = 0,
   critical = false, regular = 0, red = false, black = false }
 end
 local best
 for lowAces = 0, aces do
  local sum = raw - 10 * lowAces
  if (zone.pull or 0) > 0 and math.abs(sum - target) <= zone.pull then sum = target end
  local bust = sum > target and kings < 3
  local distance = math.abs(target - sum)
  local candidate = { sum = sum, bust = bust, distance = distance }
  if not best then
   best = candidate
  else
   local better = (not bust and best.bust)
    or (bust == best.bust and ((not bust and distance < best.distance) or (bust and sum < best.sum)))
   if better then best = candidate end
  end
 end
 local regular = normals
 local exact = not best.bust and best.sum == target
 local critical = aces >= 3
 local colorBonus = if not best.bust and regular >= 3 and allBlack then (if regular >= 4 then 15 else 10) else 0
 local heal = if not best.bust and regular >= 3 and allRed then (if regular >= 4 then 15 else 10) else 0
 return { sum = best.sum, damage = 0, exact = exact, bust = best.bust, heal = heal,
  colorBonus = colorBonus, critical = critical, regular = regular,
  red = allRed and regular > 0, black = allBlack and regular > 0 }
end

local function duelDamage(zone, target)
 if zone.zero then return 0 end
 local result = evalZone(zone, target)
 if result.regular == 0 or result.bust then return 0 end
 local distance = math.abs(target - result.sum)
 local damage = if distance == 0 then 8 elseif distance == 1 then 6 elseif distance == 2 then 5
  elseif distance == 3 then 4 elseif distance <= 5 then 3 elseif distance <= 9 then 2 else 1
 if result.critical then damage *= 2 end
 if result.colorBonus > 0 then damage = rounded(damage * (1 + result.colorBonus / 100)) end
 return damage
end

local function evaluatePlayer(seat, target, config)
 local result = { damage = 0, heal = 0, armor = 0, busts = 0, redZones = 0, blackZones = 0,
  cards = 0, sums = {}, zones = {} }
 local sums, valid = {}, {}
 for i, zone in seat.zones do
  local r = evalZone(zone, target)
  local damage = duelDamage(zone, target)
  if not r.bust and r.regular > 0 then
   if seat.class == "sharp" and r.exact then damage += 1 end
   if table.find(seat.jokers or {}, "triple") and r.regular == 3 then damage += 1 end
   if table.find(seat.jokers or {}, "blot") and r.black then damage += 1 end
   if zone.scales and r.exact then damage = rounded(damage * 1.5) end
   damage = rounded(damage * (zone.dmgMult or 1))
  else
   damage = 0
  end
  if r.bust then result.busts += 1 end
  if r.red then result.redZones += 1 end
  if r.black then result.blackZones += 1 end
  result.damage += math.max(0, damage)
  result.cards += #zone.cards
  result.heal += rounded(r.heal * (config.HealScale or 0.2))
  if not r.bust and r.regular > 0 then
   sums[r.sum] = (sums[r.sum] or 0) + 1
   table.insert(valid, r.sum)
  end
  r.damage = math.max(0, damage)
  result.zones[i] = r
 end
 if seat.class == "healer" then result.heal += math.min(3, result.redZones) end
 if table.find(seat.jokers or {}, "crimson") then result.heal += math.min(3, result.redZones) end
 if seat.class == "guardian" and result.busts == 0 and result.cards > 0 then result.armor += 2 end
 local bonus = 0
 if table.find(seat.jokers or {}, "tandem") then
  for _, count in sums do if count >= 2 then bonus += 2; break end end
 end
 if table.find(seat.jokers or {}, "ladder") and #valid >= 3 then
  local unique = {}
  for _, value in valid do unique[value] = true end
  local ordered = {}
  for value in unique do table.insert(ordered, value) end
  table.sort(ordered)
  for i = 1, #ordered - 2 do
   if ordered[i + 1] == ordered[i] + 1 and ordered[i + 2] == ordered[i + 1] + 1 then
    bonus += 3
    break
   end
  end
 end
 result.damage += bonus
 result.bonus = bonus
 return result
end

local function activeZone(seat, target, slots)
 for i, zone in seat.zones do
  if not zone.stood and not zone.zero and #zone.cards < slots then
   local r = evalZone(zone, target)
   if not r.bust and not r.exact then return i end
  end
 end
 return nil
end

local function zoneAccepts(seat, index, target, slots)
 local zone = seat.zones[index]
 if not zone or zone.stood or zone.zero or #zone.cards >= slots then return false end
 local r = evalZone(zone, target)
 return not r.bust and not r.exact
end

-- ------------------------------------------------------------------ tarot

local function publicCard(card)
 if not card then return nil end
 if card.kind == "tarot" then
  return { kind = "tarot", hidden = true, back = true }
 end
 return { kind = "normal", hidden = false, rank = card.rank, suit = card.suit,
  rankIndex = card.rankIndex, suitIndex = card.suitIndex, value = card.value, red = card.red }
end

local function peekTop(state, count)
 local out = {}
 for i = #state.deck, math.max(1, #state.deck - count + 1), -1 do
  local card = state.deck[i]
  if not card then continue end
  if card.kind == "tarot" then
   -- Candle peek reveals identities: name is needed for the preview strip.
   table.insert(out, { kind = "tarot", id = card.tarot, name = RaceTarot.Name(card.tarot),
    symbol = RaceTarot.Symbol(card.tarot), good = card.good })
  else
   table.insert(out, publicCard(card))
  end
 end
 return out
end

local function applyTarot(state, seat, zone, card, now)
 local id = card.tarot
 local good = RaceTarot.IsGood(id)
 seat.roundStats.tarot += 1
 if good then seat.roundStats.good += 1 else seat.roundStats.bad += 1 end
 table.insert(state.tarotLog, { round = state.round, seat = seat.index, id = id, good = good })
 if #state.tarotLog > 40 then table.remove(state.tarotLog, 1) end

 if seat.cancelBad and not good then
  seat.cancelBad = false
  return
 end

 if id == "rose" then seat.hp = math.min(seat.maxHp, seat.hp + 10)
 elseif id == "guardian" then seat.roundArmor += 6
 elseif id == "sun" then zone.dmgMult *= 1.6
 elseif id == "moon" then seat.incomingMult *= 0.65
 elseif id == "scales" then zone.scales = true
 elseif id == "clock" then zone.pull = 2
 elseif id == "focus" then seat.discardsLeft += 1
 elseif id == "wheel" then seat.winTies = true
 elseif id == "justice" then seat.cancelBad = true
 elseif id == "candle" then seat.peek = 3; seat.peekCards = peekTop(state, 3)
 elseif id == "poison" then seat.hp = math.max(0, seat.hp - 5)
 elseif id == "rust" then zone.dmgMult *= 0.75
 elseif id == "chain" then zone.zero = true
 elseif id == "load" then zone.bonusSum += 4
 elseif id == "tower" then
  local kept = {}
  for _, item in zone.cards do
   if item.kind == "tarot" then table.insert(kept, item) else table.insert(state.discard, item) end
  end
  zone.cards = kept
  zone.bonusSum = 0
 elseif id == "death" then zone.zero = true
 elseif id == "thief" then seat.discardsLeft = math.max(0, seat.discardsLeft - 1)
 elseif id == "hanged" then seat.stunUntil = math.max(seat.stunUntil, now + 1.5)
 elseif id == "darkening" then state.hidden += 3
 elseif id == "jester" then state.forceOpponentNext = seat.index
 end
end

local function takeCard(state, seat, zoneIndex, card, now)
 local zone = seat.zones[zoneIndex]
 table.insert(zone.cards, card)
 seat.roundStats.cards += 1
 seat.grabReadyAt = now + state.config.GrabCooldown
 if card.kind == "tarot" then applyTarot(state, seat, zone, card, now) end
 state.open = nil
 local revealed = if card.kind == "tarot" then {
  kind = "tarot", id = card.tarot, name = RaceTarot.Name(card.tarot),
  symbol = RaceTarot.Symbol(card.tarot), good = card.good,
 } else publicCard(card)
 state.lastTake = { round = state.round, seat = seat.index, zone = zoneIndex, card = revealed, at = now }
 state.revealAt = now
 state.nextRevealAt = now + state.config.RevealDelay
 state.revision += 1
end

-- ------------------------------------------------------------------ deck

local function drawCard(state)
 if #state.deck == 0 then
  if #state.discard == 0 then return nil end
  state.deck, state.discard = state.discard, {}
  shuffle(state.deck, state.random)
 end
 return table.remove(state.deck)
end

local function revealNext(state, now)
 local card = drawCard(state)
 state.open = card
 state.revealAt = now
 state.nextRevealAt = nil
 state.openHidden = false
 state.openSerial += 1
 if card then
  if card.kind == "tarot" then state.stats.tarotSeen += 1 end
  if state.hidden > 0 then
   state.hidden -= 1
   state.openHidden = true
  end
 end
 state.revision += 1
 return card ~= nil
end

local function discardOpen(state)
 if not state.open then return false end
 table.insert(state.discard, state.open)
 state.open = nil
 state.revision += 1
 return true
end

-- ---------------------------------------------------------------- contest

local function resolveContest(state, now)
 local pending = state.pending
 if not pending then return false end
 state.pending = nil
 local actions = {}
 for _, action in pending.actions do table.insert(actions, action) end
 table.sort(actions, function(a, b)
  if a.at == b.at then return a.seat < b.seat end
  return a.at < b.at
 end)
 local first = actions[1]
 if not first then return false end
 local winner = first
 if #actions >= 2 then
  local a, b = actions[1], actions[2]
  if a.kind == "grab" and b.kind == "grab" then
   local sa, sb = state.seats[a.seat], state.seats[b.seat]
   if sa.winTies ~= sb.winTies then
    winner = if sa.winTies then a else b
   else
    winner = if state.random:NextNumber() < 0.5 then a else b
   end
  end
 end
 local seat = state.seats[winner.seat]
 if winner.kind == "grab" then
  local zoneIndex = winner.zone
  if not zoneIndex or not zoneAccepts(seat, zoneIndex, state.target, state.config.Slots) then
   zoneIndex = activeZone(seat, state.target, state.config.Slots)
  end
  if zoneIndex and state.open then
   takeCard(state, seat, zoneIndex, state.open, now)
  elseif state.open then
   if state.open.kind == "tarot" then state.stats.tarotDiscarded += 1 end
   discardOpen(state)
   state.nextRevealAt = now + state.config.RevealDelay
  end
 else
  if state.open and state.open.kind == "tarot" then state.stats.tarotDiscarded += 1 end
  seat.discardsLeft = math.max(0, seat.discardsLeft - 1)
  seat.discardsUsed += 1
  seat.roundStats.discards += 1
  seat.discardReadyAt = winner.at + state.config.DiscardCooldown
  discardOpen(state)
  state.nextRevealAt = now + state.config.RevealDelay
 end
 state.lastContest = { round = state.round, winner = winner.seat, kind = winner.kind, actions = actions }
 state.revision += 1
 return true
end

local function addContestAction(state, seatIndex, kind, now, zoneIndex)
 if state.config.Arbitration <= 0 then
  state.pending = { startedAt = now, resolveAt = now, actions = {} }
 elseif not state.pending then
  state.pending = { startedAt = now, resolveAt = now + state.config.Arbitration, actions = {} }
 end
 state.pending.actions[seatIndex] = { seat = seatIndex, kind = kind, at = now, zone = zoneIndex }
 state.revision += 1
 local count = 0
 for _ in state.pending.actions do count += 1 end
 if count >= 2 or state.config.Arbitration <= 0 then
  resolveContest(state, now)
 elseif state.config.RevealDelay <= 0 and state.nextRevealAt then
  -- no-op: Tick will reveal
 end
 return true
end

-- ------------------------------------------------------------------ round

local function resetSeat(seat, config)
 seat.zones = emptyZones(config.Zones)
 seat.discardsLeft = config.Discards
 seat.discardsUsed = 0
 seat.discardReadyAt = 0
 seat.grabReadyAt = 0
 seat.stunUntil = 0
 seat.incomingMult = 1
 seat.roundArmor = 0
 seat.winTies = false
 seat.cancelBad = false
 seat.peek = 0
 seat.peekCards = {}
 seat.roundStartHp = seat.hp
 seat.roundStats = newStats()
end

local function startRound(state, now)
 state.phase = "round"
 state.roundBeganAt = now
 state.roundEndsAt = now + state.config.RoundSeconds
 state.target = targetFor(state.config, state.round)
 state.hidden = 0
 state.forceOpponentNext = nil
 state.pending = nil
 state.nextRevealAt = nil
 state.open = nil
 state.openHidden = false
 state.lastContest = nil
 state.receipt = nil
 for _, seat in state.seats do
  seat._state = state
  resetSeat(seat, state.config)
 end
 if not revealNext(state, now) then
  state.roundEndsAt = now
 end
 for _, seat in state.seats do
  if table.find(seat.jokers or {}, "xray") then
   seat.peek = math.max(seat.peek or 0, 1)
   seat.peekCards = peekTop(state, 1)
  end
 end
 state.revision += 1
end

local function bothClosed(state)
 return activeZone(state.seats[1], state.target, state.config.Slots) == nil
  and activeZone(state.seats[2], state.target, state.config.Slots) == nil
end

local function finishRound(state, now)
 return SharedDuel.Resolve(state, now)
end

local function contestChoices(state, seatIndex)
 local out = {}
 local pending = state.pending
 if not pending then return out end
 for _, action in pending.actions do
  table.insert(out, { seat = action.seat, kind = action.kind, at = action.at })
 end
 table.sort(out, function(a, b) return a.at < b.at end)
 return out
end

-- ------------------------------------------------------------------- API

function SharedDuel.New(config, seed, builds, options)
 local c = table.clone(config or {})
 c.RoundSeconds = c.RoundSeconds or 20
 c.HP = c.HP or 100
 c.Target = c.Target or 21
 c.TargetStep = c.TargetStep or 1
 c.TargetCap = c.TargetCap or 30
 c.Zones = c.Zones or 3
 c.Slots = c.Slots or 4
 c.Discards = c.Discards or 2
 c.DiscardCooldown = c.DiscardCooldown or 0.8
 c.GrabCooldown = c.GrabCooldown or 0.6
 c.Guard = c.Guard or 0.4
 c.Arbitration = c.Arbitration or 0.18
 c.TarotTimeout = c.TarotTimeout or 1.5
 c.RevealDelay = c.RevealDelay or 0.15
 c.TarotGood = c.TarotGood or 2
 c.TarotBad = c.TarotBad or 2
 c.ArmorPerDiscard = c.ArmorPerDiscard or 2
 c.ArmorCap = c.ArmorCap or 4
 c.SuddenRound = c.SuddenRound or 8
 c.SuddenMult = c.SuddenMult or 1.5
 if c.Tiebreak == nil then c.Tiebreak = true end
 c.MaxRounds = c.MaxRounds or 24
 c.HealScale = c.HealScale or 0.2

 local random = Random.new(seed or 1)
 local auto = if type(builds) == "table" and type(builds[1]) == "table" and type(builds[2]) == "table"
  then nil else autoBuilds(random, c)
 local first = makeBuild(if builds and builds[1] then builds[1] else auto[1], random, c)
 local second = makeBuild(if builds and builds[2] then builds[2] else auto[2], random, c)
 local state = {
  id = options and options.id or ("race-" .. tostring(seed or 1)),
  mode = "race", config = c, random = random,
  phase = "idle", round = 1, target = c.Target, revision = 0,
  deck = {}, discard = {}, deckTotal = 0, open = nil, openHidden = false,
  openSerial = 0, revealAt = 0, nextRevealAt = nil,
  roundBeganAt = 0, roundEndsAt = 0, resolvedAt = 0, finishedAt = 0,
  seats = {}, pending = nil, hidden = 0, forceOpponentNext = nil,
  winner = nil, outcome = nil, receipt = nil, journal = {}, tarotLog = {},
  stats = { cards = 0, tarotSeen = 0, tarotTaken = 0, tarotDiscarded = 0,
   tarotTimeout = 0, discards = 0, armor = 0, damage = 0, heal = 0 },
 }
 state.seats[1] = {
  index = 1, id = first.id, build = first, class = first.class, jokers = first.jokers,
  hp = c.HP, maxHp = c.HP, zones = emptyZones(c.Zones),
 }
 state.seats[2] = {
  index = 2, id = second.id, build = second, class = second.class, jokers = second.jokers,
  hp = c.HP, maxHp = c.HP, zones = emptyZones(c.Zones),
 }
 state.seats[1]._state = state
 state.seats[2]._state = state
 resetSeat(state.seats[1], c)
 resetSeat(state.seats[2], c)
 state.deck = buildDeck(c, random, { first, second })
 state.deckTotal = #state.deck
 state.stats.tarotSeen = 0
 return state
end

function SharedDuel.Begin(state, now)
 if state.phase ~= "idle" then return false, "Дуэль уже началась" end
 now = now or 0
 state.startedAt = now
 startRound(state, now)
 return true
end

function SharedDuel.NextRound(state, now)
 if state.phase ~= "resolving" then return false, "Раунд ещё не закончен" end
 now = now or 0
 for _, seat in state.seats do
  for _, zone in seat.zones do
   for _, card in zone.cards do table.insert(state.discard, card) end
  end
 end
 if state.round >= state.config.MaxRounds then
  state.phase = "finished"
  state.finishedAt = now
  local a, b = state.seats[1].hp, state.seats[2].hp
  if a > b then state.winner = 1 elseif b > a then state.winner = 2 else state.winner = nil end
  state.outcome = { winner = state.winner, reason = "round-cap" }
  state.revision += 1
  return true
 end
 state.round += 1
 startRound(state, now)
 return true
end

function SharedDuel.Grab(state, seatIndex, now)
 if state.phase ~= "round" then return false, "Сейчас нельзя брать карту" end
 local seat = state.seats[seatIndex]
 if not seat then return false, "Нет такого места" end
 now = now or 0
 if state.pending and now > state.pending.resolveAt then resolveContest(state, now) end
 if now >= state.roundEndsAt then return false, "Раунд закончился" end
 if not state.open or state.nextRevealAt then return false, "Карта ещё не открыта" end
 if now < seat.stunUntil then return false, "Ты оглушён" end
 if now < seat.grabReadyAt then return false, "Подожди немного" end
 if state.pending and state.pending.actions[seatIndex] then return false, "Ты уже действуешь" end
 if state.open.kind == "tarot" and now >= state.revealAt + state.config.TarotTimeout then
  return false, "Таро уже ушло"
 end
 local zoneIndex = activeZone(seat, state.target, state.config.Slots)
 if not zoneIndex then return false, "Нет активной зоны" end
 addContestAction(state, seatIndex, "grab", now, zoneIndex)
 return true
end

function SharedDuel.Discard(state, seatIndex, now)
 if state.phase ~= "round" then return false, "Сейчас нельзя сбрасывать" end
 local seat = state.seats[seatIndex]
 if not seat then return false, "Нет такого места" end
 now = now or 0
 if state.pending and now > state.pending.resolveAt then resolveContest(state, now) end
 if now >= state.roundEndsAt then return false, "Раунд закончился" end
 if not state.open or state.nextRevealAt then return false, "Карта ещё не открыта" end
 if now < state.revealAt + state.config.Guard then return false, "Карта только открылась" end
 if state.open.kind == "tarot" and now >= state.revealAt + state.config.TarotTimeout then
  return false, "Таро уже ушло"
 end
 if seat.discardsLeft <= 0 then return false, "Сбросы закончились" end
 if now < seat.discardReadyAt then return false, "Подожди немного" end
 if now < seat.stunUntil then return false, "Ты оглушён" end
 if state.pending and state.pending.actions[seatIndex] then return false, "Ты уже действуешь" end
 addContestAction(state, seatIndex, "discard", now, nil)
 return true
end

function SharedDuel.Stand(state, seatIndex, now)
 if state.phase ~= "round" then return false, "Сейчас нельзя остановиться" end
 local seat = state.seats[seatIndex]
 if not seat then return false, "Нет такого места" end
 now = now or 0
 if state.pending then return false, "Подожди карту" end
 if now < seat.stunUntil then return false, "Ты оглушён" end
 local zoneIndex = activeZone(seat, state.target, state.config.Slots)
 if not zoneIndex then return false, "Нет активной зоны" end
 if #seat.zones[zoneIndex].cards == 0 then return false, "Зона пуста" end
 seat.zones[zoneIndex].stood = true
 state.revision += 1
 if bothClosed(state) then finishRound(state, now) end
 return true
end

local function hitsFor(seat, result, loss)
 local hits, total = {}, 0
 for i, zone in seat.zones do
  if result.zones[i].damage > 0 then
   local ordinary = {}
   for _, card in zone.cards do if card.kind ~= "tarot" then table.insert(ordinary, card) end end
   if #ordinary > 0 then
    total += result.zones[i].damage
    for _, card in ordinary do
     table.insert(hits, { card = copy(card), zone = i, weight = result.zones[i].damage / #ordinary })
    end
   end
 end
 end
 local cumulative, assigned = 0, 0
 for _, hit in hits do
  cumulative += hit.weight
  local share = if total > 0 then rounded(loss * cumulative / total) else 0
  hit.damage = share - assigned
  assigned = share
  hit.weight = nil
 end
 return hits
end

function SharedDuel.Resolve(state, now)
 if state.phase ~= "round" then return false, "Раунд уже закончен" end
 now = now or 0
 local seats = state.seats
 local forecast = { evaluatePlayer(seats[1], state.target, state.config), evaluatePlayer(seats[2], state.target, state.config) }
 local sudden = if state.round >= state.config.SuddenRound then state.config.SuddenMult else 1
 local preHp = { seats[1].roundStartHp, seats[2].roundStartHp }
 local armors, incoming, hpBeforeHit, newHp = {}, {}, {}, {}
 for i = 1, 2 do
  local seat = seats[i]
  local discardArmor = math.min(state.config.ArmorCap, math.max(0, seat.discardsLeft) * state.config.ArmorPerDiscard)
  armors[i] = math.min(ARMOR_MAX, discardArmor + seat.roundArmor + forecast[i].armor)
  incoming[i] = rounded(forecast[3 - i].damage * seat.incomingMult * sudden)
  hpBeforeHit[i] = seat.hp
  local afterHeal = math.min(seat.maxHp, seat.hp + forecast[i].heal)
  local absorbed = math.min(incoming[i], armors[i])
  newHp[i] = math.max(0, afterHeal - (incoming[i] - absorbed))
 end

 local receipt = { round = state.round, target = state.target, sudden = sudden, seats = {}, logs = {} }
 for i = 1, 2 do
  local seat = seats[i]
  local other = seats[3 - i]
  local absorbed = math.min(incoming[i], armors[i])
  local actualLossMe = math.max(0, hpBeforeHit[i] - newHp[i])
  local actualLossOther = math.max(0, hpBeforeHit[3 - i] - newHp[3 - i])
  local outgoingHits = hitsFor(seat, forecast[i], actualLossOther)
  local incomingHits = hitsFor(other, forecast[3 - i], actualLossMe)
  seat.roundStats.armor = armors[i]
  seat.roundStats.busts = forecast[i].busts
  seat.roundStats.zones2 = 0
  seat.roundStats.scored = 0
  for _, zone in seat.zones do
   local regular, damage = 0, duelDamage(zone, state.target)
   for _, card in zone.cards do if card.kind ~= "tarot" then regular += 1 end end
   if regular >= 2 then seat.roundStats.zones2 += 1 end
   if damage > 0 then seat.roundStats.scored += 1 end
  end
  receipt.seats[i] = {
   seat = i, damage = forecast[i].damage, heal = forecast[i].heal,
   incoming = incoming[i], armor = armors[i], absorbed = absorbed,
   blocked = absorbed, hpBeforeRound = preHp[i], hpBeforeHit = hpBeforeHit[i],
   hpAfter = newHp[i], enemyHpAfter = newHp[3 - i],
   busts = forecast[i].busts, zones = forecast[i].zones,
   hits = outgoingHits, incomingHits = incomingHits,
   stats = copy(seat.roundStats),
  }
  state.stats.cards += seat.roundStats.cards
  state.stats.tarotTaken += seat.roundStats.tarot
  state.stats.discards += seat.roundStats.discards
  state.stats.armor += absorbed
  state.stats.damage += forecast[i].damage
  state.stats.heal += forecast[i].heal
 end
 state.receipt = receipt
 local deadA, deadB = newHp[1] <= 0, newHp[2] <= 0
 local winner, reason
 if deadA and deadB then
  if state.config.Tiebreak then
   if preHp[1] > preHp[2] then winner, reason = 1, "double-ko-hp"
   elseif preHp[2] > preHp[1] then winner, reason = 2, "double-ko-hp"
   else winner, reason = nil, "double-ko-draw" end
  else
   winner, reason = nil, "double-ko-draw"
  end
 elseif deadA then winner, reason = 2, "ko"
 elseif deadB then winner, reason = 1, "ko"
 elseif state.round >= state.config.MaxRounds then
  if newHp[1] > newHp[2] then winner, reason = 1, "round-cap"
  elseif newHp[2] > newHp[1] then winner, reason = 2, "round-cap"
  else winner, reason = nil, "round-cap-draw" end
 end
 seats[1].hp, seats[2].hp = newHp[1], newHp[2]
 if state.open then discardOpen(state) end
 state.pending = nil
 state.nextRevealAt = nil
 local hpText = string.format("Раунд %d: %d:%d HP · урон %d:%d · броня %d:%d",
  state.round, newHp[1], newHp[2], forecast[1].damage, forecast[2].damage, armors[1], armors[2])
 table.insert(state.journal, hpText)
 if #state.journal > 20 then table.remove(state.journal, 1) end
 state.revision += 1
 if winner or reason then
  state.phase = "finished"
  state.finishedAt = now
  state.winner = winner
  state.outcome = { winner = winner, reason = reason }
  seats[1].result = resultFor(winner, 1)
  seats[2].result = resultFor(winner, 2)
 else
  state.phase = "resolving"
  state.resolvedAt = now
 end
 return true
end

function SharedDuel.Tick(state, now)
 now = now or 0
 state.now = now
 if state.phase ~= "round" then return false end

 if state.nextRevealAt and now >= state.nextRevealAt then
  state.nextRevealAt = nil
  if not revealNext(state, now) then
   return finishRound(state, now)
  end
 end

 if state.forceOpponentNext and state.open and now >= state.revealAt + 0.25 then
  local taker = state.forceOpponentNext
  local victim = state.seats[3 - taker]
  state.forceOpponentNext = nil
  local zoneIndex = activeZone(victim, state.target, state.config.Slots)
  if zoneIndex then
   takeCard(state, victim, zoneIndex, state.open, now)
  else
   if state.open.kind == "tarot" then state.stats.tarotDiscarded += 1 end
   discardOpen(state)
   state.nextRevealAt = now + state.config.RevealDelay
  end
 end

 if state.pending and (now >= state.pending.resolveAt or now >= state.roundEndsAt) then
  resolveContest(state, now)
 end

 if state.open and state.open.kind == "tarot" and now >= state.revealAt + state.config.TarotTimeout then
  local protected = state.pending and state.pending.startedAt <= state.revealAt + state.config.TarotTimeout
  if not protected then
   state.stats.tarotTimeout += 1
   discardOpen(state)
   state.nextRevealAt = now + state.config.RevealDelay
  end
 end

 if now >= state.roundEndsAt then
  return finishRound(state, now)
 end
 if not state.open and not state.nextRevealAt and #state.deck == 0 and #state.discard == 0 then
  return finishRound(state, now)
 end
 if bothClosed(state) then
  return finishRound(state, now)
 end
 return false
end

function SharedDuel.Forfeit(state, seatIndex, now)
 if state.phase == "finished" then return false end
 now = now or 0
 state.phase = "finished"
 state.finishedAt = now
 if seatIndex == 1 then state.winner = 2 elseif seatIndex == 2 then state.winner = 1 else state.winner = nil end
 state.outcome = { winner = state.winner, reason = "forfeit" }
 state.seats[1].result = resultFor(state.winner, 1)
 state.seats[2].result = resultFor(state.winner, 2)
 state.revision += 1
 return true
end

-- ------------------------------------------------------------------ view

local function currentArmor(seat, target, config)
 local discardArmor = math.min(config.ArmorCap, math.max(0, seat.discardsLeft) * config.ArmorPerDiscard)
 local forecast = evaluatePlayer(seat, target, config)
 return math.min(ARMOR_MAX, discardArmor + (seat.roundArmor or 0) + forecast.armor)
end

local function zoneView(zone, target)
 local result = evalZone(zone, target)
 result.damage = duelDamage(zone, target)
 return {
  cards = copy(zone.cards), stood = zone.stood, sum = result.sum, damage = result.damage,
  exact = result.exact, bust = result.bust, heal = result.heal, regular = result.regular,
  red = result.red, black = result.black, critical = result.critical,
  zero = zone.zero, bonusSum = zone.bonusSum, dmgMult = zone.dmgMult,
  pull = zone.pull, scales = zone.scales, result = result,
 }
end

local function seatView(state, index, now)
 local seat = state.seats[index]
 local zones = {}
 for i, zone in seat.zones do zones[i] = zoneView(zone, state.target) end
 local forecast = evaluatePlayer(seat, state.target, state.config)
 return {
  index = index, id = seat.id, class = seat.class, jokers = copy(seat.jokers),
  hp = seat.hp, maxHp = seat.maxHp, zones = zones,
  discardsLeft = seat.discardsLeft, discardsUsed = seat.discardsUsed,
  discardReadyIn = math.max(0, (seat.discardReadyAt or 0) - now),
  grabReadyIn = math.max(0, (seat.grabReadyAt or 0) - now),
  stunIn = math.max(0, (seat.stunUntil or 0) - now),
  armor = currentArmor(seat, state.target, state.config),
  incomingMult = seat.incomingMult, winTies = seat.winTies, cancelBad = seat.cancelBad,
  peek = if index == (state.viewSeat or index) then copy(seat.peekCards) else nil,
  forecast = { damage = forecast.damage, heal = forecast.heal, busts = forecast.busts,
   exact = 0, cards = forecast.cards, zones = forecast.zones, armor = forecast.armor },
  result = seat.result,
 }
end

function SharedDuel.View(state, seatIndex, now)
 seatIndex = seatIndex or 1
 now = now or state.now or state.roundBeganAt or 0
 state.viewSeat = seatIndex
 local me = state.seats[seatIndex]
 local other = state.seats[3 - seatIndex]
 local phase = state.phase
 if phase == "finished" then
  phase = resultFor(state.winner, seatIndex)
 elseif phase == "idle" then phase = "intro"
 elseif phase == "resolving" then phase = "resolving"
 end
 local ownForecast = evaluatePlayer(me, state.target, state.config)
 local zones = {}
 for i, zone in me.zones do zones[i] = zoneView(zone, state.target) end
 local otherZones = {}
 for i, zone in other.zones do otherZones[i] = zoneView(zone, state.target) end
 local open = publicCard(state.open)
 if open and state.openHidden and open.kind == "normal" then
  open = { kind = "normal", hidden = true, back = true }
 end
 local peek = if me.peekCards and #me.peekCards > 0 then copy(me.peekCards) else nil
 local myReceipt = state.receipt and state.receipt.seats[seatIndex]
 local theirReceipt = state.receipt and state.receipt.seats[3 - seatIndex]
 local legacyReceipt = nil
 if myReceipt and theirReceipt then
  legacyReceipt = {
   round = state.receipt.round, damage = myReceipt.damage, received = myReceipt.incoming,
   heal = myReceipt.heal, ownBefore = myReceipt.hpBeforeHit, ownHealed = myReceipt.hpBeforeHit,
   enemyHealBefore = theirReceipt.hpBeforeHit, enemyBefore = theirReceipt.hpBeforeHit,
   enemyAfter = theirReceipt.hpAfter, ownArmorBefore = myReceipt.armor,
   ownArmorAfter = myReceipt.armor, ownBlocked = myReceipt.blocked,
   enemyArmorBefore = theirReceipt.armor, enemyArmorAfter = theirReceipt.armor,
   enemyBlocked = theirReceipt.blocked, hits = myReceipt.hits,
   incoming = { enemyBefore = myReceipt.hpBeforeHit, enemyAfter = myReceipt.hpAfter,
    hits = myReceipt.incomingHits, returns = {} },
  }
 end
 local recentTarot = {}
 for i = math.max(1, #state.tarotLog - 5), #state.tarotLog do
  table.insert(recentTarot, copy(state.tarotLog[i]))
 end
 local view = {
  id = state.id, mode = "race", phase = phase, revision = state.revision,
  round = state.round, roundsTotal = state.config.MaxRounds,
  roundsLeft = math.max(0, state.config.MaxRounds - state.round + 1),
  target = state.target, slots = state.config.Slots,
  hp = me.hp, maxHp = me.maxHp, enemyHp = other.hp, enemyMaxHp = other.maxHp,
  armor = currentArmor(me, state.target, state.config),
  enemyArmor = currentArmor(other, state.target, state.config), armorMax = ARMOR_MAX,
  deckCount = #state.deck, deckTotal = state.deckTotal, discardCount = #state.discard,
  zones = zones, active = activeZone(me, state.target, state.config.Slots),
  forecast = { damage = ownForecast.damage, heal = ownForecast.heal, busts = ownForecast.busts,
   exact = 0, cards = ownForecast.cards, zones = ownForecast.zones, armor = ownForecast.armor },
  class = me.class, jokers = copy(me.jokers), peek = peek,
  journal = copy(state.journal), receipt = legacyReceipt, network = true,
  roundSeconds = state.config.RoundSeconds, timeLeft = math.max(0, state.roundEndsAt - now),
  discardLimit = state.config.Discards,
  supplies = { minus2 = 0, minus4 = 0 },
  sleeveUsed = 0, sleeveCount = 0, scanCharges = 0,
  tarotUsed = me.roundStats and me.roundStats.tarot or 0,
  tarotLimit = state.config.TarotGood + state.config.TarotBad,
  race = {
   you = seatIndex, open = open, peek = peek,
   nextRevealIn = math.max(0, (state.nextRevealAt or 0) - now),
   tarotTimeoutIn = if state.open and state.open.kind == "tarot"
    then math.max(0, state.revealAt + state.config.TarotTimeout - now) else nil,
   deckCount = #state.deck, discardCount = #state.discard, deckTotal = state.deckTotal,
   contest = {
    active = state.pending ~= nil,
    endsIn = if state.pending then math.max(0, state.pending.resolveAt - now) else 0,
    yours = state.pending and state.pending.actions[seatIndex] ~= nil or false,
    theirs = state.pending and state.pending.actions[3 - seatIndex] ~= nil or false,
   },
   seats = { seatView(state, 1, now), seatView(state, 2, now) },
   lastContest = copy(state.lastContest),
   lastTake = copy(state.lastTake),
   tarotLog = recentTarot,
   outcome = copy(state.outcome),
   target = state.target, round = state.round, timeLeft = math.max(0, state.roundEndsAt - now),
   sudden = state.round >= state.config.SuddenRound,
  },
  duel = { opponentKind = "player", revealed = true, enemyZones = otherZones,
   enemyClass = other.class, enemyJokers = copy(other.jokers),
   enemyReady = true, enemyDeckTotal = state.deckTotal, enemyDeckCount = #state.deck,
   enemySupplies = { minus2 = 0, minus4 = 0 }, enemyArmor = currentArmor(other, state.target, state.config),
   enemyScanCharges = 0 },
 }
 view.duel.enemyZones = otherZones
 return view
end

-- Exposed for QA and for a future training bot.
SharedDuel.Evaluate = evaluatePlayer
SharedDuel.Zone = evalZone
SharedDuel.Damage = duelDamage
SharedDuel.ActiveZone = activeZone
SharedDuel.TargetFor = targetFor
SharedDuel.HitsFor = hitsFor
SharedDuel.CurrentArmor = currentArmor
SharedDuel.ContestChoices = contestChoices

return SharedDuel
