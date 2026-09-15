// Rebuild the two review-only vector badges. Run from any working directory.
// Artwork coordinates follow the existing 1024 px PNGs. All shading is solid
// polygon geometry: no raster payload, filters, gradients, fonts, or resources.
import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const out = resolve(root, 'docs/streak-concepts/svg-pilot');
mkdirSync(out, { recursive: true });
const palette = {
  chassis: '#26282b', recess: '#111416', gold: '#df9b46', goldLight: '#ffe1a1',
  goldDark: '#88430e', edge: '#482809', ivory: '#ecdfbd', ivoryLight: '#fff3d3',
  ivoryDark: '#bb9963', blue: '#073c96', blueLight: '#397dcf', blueDark: '#03265f',
};
const fmt = v => Number(v.toFixed(2));
const polygon = (p, fill, attrs = '') => `<polygon points="${p.map(q => q.map(fmt).join(',')).join(' ')}" fill="${fill}" ${attrs}/>`;
const line = (p, color, width) => `<polyline points="${p.map(q => q.map(fmt).join(',')).join(' ')}" fill="none" stroke="${color}" stroke-width="${width}" stroke-linejoin="round"/>`;
const cross = (a, b) => a[0] * b[1] - a[1] * b[0];
function inset(p, amount) {
  const area = p.reduce((sum, a, i) => sum + cross(a, p[(i + 1) % p.length]), 0);
  const side = Math.sign(area);
  const edges = p.map((a, i) => {
    const b = p[(i + 1) % p.length];
    const v = [b[0] - a[0], b[1] - a[1]], len = Math.hypot(...v);
    return { a: [a[0] - side * v[1] * amount / len, a[1] + side * v[0] * amount / len], v };
  });
  return edges.map((b, i) => {
    const a = edges[(i + edges.length - 1) % edges.length];
    const t = cross([b.a[0] - a.a[0], b.a[1] - a.a[1]], b.v) / cross(a.v, b.v);
    return [a.a[0] + t * a.v[0], a.a[1] + t * a.v[1]];
  });
}
function ring(outer, inner, colors) {
  return outer.map((p, i) => polygon([p, outer[(i + 1) % outer.length], inner[(i + 1) % inner.length], inner[i]], colors[i % colors.length])).join('\n');
}
function metal(p, compact) {
  const ridge = inset(p, compact ? 20 : 17), inside = inset(p, compact ? 43 : 42);
  return [
    polygon(p, palette.edge),
    ring(p, ridge, ['#eab469', '#c47a27', '#a55a1b', '#be752b', '#e1a44f', '#ffe0a0']),
    ring(ridge, inside, ['#8d430d', '#5e2d0c', '#70380c', '#9c5215', '#b87128', '#b67831']),
    polygon(inside, palette.chassis),
    line([...ridge, ridge[0]], '#ffdfa2', compact ? 3.5 : 2.3),
    line([...p, p[0]], '#edc17f', compact ? 2.5 : 1.2),
    line([...inside, inside[0]], palette.recess, compact ? 5 : 6),
  ].join('\n');
}
function ribbon(points, kind, compact) {
  const rim = inset(points, compact ? 10 : 8), face = inset(points, compact ? 17 : 15);
  const base = palette[kind], light = palette[kind + 'Light'], dark = palette[kind + 'Dark'];
  return [
    polygon(points, palette.edge, `stroke="${palette.recess}" stroke-width="${compact ? 9 : 10}" stroke-linejoin="miter"`),
    ring(points, rim, ['#f8cc83', '#b8772a', '#85420e', '#a7651e', '#d99743', '#ffe1a3', '#cc8b3d', '#f7d18c']),
    ring(rim, face, [light, light, dark, dark, dark, light, light, dark]),
    polygon(face, base),
    line([...rim, rim[0]], kind === 'ivory' ? '#fff1cd' : '#ccae7b', compact ? 0 : 1.5),
  ].join('\n');
}
function first(compact) {
  const frame = [[512,54],[864,295],[864,708],[512,966],[160,708],[160,295]];
  return [
    metal(frame, compact),
    // The four broad arms remain separate around the central keystone.
    ribbon([[338,244],[506,404],[506,424],[420,502],[280,363],[280,285]], 'ivory', compact),
    ribbon([[690,243],[788,315],[788,361],[600,531],[510,442],[510,418]], 'blue', compact),
    ribbon([[441,493],[527,572],[333,763],[238,699],[235,660]], 'blue', compact),
    ribbon([[590,501],[744,651],[744,721],[691,762],[512,591],[512,565]], 'ivory', compact),
    polygon([[512,416],[588,494],[512,563],[436,494]], palette.edge, 'stroke="#482809" stroke-width="7"'),
    polygon([[512,420],[584,493],[512,493]], '#f1c16d'),
    polygon([[512,420],[512,493],[440,493]], '#ffe8a9'),
    polygon([[440,495],[512,495],[512,559]], '#b36c22'),
    polygon([[512,495],[584,495],[512,559]], '#89430d'),
    line([[440,493],[512,420],[584,493],[512,559],[440,493],[584,493]], '#e5b061', compact ? 3 : 2),
  ].join('\n');
}
function builder(compact) {
  const frame = [[512,49],[875,335],[875,682],[512,996],[148,682],[148,335]];
  return [
    metal(frame, compact),
    ribbon([[188,347],[381,499],[381,620],[188,451]], 'ivory', compact),
    ribbon([[294,258],[485,411],[395,491],[296,407]], 'blue', compact),
    ribbon([[830,346],[830,451],[637,610],[563,531]], 'ivory', compact),
    // Open V return: the negative space belongs to the chassis, not a medallion.
    ribbon([[318,714],[512,882],[701,730],[701,812],[512,936],[318,790]], 'ivory', compact),
    // The main blue band crosses above the lower ivory return.
    ribbon([[727,257],[727,407],[637,480],[691,527],[411,755],[318,818],[318,716],[556,519],[504,473]], 'blue', compact),
    // Lower left branch stops at the woven junction.
    ribbon([[190,481],[318,589],[381,641],[318,701],[190,593]], 'blue', compact),
    // Lower right branch sits behind the forward ivory band.
    ribbon([[830,481],[830,593],[704,701],[639,643]], 'blue', compact),
    // Tall ivory crown and forward descending ribbon.
    ribbon([[512,108],[618,292],[618,347],[513,452],[560,495],[459,598],[374,537],[374,484],[458,400],[408,349],[408,293]], 'ivory', compact),
    polygon([[512,222],[568,302],[513,345],[463,303]], palette.recess,
      `stroke="#a36b30" stroke-width="${compact ? 10 : 6}"`),
    line([[512,113],[512,219]], '#fff1d0', compact ? 3.5 : 2.5),
    // Restore the front right ivory crossing over its cobalt branch.
    ribbon([[586,597],[702,693],[702,813],[496,651]], 'ivory', compact),
  ].join('\n');
}
for (const [id, name, draw] of [['first-prompt', 'First Prompt', first], ['builder', 'Builder', builder]]) {
  for (const compact of [false, true]) {
    const filename = `${id}${compact ? '-compact' : ''}.svg`;
    const svg = `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-labelledby="title desc">\n<title id="title">DockMagic ${name}${compact ? ' — compact' : ''}</title>\n<desc id="desc">Review prototype reconstructed from the existing badge. Solid vector facets, transparent canvas, no embedded bitmap.</desc>\n${draw(compact)}\n</svg>\n`;
    if (/NaN|Infinity/.test(svg)) throw new Error(`Invalid geometry: ${filename}`);
    writeFileSync(resolve(out, filename), svg);
    console.log(`${filename}: ${Buffer.byteLength(svg)} bytes`);
  }
}

