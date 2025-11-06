const puppeteer = require('puppeteer');

async function main() {
  const url = process.argv[2] ?? 'https://maromsa.github.io/english_learning_app/';
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const page = await browser.newPage();

  page.on('console', (msg) => {
    console.log('[console]', msg.type(), msg.text());
  });

  page.on('pageerror', (err) => {
    console.error('[pageerror]', err);
  });

  page.on('requestfailed', (req) => {
    console.error('[requestfailed]', req.url(), req.failure()?.errorText);
  });

  const interestingRequests = [];
  const assetStatus = new Map();
  page.on('requestfinished', (req) => {
    const url = req.url();
      if (url.includes('assets/assets/images/words/') || url.includes('assets/images/words/')) {
        interestingRequests.push(url);
        try {
          assetStatus.set(url, req.response()?.status());
        } catch (err) {
          assetStatus.set(url, 'unknown');
        }
      }
  });

  await page.goto(url, { waitUntil: 'networkidle2', timeout: 120_000 });

  // Wait for Flutter to bootstrap (glass pane element appears once the engine is ready).
  try {
    await page.waitForSelector('flt-glass-pane', { timeout: 60_000 });
  } catch (err) {
    console.warn('[warn] flt-glass-pane not found within timeout');
  }

  // Allow a bit more time for widgets to render.
  await new Promise((resolve) => setTimeout(resolve, 10_000));

  // Try to dismiss the onboarding dialog (button near bottom center).
  await page.mouse.move(400, 560);
  await page.mouse.click(400, 560);
  await new Promise((resolve) => setTimeout(resolve, 2_000));

  // Try to tap the first level on the map (roughly center-bottom area).
  await page.mouse.move(500, 480);
  await page.mouse.click(500, 480);
  await new Promise((resolve) => setTimeout(resolve, 2_000));

  // Confirm level start button if visible (bottom center again).
  await page.mouse.move(400, 560);
  await page.mouse.click(400, 560);
  await new Promise((resolve) => setTimeout(resolve, 5_000));

    const result = await page.evaluate(() => {
      const canvases = Array.from(document.querySelectorAll('flt-canvas'));
    const imgs = Array.from(document.querySelectorAll('img'));
      const textSample = document.body.innerText.slice(0, 200);
    return {
      canvasCount: canvases.length,
      imgSources: imgs.map((el) => el.getAttribute('src')),
        textSample,
    };
  });

  console.log('[evaluate]', JSON.stringify(result, null, 2));
    console.log('[assetRequests]', interestingRequests);
    console.log('[assetStatus]', Object.fromEntries(assetStatus));

  await page.screenshot({ path: 'debug-screenshot.png', fullPage: true });

  await browser.close();
  console.log('[info] Screenshot saved to debug-screenshot.png');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
