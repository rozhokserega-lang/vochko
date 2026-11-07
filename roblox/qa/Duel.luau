local Duel=require(game.ServerStorage.VochkoPrototype.Duel)
local Battle=require(game.ServerStorage.VochkoPrototype.Battle)
local config=require(game.ServerStorage.VochkoPrototype.Config).ForBattle()
local count=0
local function check(value,name)assert(value,name);count+=1 end
local function unique(side)
 local ids,total={},0
 for _,list in {side.deck,side.discard}do for _,card in list do check(not ids[card.id],'No duplicate in deck/discard');ids[card.id]=true;total+=1 end end
 for _,z in side.zones do for _,card in z.cards do check(not ids[card.id],'No duplicate on table');ids[card.id]=true;total+=1 end end
 check(total==52,'All 52 cards accounted for')
end
local function pack(cards)return {cards=cards,delta=0,chipDelta=0,stood=false}end
local deck=Battle.Deck()
local function card(rank,suit)for _,c in deck do if c.rank==rank and c.suit==suit then return table.clone(c)end end end
local exact=pack({card('A','♠'),card('8','♥'),card('2','♦')})
local sample=Duel.New(config,777,'sharp','qa')
check(not Duel.Play(sample),'Cannot play intro')
check(Duel.Begin(sample),'Begin accepted')
check(not Duel.Begin(sample),'Cannot plan bot twice')
check(#sample.player.deck==52,'Bot leaves player deck alone')
check(not sample.botReady and #sample.bot.deck==52,'Bot begins with empty table')
check(Duel.StepBot(sample),'One visible bot step')
check(#sample.bot.deck==51,'First step draws exactly one card')
check(not Duel.Play(sample),'Cannot resolve while bot is thinking')
local function finishBot(state)
 local guard=0
 while not state.botReady do guard+=1;check(guard<100,'Bot always finishes');Duel.StepBot(state)end
end
finishBot(sample)
local view=Duel.View(sample)
check(view.mode=='duel' and view.enemyHp==100 and view.maxHp==100,'Fair duel HP')
check(view.roundsTotal==10 and view.target==21 and view.slots==4,'Configured format')
check(view.deck==nil and view.bot==nil,'No private deck in snapshot')
for _,z in view.duel.enemyZones do
 check(z.result~=nil,'Live sum is public')
 for _,c in z.cards do check(not c.hidden and c.rank~=nil and c.suit~=nil,'Opponent faces visible during draw')end
end
local ids={}for _,c in exact.cards do ids[c.id]=true end
for i=#sample.player.deck,1,-1 do if ids[sample.player.deck[i].id]then table.remove(sample.player.deck,i)end end
sample.player.zones[1]=exact
check(Duel.Evaluate(sample.player).damage==9,'Exact sharp zone uses PvP damage scale')
local playerHp,botHp=sample.player.hp,sample.bot.hp
check(Duel.Play(sample),'Resolve duel')
check(not Duel.Play(sample),'No duplicate round resolution')
check(sample.roundsLeft==9,'Exactly one round spent')
local sum=0 for _,hit in sample.receipt.hits do sum+=hit.damage end
check(sum==sample.receipt.enemyBefore-sample.bot.hp,'Outgoing shares equal actual loss')
sum=0 for _,hit in sample.receipt.incoming.hits do sum+=hit.damage end
check(sum==sample.receipt.incoming.enemyBefore-sample.player.hp,'Incoming shares equal actual loss')
view=Duel.View(sample)
check(view.duel.revealed,'Opponent cards revealed after confirmation')
check(view.duel.enemyZones[1].cards[1].rank~=nil,'Opponent faces visible when revealed')
Duel.Next(sample);check(sample.round==2 and sample.phase=='combat','Next round starts')
check(sample.config.Target==22 and sample.player.config.Target==22 and sample.bot.config.Target==22,'Target increases for both sides')
Duel.Next(sample);check(sample.config.Target==22,'Cannot increase target twice in same round')
check(#sample.player.discard==3,'Player cards recycled')
unique(sample.player);unique(sample.bot)
-- Simultaneous knockout remains a draw; there is no first-attacker advantage.
local tie=Duel.New(config,12,'sharp','tie');Duel.Begin(tie);finishBot(tie)
tie.player.zones={exact,pack({}),pack({})};tie.bot.zones={exact,pack({}),pack({})};tie.player.hp=1;tie.bot.hp=1
check(Duel.Play(tie) and tie.phase=='draw','Simultaneous lethal is a draw')
local c=table.clone(config);c.DuelRounds=1
local last=Duel.New(c,33,'sharp','last');Duel.Begin(last);finishBot(last)
last.player.zones={exact,pack({}),pack({})};last.bot.zones={pack({card('2','♠')}),pack({}),pack({})}
check(Duel.Play(last) and last.phase=='won','Final-round HP determines winner')
local red=Duel.New(config,22,'healer','heal');red.player.zones[1]=pack({card('2','♥'),card('3','♦'),card('4','♥')})
check(Duel.Evaluate(red.player).heal==3,'Healing adapted to duel scale')
-- Full seeded matches exercise AI, reshuffling, termination and isolation.
local outcomes={won=0,lost=0,draw=0}
for seed=1,24 do
 local s=Duel.New(config,seed,'sharp','run-'..seed);Duel.Begin(s)
 for round=1,config.DuelRounds do
  local guard=0
  while Battle.Active(s.player)and guard<80 do
   guard+=1;local index=Battle.Active(s.player);local r=Battle.Zone(s.player.zones[index],s.player.config.Target)
   if r.sum<s.player.config.Target-3 then Duel.Draw(s)else Duel.Stop(s)end
  end
  unique(s.player);unique(s.bot)
  finishBot(s)
  check(Duel.Play(s),'Every test round resolves')
  if s.phase~='resolving'then break end
  Duel.Next(s)
 end
 check(s.phase=='won'or s.phase=='lost'or s.phase=='draw','Match always terminates')
 outcomes[s.phase]+=1
 check(s.round<=config.DuelRounds,'Round cap respected')
end
return {passed=count,outcomes=outcomes}
