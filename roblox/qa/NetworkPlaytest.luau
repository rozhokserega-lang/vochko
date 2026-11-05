-- Server-side functional sessions with two independent participants and clock.
local S=game.ServerStorage.VochkoPrototype
local Net,C=require(S.NetworkDuel),require(S.Config)
local checks=0
local function check(value,message)assert(value,message);checks+=1 end
local function participant(name)
 return {DisplayName=name,Parent=true,Character={FindFirstChildOfClass=function()return {Health=100}end}}
end
local now=0;local a,b,c=participant('A'),participant('B'),participant('C')
local build={class='sharp',jokers={'crimson','blot'},duelTarot={'rose','guardian','sun'}}
local net=Net.new({profile=function()return build end,push=function()end,config=function()return table.clone(C.Defaults)end,id=function()return 'network-functional'end,now=function()return now end,sit=function()return true end,leave=function()end})
check(net:Join(a,2),'First player can choose far chair')
check(net:View(a).screen=='pvpwait','First player waits')
check(not net:Join(c,2),'Occupied chair rejects another player')
check(net:Join(b,1),'Second player can choose near chair')
check(net:View(a).battle.phase=='countdown','Countdown begins')
check(not net:Join(c,1),'Third participant rejected')
now=4;net:Tick()
check(net:View(a).battle.phase=='combat','Countdown reaches combat')
check(net:View(a).battle.seatIndex==2 and net:View(b).battle.seatIndex==1,'Sides preserved')
local id=net.match.state.id
net:Action(a,{kind='draw',sessionId='stale'})
check(#net.match.state.bot.zones[1].cards==0,'Stale session cannot draw')
net:Action(a,{kind='draw',sessionId=id})
check(#net.match.state.bot.zones[1].cards==1,'Far-side input modifies far-side cards')
check(#net.match.state.player.zones[1].cards==0,'Other side unchanged')
net:Action(a,{kind='play',sessionId=id})
net:Action(a,{kind='draw',sessionId=id})
check(#net.match.state.bot.zones[1].cards==1,'Confirmed cards locked')
check(net:View(b).battle.duel.enemyReady,'Ready status replicated')
net:Action(b,{kind='draw',sessionId=id});net:Action(b,{kind='play',sessionId=id})
check(net.match.state.phase=='resolving','Both ready resolve shared round')
local av,bv=net:View(a).battle,net:View(b).battle
check(av.hp==bv.enemyHp and bv.hp==av.enemyHp,'HP perspectives mirror')
check(av.receipt.damage==bv.receipt.received,'Damage receipt mirrors')
check(av.receipt.enemyAfter==bv.receipt.incoming.enemyAfter,'Animation receipt mirrors')
check(av.deck==nil and av.duel.deck==nil and av.duel.peek==nil,'Opponent future cards not exposed')
now+=10;net:Tick();check(net.match.state.round==2,'Next round shared')
-- Empty hands are valid at timeout; must finish without assertions or deadlock.
local rounds=0
while not net.match.finished and rounds<20 do now+=200;net:Tick();rounds+=1 end
check(net.match.finished,'Timeouts complete full match')
check(net:View(a).battle.phase=='draw'or net:View(a).battle.phase=='won'or net:View(a).battle.phase=='lost','Terminal view')
net:Leave(a);net:Leave(b);check(net.match==nil,'Table freed after both leave')
check(net:Join(a,1),'Near chair can be chosen next match');check(net:Join(b,2),'Far chair can be chosen next match')
now+=4;net:Tick();net:Leave(a)
check(net:View(b).battle.phase=='won','Opponent wins on departure')
net:Leave(b);check(net.match==nil and not next(net.members),'Departure cleanup')
check(net:Join(a,2),'Waiting chair reusable');net:Leave(a);check(not next(net.members),'Waiting can be cancelled')
check(net:Join(a,2)and net:Join(b,1),'Countdown can restart');net:Leave(b)
check(net:View(a).screen=='pvpwait','Leaving during countdown returns other player to waiting')
net:Leave(a)
local concurrent=Net.new({profile=function()return build end,push=function()end,config=function()return table.clone(C.Defaults)end,id=function()return 'concurrent-seating'end,now=function()return now end,sit=function()task.wait(.05);return true end,leave=function()end})
local joined1,joined2
task.spawn(function()joined1=concurrent:Join(a,1)end)
task.spawn(function()joined2=concurrent:Join(b,2)end)
task.wait(.2)
check(joined1 and joined2 and concurrent.match~=nil,'Simultaneous seating reserves both chairs safely')
local profiles={}
for _,p in {a,b}do profiles[p]={class='sharp',jokers={'crimson','blot'},duelTarot={'rose','guardian','sun'}}end
local editing=Net.new({profile=function(p)return profiles[p]end,push=function()end,config=function()return table.clone(C.Defaults)end,id=function()return 'seated-build'end,now=function()return now end,sit=function()return true end,leave=function()end})
check(editing:Join(a,1),'Sit before choosing build')
editing:Action(a,{kind='openBuild'});check(editing:View(a).screen=='pvpwardrobe','Open build while seated')
check(editing:Join(b,2)and editing.match==nil,'Friend arrival does not interrupt build selection')
editing:Action(a,{kind='buildClass',item='healer'})
editing:Action(a,{kind='buildTarot',item='rose'})
editing:Action(a,{kind='closeBuild'})
check(editing.match==nil and editing:View(a).screen=='pvpwait','Incomplete build can wait without starting')
editing:Action(a,{kind='openBuild'});editing:Action(a,{kind='buildTarot',item='rose'});editing:Action(a,{kind='closeBuild'})
check(editing.match and editing.match.state.player.talent=='healer','Latest seated build used in match')
editing:Action(a,{kind='buildClass',item='sharp'})
check(profiles[a].class=='healer','Countdown locks seated build')
return {checks=checks,fullMatches=1,sides='both',timeout=true,departure=true}
