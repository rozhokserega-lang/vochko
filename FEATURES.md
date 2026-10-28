# Tactical update

The game entry point remains `index_vochko_v8.html`. It loads `assets/game-features.js` before the inline game code and `assets/reference-theme.css` for the portrait interface.

- Run checkpoints: browser localStorage key `vochko.run.v1`, separate from permanent progression. The setup screen shows Continue when a valid checkpoint exists. Stable actions save automatically; score animations retain the preceding checkpoint. Completion/death clears it. Consumable definitions, event callbacks, and shop card references are rebound on resume. Daily PRNG state is preserved; effects use the independent cosmetic RNG.
- Forecast: `attackPreview`, `enemyResponse`, and `combatForecast` share the real attack and enemy response calculations. The displayed HP loss accounts for shields, armor, weakness, damage jokers, table healing, revival, enemy abilities, and lethal attacks. A final-round warning accounts for Phoenix.
- Deck inspection: tap the small deck. The book groups remaining cards by rank/suit/upgrade/modification and lists draw, discard, and table counts. No shuffle order is exposed. The return button sticks while scrolling.
- Enemy identities: Collector accepts $3 to cancel its next announced attack (not bust damage); Brawler announces a heavy blow every third round, reduced 40% by a non-bust table of four or more cards; Sentinel loses two percentage points of armor per exact table for the rest of the fight; Usurer's announced heal is canceled by two exact tables. Bosses retain their house rules.
- Transfer: a $5 consumable moves one selected card to another unblocked table below capacity. Closed tables can reopen; frozen prefixes adjust when a card is removed, and a frozen destination retains its frozen prefix. It obeys Seal/one-item bosses and Alchemist. The source/destination are selected in an accessible modal; cancel spends nothing.
- Reservation: one unsold joker, consumable, rank upgrade or modification can be reserved free. It survives rerolls and arrives at the next shop at the same price. Selecting another item changes the reservation; buying consumes it. An item rendered invalid by intervening deck/event changes is omitted.
- Attack choreography: `assets/attack-fx.js` and `.css` collect card motes into the damage counter (~490ms), send an impulse to the enemy (220ms), commit damage on impact, then resolve the enemy response 270ms later. Controls are locked through the sequence. Cosmetic effects use only `RNG0`. Reduced motion skips the sequence; backgrounding fast-forwards safely; restarting cancels the old sequence. Stable save checkpoints remain intact until resolution. Direct calls to `finishSeat(result)` remain synchronous for deterministic combat checks.
- Mobile readability: `assets/mobile-polish.css` gives sums 32px, HP 18px and touch controls 13–15px text with 44–54px targets. Consumables are immediately below the goal/deck row. Controls stay in normal flow so they never cover tables or the forecast; small screens scroll. Telegram system and content safe areas are combined and updated on SDK inset/viewport events, including overlays and bottom spacing. Fine gold borders replace small decorative frames; idle table confetti is removed.
- Turn budget: a full-width banner in the battle panel shows remaining/total turns in large numbers with one segment per turn. One remaining turn uses an explicit last-turn warning. Draw and stop-table do not spend turns; "Сыграть ход" resolves one complete set of tables. The banner follows extra-turn jokers, difficulty and contracts, updates on impact, and hides outside battle. Shop offers use compact list rows with 30–36px art, 14px descriptions, and full-size purchase/reserve targets.

Verification (Node + bundled Playwright, installed Edge):

```
rtk proxy node .preview/check-layout.cjs
rtk proxy node .preview/check-new-mechanics.cjs
rtk proxy node .preview/check-tactical.cjs
rtk proxy node .preview/check-attack-fx.cjs
rtk proxy node .preview/check-telegram-layout.cjs
rtk proxy node .preview/check-shop-rounds.cjs
```

Layout checks cover 320–1440px, three/four tables and touch controls. Tactical checks compare forecast to complete real turns, reload different progression phases, exercise selection UIs, verify daily RNG and item references, and cover transfer/reservation rules.