// Optional throwaway asset catalog for the native SwiftUI verification harness.
// Production Assets.xcassets is deliberately not a generator output.
const catalog = process.argv[2];
if (catalog) {
  mkdirSync(catalog, { recursive: true });
  writeFileSync(resolve(catalog, 'Contents.json'), JSON.stringify({info:{author:'xcode',version:1}}));
  for (const [slug, asset] of [['first-prompt','StreakBadgeFirstPrompt'],['builder','StreakBadgeBuilder']]) {
    for (const variant of ['png', 'svg', 'compact']) {
      const name = `${slug}-${variant}`, dir = resolve(catalog, `${name}.imageset`);
      mkdirSync(dir, {recursive:true});
      const filename = variant === 'png' ? `${asset}.png` : `${slug}${variant === 'compact' ? '-compact' : ''}.svg`;
      const source = variant === 'png' ? resolve(root, `DockMagic/DockMagic/Assets.xcassets/${asset}.imageset/${filename}`) : resolve(out, filename);
      copyFileSync(source, resolve(dir, filename));
      const spec = {images:[{filename,idiom:'universal',...(variant === 'png' ? {scale:'1x'} : {})}],info:{author:'xcode',version:1}};
      if (variant !== 'png') spec.properties = {'preserves-vector-representation':true};
      writeFileSync(resolve(dir,'Contents.json'), JSON.stringify(spec));
    }
  }
}
