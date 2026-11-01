/* A fresh endless run is independent of chapters and legacy post-victory runs. */
const Endless={
 setup(){SETUP.mode='endless';SETUP.chapter=0;GameMenu.setup();},
 round(game=G){return (game.stats?.blinds||0)+1;},
 label(game=G){return 'Бесконечный забег · бой '+this.round(game);},
 target(){return Math.round(1800*Math.pow(1.14,Math.min(200,G.stats.blinds||0))*(G.blind===2?1.3:1));},
 record(){if(!G.endlessFromStart)return;const next={battles:G.stats.blinds,points:G.runPoints||0,bestSeat:G.stats.bestSeat,deck:G.deckKey,talent:G.talent,date:new Date().toISOString()};const old=META.endlessRecord;if(!old||next.battles>old.battles||next.battles===old.battles&&next.points>old.points)META.endlessRecord=next;metaSave();},
 renderHUD(){if(!G.endlessFromStart)return;$('#hud-ante').closest('.pill').querySelector('.label').textContent='Бой';$('#hud-ante').textContent=this.round();$('#hud-blind').closest('.pill').querySelector('.label').textContent='Режим';$('#hud-blind').textContent='Бесконечный';},
 loss(){const best=META.endlessRecord?.battles||0;showOverlay('<div class="kicker">Бесконечный забег · бой '+this.round()+'</div><h2>До следующей попытки</h2><p class="sub">'+(G.lossReason||'Противник оказался сильнее.')+'</p>'+lossReviewHTML()+'<div class="stat-line"><span>Врагов побеждено</span><b>'+G.stats.blinds+'</b></div><div class="stat-line"><span>Личный рекорд</span><b>'+best+'</b></div><div class="stat-line"><span>Очки за забег</span><b>'+fmt(G.runPoints||0)+'</b></div><div class="stat-line"><span>Лучший ход</span><b>'+fmt(G.stats.bestSeat)+'</b></div>'+coinSummaryHTML()+'<div class="row-btns"><button class="primary" id="endless-retry">Ещё попытка</button><button class="ghost" id="endless-home">Главное меню</button></div>');$('#endless-retry').onclick=()=>this.setup();$('#endless-home').onclick=()=>newGame();}
};
