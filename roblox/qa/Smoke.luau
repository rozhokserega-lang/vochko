-- Gameplay QA: run in Studio against ServerStorage.VochkoPrototype modules.
local Battle=require(game.ServerStorage.VochkoPrototype.Battle)
local defaults=require(game.ServerStorage.VochkoPrototype.Config).ForBattle()
defaults.Target=30
local checks={}
local function check(name,value)assert(value,name);table.insert(checks,name)end
local deck=Battle.Deck()
local function card(rank,suit)
 for _,c in deck do if c.rank==rank and c.suit==suit then return table.clone(c)end end
 error("Missing card "..rank..suit)
end
local function zone(cards,delta)return {cards=cards,delta=delta or 0,chipDelta=0,stood=false}end
check("52 unique original cards",#deck==52)
local ids={}for _,c in deck do check("unique "..c.id,not ids[c.id]);ids[c.id]=true end
local exact=Battle.Zone(zone({card("A","♠"),card("A","♥"),card("8","♦")}),30)
check("Two high aces can reach 30",exact.sum==30 and exact.exact and exact.damage==2400)
local low=Battle.Zone(zone({card("A","♠"),card("A","♥"),card("9","♦")}),30)
check("Ace lowers to avoid 31",low.sum==21 and not low.bust)
local natural=Battle.Zone(zone({card("A","♠"),card("K","♥")}),21)
check("21 comparison preserves two-card natural",natural.sum==21 and natural.damage==3360)
local busted=zone({card("K","♠"),card("Q","♥"),card("9","♦"),card("3","♣")})
check("32 busts at target 30",Battle.Zone(busted,30).bust)
local state=Battle.New(defaults,123,"sharp","qa")
state.zones[1]=busted;local chipsBefore=Battle.Zone(busted,30).damage
check("Useful correction accepted",Battle.Consume(state,"minus2",1))
local rescued=Battle.Zone(state.zones[1],30)
check("Cut rescues bust without removing chips",rescued.exact and rescued.damage==2560 and chipsBefore==0)
check("Cut consumed exactly once",state.supplies.minus2==0 and not Battle.Consume(state,"minus2",1))
local fresh=Battle.New(defaults,321,"sharp","fresh")
check("Empty board cannot spend turn",not Battle.Play(fresh) and fresh.roundsLeft==defaults.Rounds)
check("Empty zone cannot be stopped",not Battle.Stop(fresh))
for _=1,3 do check("Rapid logical draw accepted",Battle.Draw(fresh))end
local total=0 for _,z in fresh.zones do total+=#z.cards end
check("Three requests deal three cards",total==3 and #fresh.deck==49)
local other=Battle.New(defaults,999,"healer","other")
check("Independent sessions",#other.deck==52 and #other.zones[1].cards==0)
fresh.enemyHp=100000;local forecast=Battle.Forecast(fresh);local hp=fresh.hp;local rounds=fresh.roundsLeft
check("Attack accepted",Battle.Play(fresh))
check("Forecast equals actual attack",fresh.enemyHp==100000-forecast.damage)
check("Counter and healing match forecast",fresh.hp==math.max(0,math.min(defaults.PlayerHP,hp+forecast.heal)-forecast.received))
check("Only one round spent",fresh.roundsLeft==rounds-1)
check("Cannot replay while resolving",not Battle.Play(fresh))
Battle.Next(fresh);check("Next round recycles held cards into discard",fresh.phase=="combat" and #fresh.discard==3 and #fresh.zones[1].cards==0)
local view=Battle.View(fresh)
check("Private deck and seed never enter client snapshot",view.deck==nil and view.random==nil and view.config==nil)
local win=Battle.New(defaults,555,"sharp","win");win.zones[1]=zone({card("A","♠"),card("A","♥"),card("8","♦")})
check("Winning attack accepted",Battle.Play(win))
check("Enemy dies before counterattack",win.phase=="won" and win.hp==defaults.PlayerHP)
check("Cannot attack after victory",not Battle.Play(win))
return {passed=#checks,checks=checks}
