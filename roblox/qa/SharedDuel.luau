-- QA for the real-time shared-deck duel. Run from the Studio command bar:
-- require(game.ServerScriptService.VochkoPrototypeServer) is not the test runner;
-- paste the body into a Script or execute it with the Studio MCP execute_luau tool.
local SharedDuel = require(game.ServerStorage.VochkoPrototype.SharedDuel)
local RaceTarot = require(game.ReplicatedStorage.VochkoPrototype.RaceTarot)
local Loadout = require(game.ReplicatedStorage.VochkoPrototype.Loadout)
local Config = require(game.ServerStorage.VochkoPrototype.Config)
local config = Config.ForDuelRace()
local count = 0
local function check(value, name) assert(value, name); count += 1 end
local function near(a, b) return math.abs(a - b) < 0.001 end

local function normalCard(rank, suit, value, red)
 return { id = "qa-" .. rank .. suit, kind = "normal", rank = rank, suit = suit,
  suitIndex = 1, rankIndex = 1, value = value, red = red or false }
end

local function lethalZone(mult)
 return { cards = { normalCard("10", "♠", 10, false) }, stood = false, bonusSum = 0,
  dmgMult = mult, zero = false, pull = 0, scales = false }
end

local function putTarotOnTop(state)
 local index
 for i, card in state.deck do if card.kind == "tarot" then index = i; break end end
 check(index ~= nil, "Deck contains tarot")
 local card = table.remove(state.deck, index)
 table.insert(state.deck, card)
 return card
end

