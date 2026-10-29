/* No polling: wake only on app visibility changes. */
const MOBILE_FX = matchMedia('(pointer:coarse), (max-width:700px)').matches;
function updatePerformanceVisibility(){
  document.documentElement.classList.toggle('game-backgrounded',document.hidden);
}
document.addEventListener('visibilitychange',updatePerformanceVisibility);
updatePerformanceVisibility();
