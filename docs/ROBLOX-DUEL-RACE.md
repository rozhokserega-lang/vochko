# Vochko · real-time shared-deck duel (draft v1.0)

Status: balance pass complete, server/UI implementation not started.
Source of numbers: `tests/playtest/duel-race-sim.cjs` (headless, bot vs bot).
This document is the handoff for `SharedDuel.luau`, the PvP network layer and the table client.

## 1. Core rules

- One shared deck: 52 ordinary cards + 2 good + 2 bad tarot from each player = 60 cards.
- One open card on the table. Both players see it. The first valid grab wins.
- Each player has 3 own zones, 4 slots each. A grabbed card goes into the grabber's current zone.
  Shared are only the deck, the open card and the discard pile.
- At the end of the round each player's zones hit the opponent's HP:
  distance to target `0=8, 1=6, 2=5, 3=4, <=5=3, <=9=2, else 1`.
  Bust = 0. Critical (3+ aces) = x2. All-black bonus +10/15%. All-red heal 10/15, scaled by 20%.
- Target starts at 21, grows by 1 per round, capped at 30.
- Round ends by timer, or earlier when both players have no active zone.
- HP 100. Sudden death from round 8: damage x1.5.
- If both players reach 0 HP in the same round, the player with more HP **before** the round wins.
  Equal HP before the round = draw. This removes the ~25% double-KO draws seen in the sim.

## 2. Timing (final values)

| Parameter | Value | Notes |
|---|---:|---|
| Round | **20 s** | 15 s is borderline, 18 s is the minimum, 20 s is the comfort point |
| Reveal guard | 400 ms | nobody may discard the fresh card before this |
| Arbitration window | 180 ms | both grabs inside the window = random winner, loser spends nothing |
| Grab cooldown | 600 ms | after a successful grab |
| Discard cooldown | 800 ms | after a discard |
| Discards per round | 2 | unused discards become armor at the end of the round |
| Tarot timeout | 1500 ms | unclaimed closed tarot goes to discard, identity is not revealed |
| Reveal animation | 150 ms | server-side gap before the next card is open |
| Armor per unused discard | 2 | max 4 from discards per round |
| Armor cap | 4 | tarot/class armor is separate, total cap 12 |
| Sudden death | round 8, x1.5 | |

Armor is granted **before** damage of the same round and does not carry over.
A discard therefore trades 2 armor for tempo / denial / information destruction.

## 3. Tarot

All tarot have the same back, no owner mark. Identity is revealed only when taken.
A discarded or timed-out tarot returns to the shared discard and is shuffled back later.

Good (2 per player):
- **Rose** +10 HP
- **Guardian** +6 armor
- **Sun** zone damage x1.6
- **Moon** incoming damage x0.65
- **Scales** exact zone x1.5
- **Clock** pulls a zone to target if it is within 2
- **Focus** +1 discard this round
- **Wheel** wins arbitration ties
- **Justice** cancels the next bad tarot you take
- **Candle** peeks the next 3 cards

Bad (2 per player):
- **Poison** -5 HP
- **Rust** zone damage x0.75
- **Chain** closes the current zone (0 damage)
- **Load** +4 to the zone sum (can bust it)
- **Tower** discards the ordinary cards of the zone
- **Death** the zone deals 0 this round
- **Thief** -1 discard
- **Hanged** stun 1.5 s
- **Darkening** the next 3 reveals are hidden for both
- **Jester** the next open card goes to the opponent if they have an active zone

Good effects are deliberately stronger than bad: +10 vs -5 HP, x1.6 vs x0.75 damage.
Bad tarot mostly costs tempo and a slot, not raw HP.

## 4. Bot decision model used for tuning

- Reaction: lognormal, strong 0.42 s median / 0.25 sigma / 0.90 decision quality;
  weak 0.50 s / 0.30 / 0.50. This produces ~66-69% wins for the strong bot, not 90%.
