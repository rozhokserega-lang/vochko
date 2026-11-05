-- Functional build/armor checks and complete training matches in Studio server.
local S=game.ServerStorage.VochkoPrototype
local B,D,C=require(S.Battle),require(S.Duel),require(S.Config)
local L=require(game.ReplicatedStorage.VochkoPrototype.Loadout)
local T=require(game.ReplicatedStorage.VochkoPrototype.Tarot)
local checks=0
local function check(ok,why)assert(ok,why);checks+=1 end
check(L.Validate('sharp',{'crimson','blot'},{'rose','guardian','sun'}),'Valid build')
check(not L.Validate('daring',{'crimson','blot'},{'rose','guardian','sun'}),'Unknown PvP class rejected')
check(not L.Validate('sharp',{'crimson','crimson'},{'rose','guardian','sun'}),'Duplicate jokers rejected')
check(not L.Validate('sharp',{'crimson'},{'rose','guardian','sun'}),'Incomplete joker selection rejected')
check(not L.Validate('sharp',{'crimson','blot'},{'rose','rose','sun'}),'Duplicate tarot rejected')
check(not L.Validate('sharp',{'crimson','blot'},{'rose','thread','sun'}),'Sleeve tarot excluded')
local deck=B.Deck()
local function zone(cards)return {cards=cards,delta=0,chipDelta=0,stood=false}end
local clock={id='clock',tarot='hourglass',value=0}
check(B.Zone(zone({deck[1],clock}),21,true).sum==2,'PvP clock cannot turn 2 into 21')
check(B.Zone(zone({deck[8],deck[9],clock}),21,true).sum==21,'PvP clock corrects 19 to 21')
check(B.Zone(zone({deck[1],clock}),21).sum==21,'Campaign clock preserved')
local a={damage=8,exact=true,bust=false};T.Boost(zone({{tarot='echo'}}),a,true);check(a.damage==12,'PvP echo is +50 percent')
local c=C.ForBattle();local state=D.New(c,42,'guardian','armor-test',{'guardian','rose','sun'},{'guardian','rose','sun'},{'triple','blot'},{class='guardian',jokers={'triple','blot'}})
local original={'triple','blot'};local frozen=D.New(c,10,'sharp','copy',{'rose','guardian','sun'},nil,original);original[1]='ladder';check(frozen.player.jokers[1]=='triple','Build is copied')
for _,side in {state.player,state.bot}do side.zones={zone({deck[9],deck[13],{id='shield',tarot='guardian',value=0}}),zone({}),zone({})}end
state.phase='combat';state.botReady=true
local before=D.View(state);check(before.armor==8 and before.enemyArmor==8,'Tarot armor stacks with class armor')
local rawA=D.Evaluate(state.player).damage;local rawB=D.Evaluate(state.bot).damage
check(D.Play(state),'Armor exchange plays')
check(state.receipt.ownBlocked==math.min(rawB,8),'Player armor absorbs once')
check(state.receipt.enemyBlocked==math.min(rawA,8),'Opponent armor absorbs once')
check(state.player.hp==100-math.max(0,rawB-8),'Armor prevents exactly the expected HP loss')
check(not D.Play(state),'Duplicate play rejected')
D.Next(state);check(D.View(state).armor==0,'Armor expires at the next round')
local restore=B.New(c,2,'sharp','restore');restore.supplies.minus4=0
T.Commit(restore,{money=0,restoreCut=true});check(restore.supplies.minus4==1 and restore.money==0,'PvP coin restores a spent cut, no money')
local scan=D.New(c,7,'sharp','scan',{'rose','guardian','sun'},nil,{'xray','triple'});D.Begin(scan)
local hidden=scan.player.deck[#scan.player.deck].id
check(D.Consume(scan,'scan'),'Scanner can reveal once')
check(D.View(scan).peek[1].id==hidden and scan.player.scanCharges==1,'Only the real next card is revealed')
check(not D.Consume(scan,'scan'),'Same reveal cannot spend another charge')
check(D.Draw(scan),'Revealed card can be drawn');check(scan.player.scanCard==nil,'Reveal clears after draw')
local games,wins,losses,draws,roundTotal=0,0,0,0,0
local minHp,maxHp=100,0
for _,class in L.Classes do for i=1,#L.Jokers-1 do for j=i+1,#L.Jokers do
 local seed=1000+games*97
 local gameState=D.New(c,seed,class.id,'game-'..games,D.ChooseTarot(seed),D.ChooseTarot(seed+1),{L.Jokers[i].id,L.Jokers[j].id})
 D.Begin(gameState)
 for turn=1,8 do
  D.PlanBot(gameState.player);D.PlanBot(gameState.bot);gameState.botReady=true
  local prev=gameState.roundsLeft
  check(D.Play(gameState),'Full-match turn accepted');check(gameState.roundsLeft==prev-1,'One turn spent')
  check(gameState.player.hp>=0 and gameState.player.hp<=100 and gameState.bot.hp>=0 and gameState.bot.hp<=100,'HP bounds')
  check(gameState.receipt.ownBlocked>=0 and gameState.receipt.enemyBlocked>=0,'Armor never negative')
  if gameState.phase~='resolving'then break end;D.Next(gameState)
 end
 check(gameState.phase=='won'or gameState.phase=='lost'or gameState.phase=='draw','Match terminates')
 games+=1;roundTotal+=gameState.round
 if gameState.phase=='won'then wins+=1 elseif gameState.phase=='lost'then losses+=1 else draws+=1 end
 minHp=math.min(minHp,gameState.player.hp);maxHp=math.max(maxHp,gameState.player.hp)
 if games%5==0 then task.wait()end
end end end
return {checks=checks,games=games,wins=wins,losses=losses,draws=draws,averageRounds=roundTotal/games,playerHpRange={minHp,maxHp},note='Functional bot matches, not a claim of human PvP balance'}
