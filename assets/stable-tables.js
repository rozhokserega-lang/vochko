/* Стопка карт на столе всегда помещается в свой блок.
   Раньше при 4–5 картах нижняя карта вылезала за блок и налезала на строку бонуса
   и подпись стола. Теперь шаг стопки уменьшается ровно настолько, чтобы все карты
   уместились; при 1–3 картах вид не меняется. Только оформление, без игровой логики. */
(function(){
  'use strict';
  var MIN_STEP=13; // столько пикселей карты должно быть видно, чтобы читался ранг
  function fit(){
    var boxes=document.querySelectorAll('#table .t-cards');
    for(var b=0;b<boxes.length;b++){
      var box=boxes[b], cards=[];
      for(var i=0;i<box.children.length;i++){
        var el=box.children[i];
        if(el.classList&&el.classList.contains('card'))cards.push(el);
      }
      if(cards.length<2)continue;
      for(i=1;i<cards.length;i++)cards[i].style.marginTop='';
      var cs=getComputedStyle(box);
      var room=box.clientHeight-(parseFloat(cs.paddingTop)||0)-(parseFloat(cs.paddingBottom)||0);
      var ch=cards[0].offsetHeight;
      if(!room||!ch)continue;
      var base=ch+(parseFloat(getComputedStyle(cards[1]).marginTop)||0);
      var fitStep=(room-ch)/(cards.length-1);
      if(fitStep>=base)continue;
      var step=Math.max(fitStep,Math.min(base,MIN_STEP));
      for(i=1;i<cards.length;i++)cards[i].style.marginTop=(step-ch)+'px';
    }
  }
  function start(){
    var root=document.querySelector('#table')||document.body;
    new MutationObserver(fit).observe(root,{childList:true,subtree:true});
    window.addEventListener('resize',fit);
    window.addEventListener('orientationchange',fit);
    if(window.visualViewport)window.visualViewport.addEventListener('resize',fit);
    fit();
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start);else start();
})();
