const assert = require('node:assert/strict');
const { launch, load } = require('./runtime.cjs');

(async () => {
  const browser = await launch();
  try {
    for (const height of [568, 844]) {
      const page = await browser.newPage({ viewport: { width: 390, height }, hasTouch: true });
      await load(page);
      await page.evaluate(() => {
        newGame(0, 'classic', { campaign: true });
        // Ensure the page behind the briefing has somewhere to scroll.
        document.querySelector('main').style.minHeight = '2000px';
        startBlind();
      });
      const hudTop = await page.locator('#hud').evaluate(el => el.getBoundingClientRect().top);
      const modal = page.locator('.passage-modal');
      const box = await modal.boundingBox();
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.wheel(0, 2000);
      await page.waitForTimeout(250);
      const scroll = await modal.evaluate(el => ({ top: el.scrollTop, max: el.scrollHeight - el.clientHeight }));
      if (scroll.max > 0) assert(scroll.top > 0, 'Briefing content must remain scrollable');
      await page.mouse.wheel(0, 2000);
      await page.waitForTimeout(250);
      assert.equal(await page.evaluate(() => window.scrollY), 0, 'Scroll must not reach the background');
      assert.equal(await page.locator('#hud').evaluate(el => el.getBoundingClientRect().top), hudTop);
      await page.evaluate(() => hideOverlay());
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(250);
      assert(await page.evaluate(() => window.scrollY > 0), 'Page scrolling must resume after closing');
      await page.close();
    }
    console.log('Overlay scroll isolation passed at 390×568 and 390×844');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
