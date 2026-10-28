/* Feedback never changes game state or consumes gameplay randomness. */
function purchaseFeedback(index, name, price) {
 const offer = document.querySelector('[data-offer="'+index+'"]');
 if (offer) offer.classList.add('purchase-flash');
 document.querySelectorAll('.purchase-toast').forEach(el => el.remove());
 const message = document.createElement('div');
 message.className = 'toast purchase-toast';
 message.setAttribute('role', 'status');
 message.textContent = '✓ ' + name + ' · −$' + price;
 document.body.appendChild(message);
 setTimeout(() => message.remove(), 3000);
}

// Animate native details in both directions, retaining keyboard interaction.
document.addEventListener('click', event => {
 const summary = event.target.closest('.brief-help > summary');
 if (!summary || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
 event.preventDefault();
 const details = summary.parentElement;
 const start = details.getBoundingClientRect().height;
 const opening = details._opening === undefined ? !details.open : !details._opening;
 details._opening = opening;
 details._animation?.cancel();
 details.open = true;
 const end = opening ? details.scrollHeight : summary.getBoundingClientRect().height + parseFloat(getComputedStyle(details).paddingTop) + parseFloat(getComputedStyle(details).paddingBottom) + 1;
 const animation = details.animate([{height:start+'px'},{height:end+'px'}], {duration:240,easing:'ease-in-out'});
 details._animation = animation;
 animation.onfinish = () => {details.open = opening;delete details._opening;delete details._animation;};
});

const dock = document.getElementById('dock');
if (dock && typeof ResizeObserver !== 'undefined') {
 new ResizeObserver(() => {
  const inset = parseFloat(getComputedStyle(dock).paddingBottom) || 0;
  document.body.style.setProperty('--game-dock-height', Math.ceil(dock.getBoundingClientRect().height - inset + 8)+'px');
 }).observe(dock);
}
