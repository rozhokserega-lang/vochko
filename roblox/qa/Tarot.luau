local Battle=require(game.ServerStorage.VochkoPrototype.Battle)
local Duel=require(game.ServerStorage.VochkoPrototype.Duel)
local Tarot=require(game.ReplicatedStorage.VochkoPrototype.Tarot)
local config=require(game.ServerStorage.VochkoPrototype.Config).ForBattle()
local count=0
local function check(v,name)assert(v,name);count+=1 end
local deck=Battle.Deck()
local function c(rank,suit)for _,v in deck do if v.rank==rank and v.suit==suit then return table.clone(v)end end end
local function t(id)return {id='tarot-'..id,tarot=id,rank=Tarot.Def(id).name,suit='',value=0,red=false}end
local function z(cards)return {cards=cards,delta=0,chipDelta=0,stood=false}end
local function state()return Battle.New(config,42,'sharp','tarot-test')end
check(config.Target==21 and config.Slots==4,'Default target 21 and four slots')
check(#Tarot.List==12,'All original tarot definitions')
local p={wins=0,owned={},ach={}}
for _,def in Tarot.List do check(Tarot.Unlocked(p,def),'All tarot open for testing')end
p.wins=1;check(Tarot.Unlocked(p,Tarot.Def('moon')),'Campaign unlock')
p.owned.echo=true;p.ach.last=true
check(Tarot.Unlocked(p,Tarot.Def('echo'))and Tarot.Unlocked(p,Tarot.Def('hourglass')),'Purchased and achievement unlocks')
local s=Battle.New(config,20,'sharp','loadout',{'rose','rose','sun','guardian','moon','echo','bad'})
check(s.deckTotal==56 and #s.deck==56,'Four unique tarot limit')
local ids={}for _,card in s.deck do check(not ids[card.id],'Unique mixed deck');ids[card.id]=true end
local r=Battle.Zone(z({c('10','♠'),t('rose')}),21)
check(r.sum==10 and r.damage==Battle.Zone(z({c('10','♠')}),21).damage,'Tarot has zero points and chips')
s=state();s.zones[1]=z({c('K','♠'),c('Q','♥'),c('2','♦'),t('rose'),t('sun')})
r=Battle.Forecast(s);check(r.zones[1].bust and r.damage==0 and r.heal==0,'Bust cancels healing and boost')
s.zones[1]=z({c('K','♠'),c('Q','♥'),t('hourglass')})
r=Battle.Zone(s.zones[1],21);check(r.exact and not r.bust and r.sum==21,'Hourglass overrides bust')
check(Battle.Active(s)==1,'Hourglass table accepts more cards until capacity')
s.zones[1].cards[4]=t('sun');check(Battle.Active(s)==2,'Tarot takes a physical slot')
s=state();s.zones[1]=z({c('9','♠'),c('8','♥'),t('rose')});s.deck={t('tower')}
check(Battle.Draw(s),'Draw tower');check(#s.zones[1].cards==2 and #s.discard==2,'Tower keeps tarot and discards ordinary cards')
s=state();s.hp=30;s.zones[1]=z({c('2','♠'),t('rose'),t('coin'),t('guardian')})
check(Battle.Play(s),'Tarot round resolves');check(s.money==10 and s.receipt.heal==20 and s.receipt.received==0,'Campaign heal money and guard')
check(not Battle.Play(s)and s.money==10,'Cannot apply coin twice')
Battle.Next(s);check(#s.discard==1 and #s.tarotSpent==3,'Used tarot kept out of reshuffle until next battle')
s=state();s.zones[1]=z({c('2','♠')});check(Battle.Consume(s,'hide'),'Hide in sleeve')
check(#s.sleeve==1 and s.sleeveUsed==1 and #s.zones[1].cards==0,'Sleeve accounts for card')
check(Battle.Consume(s,'release'),'Release sleeve card')
s.zones[1]=z({c('2','♠'),t('thread'),t('candle')});Battle.Play(s)
check(s.sleeveUsed==0,'Thread restores sleeve use');Battle.Next(s)
check(#Battle.View(s).peek==3,'Candle reveals next three cards next round')
local d=Duel.New(config,43,'sharp','duel',{'rose','guardian','sun','echo'});Duel.Begin(d)
while not d.botReady do Duel.StepBot(d)end
check(d.player.deckTotal==56 and d.bot.deckTotal==56,'Equal mixed deck sizes')
d.player.zones={z({c('2','♠'),t('rose'),t('guardian')}),z({}),z({})}
r=Duel.Evaluate(d.player);check(r.heal==8 and r.tarot.shield==6,'PvP healing and guard scaled')
check(Tarot.Incoming(20,{seal=true,moon=false,shield=0},true)==10,'PvP seal halves instead of cancels')
d.player.zones[1]=z({c('A','♠'),c('K','♥'),t('sun'),t('echo')})
check(Duel.Evaluate(d.player).damage==25,'PvP exact sharp sun echo combination')
local limitConfig=table.clone(config);limitConfig.EnemyHP=1000000000;limitConfig.EnemyAttack=0;limitConfig.BustPenalty=0;limitConfig.Rounds=30
local limited=Battle.New(limitConfig,91,'sharp','limit',{'rose','sun','guardian','echo'})
local seen={};local tarotCount=0
for round=1,20 do
 while Battle.Active(limited)do
  local before=limited.tarotDrawn;Battle.Draw(limited)
  if limited.tarotDrawn>before then
   for _,zone in limited.zones do for _,card in zone.cards do if card.tarot and not seen[card.id]then seen[card.id]=true;tarotCount+=1 end end end
   check(limited.tarotDrawn==tarotCount,'No tarot can be drawn a second time')
  end
 end
 check(Battle.Play(limited),'Long battle plays');Battle.Next(limited)
 check(limited.tarotDrawn<=4,'Four tarot maximum per battle')
end
check(tarotCount==4 and #limited.tarotSpent==4,'All four tarot used once and retained')
local fresh=Battle.New(limitConfig,91,'sharp','next',{'rose','sun','guardian','echo'})
check(fresh.tarotDrawn==0 and #fresh.deck==56,'New battle restores full selected loadout')
local chosen=Duel.ChooseTarot(73);local set={}
for _,id in chosen do check(Tarot.Def(id)~=nil and not set[id],'AI chooses four distinct valid tarot');set[id]=true end
local independent=Duel.New(config,11,'sharp','different',{'rose'},chosen)
check(independent.player.deckTotal==53 and independent.bot.deckTotal==56,'Player and AI prepare separate loadouts')
local cut=state();cut.zones[1]=z({c('10','♠')})
check(Battle.Consume(cut,'minus4',1),'Minus four accepted')
check(Battle.Zone(cut.zones[1],21).sum==6 and cut.supplies.minus4==0 and cut.supplies.minus2==1,'Minus four changes four and leaves minus two untouched')
check(Battle.Consume(cut,'minus2',1)and Battle.Zone(cut.zones[1],21).sum==4,'Minus two changes two independently')
return {passed=count}