- Bots see both tables, the open card and the tarot counts already revealed.
- A bot evaluates the damage delta of a card, the denial value of a discard, the slot cost
  of a tarot and the time left in the round. Bots pass on cards that do not fit and wait
  for a better one; they stand a decent zone only when the card is bad for it or fits
  another zone much better. They never abandon a one-card zone.

## 5. Simulation results

2+2 tarot, 1.5 s timeout, 0.6 s grab cooldown, armor 2, HP 100, tiebreak on.
`z2/player` = average number of zones with 2+ ordinary cards per player per round.
`low` = share of rounds where at least one player ends with fewer than 2 such zones.

### Round length

| Round | Strong WR | Game rounds | z2/player | low | Cards/player | Round time |
|---:|---:|---:|---:|---:|---:|---:|
| 15 s | 69.0% | 11.1 | 2.46 | 9.1% | 8.1 | 15.0 s |
| 16 s | 70.2% | 10.5 | 2.56 | 6.6% | 8.4 | 15.9 s |
| **18 s** | 68.9% | 9.6 | 2.72 | 3.5% | 9.0 | 17.8 s |
| **20 s** | **66.8%** | **9.0** | **2.84** | **1.8%** | **9.4** | **19.4 s** |
| 22 s | 65.9% | 8.8 | 2.90 | 0.9% | 9.7 | 20.7 s |
| 25 s | 66.6% | 8.5 | 2.95 | 0.6% | 10.0 | 22.2 s |

**Chosen: 20 s.** 15 s misses the 2.5 zones target and gets tight against a slower opponent;
18 s is the minimum; 20 s has margin and still lands at 9 game rounds.
20 s x 9 rounds is about the same match length as 18 s x 9.6 rounds.

### Armor per unused discard (20 s)

| Armor | Strong WR | Rounds | z2/player | Discards/player | Absorbed armor |
|---:|---:|---:|---:|---:|---:|
| 1 | 72.2% | 8.5 | 2.81 | 1.41 | 2.8 |
| **2** | **67.1%** | **9.0** | **2.83** | **1.26** | **4.5** |
| 3 | 64.1% | 9.2 | 2.84 | 1.20 | 5.4 |
| 4 | 64.9% | 9.6 | 2.84 | 1.15 | 6.3 |

Armor 2 keeps discards meaningful without turning the round into a shield stack.
Armor 4 absorbs almost all of an average round and slows the game.

### Tarot count (20 s)

| Tarot | Strong WR | Rounds | z2/player | low | Taken / discarded / timeout |
|---:|---:|---:|---:|---:|---:|
| 1+1 | 68.6% | 9.0 | 2.89 | 1.2% | 22.6 / 65.0 / 8.9% |
| **2+2** | **67.1%** | **9.0** | **2.83** | **1.8%** | **22.6 / 60.3 / 13.2%** |
| 3+3 | 67.8% | 9.4 | 2.73 | 3.4% | 24.1 / 54.0 / 17.3% |

2+2 is the intended 60-card deck. 3+3 adds tarot noise and empty rounds; 1+1 is a valid
"fast" variant and is supported by config without code changes.

### Tarot timeout (20 s)

| Timeout | Strong WR | Low rounds | Timeout share |
|---:|---:|---:|---:|
| 1.0 s | 62.9% | 1.5% | 21.8% |
| **1.5 s** | **68.0%** | **1.7%** | **12.9%** |
| 2.0 s | 67.5% | 1.9% | 12.6% |
| 4.0 s | 68.0% | 3.9% | 10.9% |

1.5 s is the best point inside the requested 1-1.5 s range: 1.0 s produces too many
timeouts and pushes bots into discarding every tarot they see.

### Grab cooldown (20 s)

| Cooldown | Strong WR | Rounds | z2/player | low |
|---:|---:|---:|---:|---:|
| 0.0 s | 71.1% | 8.8 | 2.87 | 2.2% |
| 0.3 s | 73.8% | 8.8 | 2.86 | 2.0% |
| **0.6 s** | **69.4%** | **9.1** | **2.83** | **1.5%** |
| 0.9 s | 64.2% | 9.5 | 2.76 | 2.6% |
| 1.2 s | 63.6% | 10.2 | 2.62 | 4.1% |

