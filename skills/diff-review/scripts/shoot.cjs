#!/usr/bin/env node
/* Screenshot one URL (or one element) with Playwright, resolved from the target repo.
 *
 * node shoot.cjs --url URL --out FILE.png [--width 390] [--height 780] [--wait 1500]
 *                [--click "role:button:Pick a date" | --click "css:.open-menu"]... [--selector CSS] [--full] [--scheme dark|light]
 *
 * Run it from inside the repo being reviewed so the repo's own Playwright is found.
 * Falls back to a pnpm store copy, then to a global install.
 */
const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const argv = process.argv.slice(2);
const opt = { click: [] };
for (let i = 0; i < argv.length; i++) {
  const k = argv[i];
  if (!k.startsWith('--')) continue;
  const key = k.slice(2);
  if (key === 'full') opt.full = true;
  else if (key === 'click') opt.click.push(argv[++i]);
  else opt[key] = argv[++i];
}
if (!opt.url || !opt.out) {
  console.error('usage: shoot.cjs --url URL --out FILE.png [--width N] [--height N] [--wait ms] [--click role:button:Name]... [--selector CSS] [--full]');
  process.exit(2);
}

function loadPlaywright() {
  const here = createRequire(path.join(process.cwd(), 'noop.js'));
  for (const name of ['playwright', '@playwright/test', 'playwright-core']) {
    try { return here(name); } catch {}
  }
  const store = path.join(process.cwd(), 'node_modules', '.pnpm');
  if (fs.existsSync(store)) {
    const dir = fs.readdirSync(store).find((d) => /^playwright@/.test(d));
    if (dir) return require(path.join(store, dir, 'node_modules', 'playwright'));
  }
  console.error('Playwright not found. Install it where it will not touch the repo:\n  npm i --no-save playwright && npx playwright install chromium\n(or run from a repo that already depends on it)');
  process.exit(3);
}

(async () => {
  const { chromium } = loadPlaywright();
  let browser;
  try {
    browser = await chromium.launch();
  } catch (err) {
    console.error('Chromium would not start. Run: npx playwright install chromium\n' + String(err).split('\n')[0]);
    process.exit(4);
  }
  const page = await browser.newPage({
    viewport: { width: Number(opt.width || 390), height: Number(opt.height || 780) },
    deviceScaleFactor: 1,
    colorScheme: opt.scheme === 'dark' ? 'dark' : 'light',
  });
  await page.goto(opt.url, { waitUntil: 'load' });
  await page.waitForTimeout(Number(opt.wait || 1500));
  for (const c of opt.click) {
    const [kind, ...rest] = c.split(':');
    if (kind === 'role') {
      const [role, ...name] = rest;
      await page.getByRole(role, { name: name.join(':'), exact: true }).click();
    } else if (kind === 'css') {
      await page.locator(rest.join(':')).click();
    } else {
      console.error(`bad --click "${c}" (use role:<role>:<name> or css:<selector>)`);
      process.exit(2);
    }
    await page.waitForTimeout(800);
  }
  fs.mkdirSync(path.dirname(path.resolve(opt.out)), { recursive: true });
  if (opt.selector) await page.locator(opt.selector).first().screenshot({ path: opt.out });
  else await page.screenshot({ path: opt.out, fullPage: !!opt.full });
  await browser.close();
  console.log(`${opt.out} ${fs.statSync(opt.out).size} bytes`);
})();