-- 1. Deck composition and no shared identity leak before Begin.
local state = SharedDuel.New(config, 12345)
check(state.deckTotal == 60, "Race deck is 60 cards")
check(#state.deck == 60, "All cards are in the shared deck")
local normal, tarot, ids = 0, 0, {}
local good, bad = 0, 0
for _, card in state.deck do
 check(not ids[card.id], "Card ids are unique: " .. tostring(card.id)); ids[card.id] = true
 if card.kind == "normal" then normal += 1 else
  tarot += 1
  if RaceTarot.IsGood(card.tarot) then good += 1 else bad += 1 end
 end
end
check(normal == 52, "52 ordinary cards")
check(tarot == 8 and good == 4 and bad == 4, "Eight tarot, four good and four bad")
check(#state.seats[1].build.tarot == 4 and #state.seats[2].build.tarot == 4, "Each seat owns four tarot")
local intro = SharedDuel.View(state, 1, 0)
check(intro.phase == "intro", "Idle state is intro")
check(intro.deck == nil and intro.race.open == nil, "No hidden deck in intro view")

-- 2. Begin, guard, discard and cooldown.
check(SharedDuel.Begin(state, 0), "Begin accepted")
check(state.phase == "round" and state.open ~= nil, "Round starts with an open card")
local view = SharedDuel.View(state, 1, 0)
check(view.race.open ~= nil, "Open card is visible")
check(view.deck == nil and view.race.deck == nil, "Deck order is never sent")
check(view.race.seats[2].peek == nil, "Opponent peek is hidden")
check(not SharedDuel.Discard(state, 1, 0.1), "Fresh card cannot be discarded during guard")
check(SharedDuel.Discard(state, 1, 0.5), "Discard after guard is accepted")
check(state.pending ~= nil, "Discard enters the arbitration window")
SharedDuel.Tick(state, 0.7)
check(state.seats[1].discardsLeft == config.Discards - 1, "Discard is spent after arbitration")
check(#state.discard >= 1 and state.open == nil, "Open card goes to the shared discard")
check(state.nextRevealAt ~= nil, "A new card waits for the reveal delay")
SharedDuel.Tick(state, 0.9)
check(state.open ~= nil, "Next card is revealed")
local before = state.seats[1].discardsLeft
check(not SharedDuel.Discard(state, 1, 1.1), "Discard cooldown blocks a second discard")
check(state.seats[1].discardsLeft == before, "Blocked discard costs nothing")

-- 3. Two grabs inside the arbitration window: one winner, loser spends nothing.
local race = SharedDuel.New(config, 777, nil, { id = "arb" })
SharedDuel.Begin(race, 0)
check(SharedDuel.Grab(race, 1, 0.05), "First grab is buffered")
check(race.pending ~= nil and race.pending.actions[1] ~= nil, "First grab is pending")
check(SharedDuel.Grab(race, 2, 0.15), "Second grab joins the window")
check(race.pending == nil and race.lastContest ~= nil, "Contest resolves immediately when both acted")
local winner = race.lastContest.winner
local loser = 3 - winner
check(winner == 1 or winner == 2, "Contest has a winner")
check(#race.seats[winner].zones[1].cards == 1, "Winner gets the card")
check(#race.seats[loser].zones[1].cards == 0, "Loser gets nothing")
check(race.seats[loser].grabReadyAt == 0, "Loser spends no grab cooldown")
check(race.seats[winner].grabReadyAt > 0, "Winner gets grab cooldown")

-- 4. Wheel wins arbitration.
local wheel = SharedDuel.New(config, 888, nil, { id = "wheel" })
SharedDuel.Begin(wheel, 0)
wheel.seats[1].winTies = true
SharedDuel.Grab(wheel, 1, 0.05)
SharedDuel.Grab(wheel, 2, 0.10)
check(wheel.lastContest.winner == 1, "Wheel wins a grab tie")

-- 5. Closed tarot expires without revealing its identity.
local timed = SharedDuel.New(config, 999, nil, { id = "timeout" })
local topTarot = putTarotOnTop(timed)
SharedDuel.Begin(timed, 0)
check(timed.open == topTarot, "Tarot is the open card")
local hidden = SharedDuel.View(timed, 1, 0).race.open
check(hidden.hidden == true and hidden.tarot == nil and hidden.rank == nil, "Tarot back hides identity")
SharedDuel.Tick(timed, 1.6)
check(timed.stats.tarotTimeout == 1, "Unclaimed tarot times out")
check(timed.open == nil and timed.nextRevealAt ~= nil, "Timed-out tarot leaves the table")
check(table.find(timed.discard, topTarot) ~= nil, "Timed-out tarot goes to shared discard")
SharedDuel.Tick(timed, 1.8)
check(timed.open ~= nil and timed.open ~= topTarot, "A fresh card follows the timeout")

-- 6. Unused discards become armor before damage, then next round clears zones.
local armor = SharedDuel.New(config, 42, nil, { id = "armor" })
SharedDuel.Begin(armor, 0)
armor.seats[1].discardsLeft = 2
armor.seats[2].discardsLeft = 1
check(SharedDuel.Resolve(armor, 1), "Empty round resolves")
check(armor.receipt.seats[1].armor == 4, "Two unused discards give four armor")
check(armor.receipt.seats[2].armor == 2, "One unused discard gives two armor")
check(armor.seats[1].hp == 100 and armor.seats[2].hp == 100, "No damage from empty zones")
check(armor.phase == "resolving", "Non-lethal round continues")
check(SharedDuel.NextRound(armor, 2), "Next round starts")
check(armor.target == 22 and armor.round == 2, "Target grows to 22")
check(armor.seats[1].discardsLeft == config.Discards, "Discards reset each round")

-- 7. Double KO uses HP before the round as the tiebreak.
local tie = SharedDuel.New(config, 55, nil, { id = "tie" })
SharedDuel.Begin(tie, 0)
tie.seats[1].hp, tie.seats[2].hp = 40, 60
tie.seats[1].roundStartHp, tie.seats[2].roundStartHp = 40, 60
tie.seats[1].zones[1], tie.seats[2].zones[1] = lethalZone(100), lethalZone(100)
check(SharedDuel.Resolve(tie, 1), "Double KO resolves")
check(tie.seats[1].hp == 0 and tie.seats[2].hp == 0, "Both seats reach zero")
check(tie.winner == 2 and tie.outcome.reason == "double-ko-hp", "More pre-round HP wins the tiebreak")
check(SharedDuel.View(tie, 1, 1).phase == "lost", "Loser sees lost")
check(SharedDuel.View(tie, 2, 1).phase == "won", "Winner sees won")

local equal = SharedDuel.New(config, 56, nil, { id = "equal" })
SharedDuel.Begin(equal, 0)
equal.seats[1].hp, equal.seats[2].hp = 50, 50
equal.seats[1].roundStartHp, equal.seats[2].roundStartHp = 50, 50
equal.seats[1].zones[1], equal.seats[2].zones[1] = lethalZone(100), lethalZone(100)
SharedDuel.Resolve(equal, 1)
check(equal.winner == nil and equal.phase == "finished", "Equal double KO is a draw")

-- 8. Sudden death and target cap.
check(SharedDuel.TargetFor(config, 1) == 21, "Target starts at 21")
check(SharedDuel.TargetFor(config, 20) == 30, "Target caps at 30")
local sudden = SharedDuel.New(config, 57, nil, { id = "sudden" })
SharedDuel.Begin(sudden, 0)
sudden.round = config.SuddenRound
sudden.roundStartHp, sudden.roundStartHp = 100, 100
sudden.seats[1].zones[1] = lethalZone(1)
local suddenResult = SharedDuel.Resolve(sudden, 1)
check(suddenResult and sudden.receipt.sudden == 1.5, "Sudden death multiplier is applied")

-- 9. Reshuffle from the shared discard when the deck empties.
local recycle = SharedDuel.New(config, 58, nil, { id = "recycle" })
SharedDuel.Begin(recycle, 0)
local kept = {}
for i = 1, 5 do table.insert(kept, table.remove(recycle.deck)) end
recycle.deck = {}
recycle.discard = kept
recycle.open = nil
recycle.nextRevealAt = 0
SharedDuel.Tick(recycle, 0.01)
check(recycle.open ~= nil, "Discard is reshuffled when the deck is empty")
check(#recycle.deck == 4, "One card left the reshuffled deck")

-- 10. Loadout validation for the 2+2 race deck.
check(Loadout.ValidateRace("sharp", { "crimson", "blot" }, { "rose", "sun", "poison", "rust" }), "Valid 2+2 race build")
check(not Loadout.ValidateRace("sharp", { "crimson", "blot" }, { "rose", "sun", "moon", "poison" }), "Three good tarot is rejected")
check(not Loadout.ValidateRace("sharp", { "crimson", "crimson" }, { "rose", "sun", "poison", "rust" }), "Duplicate joker is rejected")
local defaults = Loadout.DefaultRaceTarot(7)
check(#defaults == 4 and RaceTarot.ValidateLoadout(defaults, 2, 2), "Default race tarot is valid")

return { passed = count, deck = state.deckTotal, tarot = tarot }
