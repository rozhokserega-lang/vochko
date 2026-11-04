-- Isolated rule checks: damage shares must match authoritative health loss.
local Battle=require(game.ServerStorage.VochkoPrototype.Battle)
local config=require(game.ServerStorage.VochkoPrototype.Config).ForBattle()
config.Target=30
local deck=Battle.Deck()
local passed=0
local function check(value,name)assert(value,name);passed+=1 end
local function card(rank,suit)
 for _,c in deck do if c.rank==rank and c.suit==suit then return table.clone(c)end end
 error('missing card')
end
local function zone(cards)return {cards=cards,delta=0,chipDelta=0,stood=false}end
for _,talent in {'sharp','healer','daring'} do
 for _,hp in {1,100,2400,50000} do
  local state=Battle.New(config,123,talent,'impact-qa')
  state.enemyHp=hp
  state.zones[1]=zone({card('A','♠'),card('A','♥'),card('8','♦')})
  state.zones[2]=zone({card('K','♣'),card('Q','♣'),card('5','♣')})
  state.zones[3]=zone({card('10','♥'),card('J','♦'),card('Q','♥'),card('2','♦')})
  check(Battle.Play(state),'play accepted')
  local sum=0;local ids={}
  for _,hit in state.receipt.hits do
   sum+=hit.damage
   check(hit.damage>=0 and hit.damage%1==0,'nonnegative integer impact')
   check(not ids[hit.card.id],'each card impacts once');ids[hit.card.id]=true
   check(hit.zone~=3,'busted zone does not attack')
  end
  check(#state.receipt.hits==6,'all six valid cards fly')
  check(sum==hp-state.enemyHp,'impact sum equals real HP loss including overkill')
  check(state.receipt.enemyBefore==hp and state.receipt.enemyAfter==state.enemyHp,'HP endpoints exact')
  check(not Battle.Play(state),'no second hit for same turn')
 end
end
local busted=Battle.New(config,7,'sharp','all-bust')
busted.zones[1]=zone({card('K','♠'),card('Q','♥'),card('J','♣'),card('2','♦')})
local hp=busted.enemyHp
check(Battle.Play(busted),'zero-damage play accepted')
check(#busted.receipt.hits==0 and busted.enemyHp==hp,'no projectiles or damage for all-bust')
return {passed=passed}