0.6 s preserves the race without turning the round into a coin flip.

## 6. Final config

```
roundSeconds = 20
hp = 100
targetBase = 21, targetStep = 1, targetCap = 30
zones = 3, slots = 4
discards = 2, discardCooldown = 0.8
grabCooldown = 0.6, guard = 0.4, arbitration = 0.18
tarotTimeout = 1.5, revealDelay = 0.15
tarotGood = 2, tarotBad = 2
armorPerDiscard = 2, armorCap = 4
suddenDeathRound = 8, suddenDeathMult = 1.5
tiebreak = true (more HP before the round wins a double KO)
```

## 7. Table layout

PvP is a separate table mode:

- shared deck + open card in the center of the table (`x = 0`, `z = -7` in the current room);
- three zones per player on their half, mirrored;
- no per-player deck / no per-player discard visible;
- tarot backs are identical for both players, no owner tint;
- the discard pile is shared and may show only the top card's back (never a tarot identity).

This is a `RoomBuilder` + `TableScene` change; the old campaign/training tables keep
their own decks.

## 8. Open points

- `Config.Defaults` now carries `DuelRace*` keys and `Config.ForDuelRace()`; the old
  `Duel`/`Battle` path is untouched.
- 60% of tarot appearances are discarded by the bots. This is a real tradeoff (tempo vs
  2 armor), not a bug. If tarot should resolve more often, raise the good effects or
  reduce the discard armor; do not lower the timeout below 1.5 s.
- Class/joker effects are applied inside `SharedDuel` (`sharp/triple/blot`, `healer/crimson`,
  `guardian`, `tandem`, `ladder`, `xray`), so the listed example is resolved.
- The double-KO tiebreak is a new rule and needs a design sign-off.
- Bot difficulty: `DuelRaceBotSkill` (0 easy / 1 normal / 2 strong) applies per session;
  the race setup screen exposes ЛАЙТ/НОРМА/СИЛЬНО chips which send `{kind="skill"}`.
- Candle (peek) renders a `RacePeek` strip near the central deck; tarot identities are
  included in the peek payload.
- Camera stays fixed during battle: the client re-applies the Scriptable fixed view if
  anything reclaims it (self-healing guard in `render`).
- Damage feedback: red screen flash + FOV punch on HP drop, soft green flash on heal
  (`TableScene.ScreenFlash` / `HitPunch`); tarot identity reveal spawns a one-shot
  particle burst above the deck (gold for good, dark red for bad).

## 9. Asset pipeline (Nov 2026)

All texture atlases are owned by `RozhokSer` and uploaded through the built-in Studio MCP
(`roblox/tools/studio-mcp.cjs list|call|upload`, needs running Studio):

| key | file | asset |
|---|---|---|
| `Assets.Cards` | `cards-atlas.png` 936×400 | `rbxassetid://126504298884435` |
| `Assets.Portraits` | `opponents.png` 1000×400 | `rbxassetid://125128067761419` |
| `Assets.LoadoutAtlas` | `loadout/loadout-atlas-v1.png` 1024×1536 | `rbxassetid://89222272583816` |
| `Assets.Tarot` (12) | `tarot/*-v1.png` | fresh IDs, see `src/Assets.luau` |
| `Assets.RaceAtlas` | `tarot/race-tarot-atlas.png` 720×960 (5×4 cells 144×240) | `rbxassetid://87719532143821` |

Race tarot cell order is fixed in `Assets.raceArtIndex`; the source decks are the two
user-supplied sheets («Винтажная колода зелёных таро-карт», «Мрачная колода негативных карт Таро»)
with the intentional mirrored bottom halves (top/bottom table views).

`roblox/tools/studio-push.cjs` injects current repo sources into the open Studio session
(eliás a manual File→Revert), and `get_console_output` / `screen_capture`/`start_stop_play`
give headless verification. Publish to `vo4ko_test` is still a manual Studio action.
