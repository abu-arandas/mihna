// Cuts every app icon from the two drawings in this folder, so a rebrand changes two SVG files and runs:
//
//   node tool/brand/make_icons.mjs
//
// from the project root. mark.svg (transparent, the button alone) is used where nothing crops the icon: the browser
// tab, the installed web app, the Android launcher and Windows. app_icon.svg (full-bleed square, the mark inside the
// middle two thirds) is used where the system cuts its own shape: iPhone and iPad, and Android's "maskable" web icons.
// Needs Node and Playwright's Chromium (npx playwright install chromium); nothing it makes ships in the app's code.
import { createRequire } from 'node:module';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const { chromium } = createRequire(import.meta.url)('playwright');
const here = dirname(new URL(import.meta.url).pathname);
const mark = readFileSync(join(here, 'mark.svg'), 'utf8');
const tile = readFileSync(join(here, 'app_icon.svg'), 'utf8');

const browser = await chromium.launch();
const page = await browser.newPage();
async function png(svg, size, transparent) {
  await page.setViewportSize({ width: size, height: size });
  const sized = svg.replace('<svg ', `<svg width="${size}" height="${size}" `);
  await page.setContent(`<html><body style="margin:0;background:transparent">${sized}</body></html>`);
  return page.screenshot({ omitBackground: transparent, clip: { x: 0, y: 0, width: size, height: size } });
}
function save(path, data) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, data);
  console.log('Wrote', path);
}

// Web: tab icon, installed app, and the home-screen icon on iPhones.
save('web/favicon.svg', mark);
save('web/favicon.png', await png(mark, 32, true));
save('web/icons/Icon-192.png', await png(mark, 192, true));
save('web/icons/Icon-512.png', await png(mark, 512, true));
save('web/icons/Icon-maskable-192.png', await png(tile, 192, false));
save('web/icons/Icon-maskable-512.png', await png(tile, 512, false));
save('web/icons/apple-touch-icon.png', await png(tile, 180, false));

// Android launcher.
for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
  save(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`, await png(mark, size, true));
}

// iPhone and iPad: every file the asset catalogue lists, with no transparency.
const set = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
for (const image of JSON.parse(readFileSync(join(set, 'Contents.json'), 'utf8')).images) {
  if (!image.filename) continue;
  const size = Math.round(parseFloat(image.size) * parseInt(image.scale));
  save(join(set, image.filename), await png(tile, size, false));
}

// Windows: one .ico holding the sizes Explorer and the taskbar pick from (PNG inside, which Windows Vista on reads).
const sizes = [16, 24, 32, 48, 64, 256];
const images = [];
for (const size of sizes) images.push(await png(mark, size, true));
const header = Buffer.alloc(6 + 16 * sizes.length);
header.writeUInt16LE(0, 0);
header.writeUInt16LE(1, 2);
header.writeUInt16LE(sizes.length, 4);
let offset = header.length;
sizes.forEach((size, i) => {
  const at = 6 + 16 * i;
  header.writeUInt8(size >= 256 ? 0 : size, at);
  header.writeUInt8(size >= 256 ? 0 : size, at + 1);
  header.writeUInt16LE(1, at + 4);
  header.writeUInt16LE(32, at + 6);
  header.writeUInt32LE(images[i].length, at + 8);
  header.writeUInt32LE(offset, at + 12);
  offset += images[i].length;
});
if (existsSync("windows")) save("windows/runner/resources/app_icon.ico", Buffer.concat([header, ...images]));

await browser.close();
