/* Run-scoped, optional for legacy saves and daily challenges. */
const TALENTS={
 healer:{name:'Лекарь',mark:'♥',desc:'Красные столы восстанавливают на 50% больше HP. Усиливает только лечение от карт.',hint:'Собирай 3–4 красные карты на одном столе.'},
 sharp:{name:'Картёжник',mark:'♠',desc:'Каждый стол с точной суммой наносит на 15% больше урона.',hint:'Доводи суммы до цели срезами и усилителями.'},
 daring:{name:'Авантюрист',mark:'♦',desc:'Если перебрал ровно один стол, общий урон хода увеличивается на 30%. Штраф за перебор остаётся.',hint:'Рискни одним столом, сохрани остальные.'}
};
function activeTalent(){return TALENTS[G?.talent]||null;}
function talentSummary(){const t=activeTalent();return t?'<details class="run-talent"><summary>'+t.mark+' Талант: '+t.name+'</summary><p>'+t.desc+'</p><small>'+t.hint+'</small></details>':'';}
