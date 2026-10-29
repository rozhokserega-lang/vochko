const assert=require('node:assert/strict');const {launch,load,writeReport}=require('./runtime.cjs');
(async()=>{const b=await launch();try{const p=await b.newPage();await load(p);const checks=await p.evaluate(()=>{
 const checks=[];const old=structuredClone(META);META.shop=defaultShop();META.unlockAll=true;
 for(let seed=0;seed<100;seed++){resetTestRandom(seed+1);newGame(0,'alchemy');if(G.cons.length!==3||new Set(G.cons).size!==3||!G.cons.some(c=>['minus','pct'].includes(c.kind))||G.money!==CONFIG.startMoney-2)throw Error('Alchemy seed '+seed);}
 checks.push('100 alchemy seeds: 3 distinct items, guaranteed cut, unchanged cash penalty');
 newGame(0,'classic');G.bargains=['velvet'];const item=buildShopItems().find(it=>it.kind==='cons');if(item.price!==CONS[item.key].price+1)throw Error('Velvet surcharge');checks.push('Velvet surcharge exactly 1');G.bargains=[];const reward=baseReward();G.bargains=['pockets'];if(baseReward()!==Math.max(0,reward-1))throw Error('Pockets reward');checks.push('Pockets penalty exactly 1');
 META=old;metaSave();return checks;
});writeReport('balance-patch.json',{checks});console.log(checks.join('\n'));}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
