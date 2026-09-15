import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const out=resolve(root,'docs/streak-concepts/hex-svg-v1');
const manifest=JSON.parse(readFileSync(resolve(out,'manifest.json'),'utf8'));
assert.deepEqual(manifest.badges.map(b=>b.day),[1,3,7,14,30,60,100,180,365,730]);
const compiled=JSON.parse(readFileSync(resolve(out,'asset-catalog-info.json'),'utf8'));
const vectors=compiled.filter(a=>a.AssetType==='Vector');
const checks=[];
const productionAssets=[];
for(const badge of manifest.badges) for(const [variant,info] of Object.entries(badge.variants)) {
  const svg=readFileSync(resolve(out,info.file),'utf8');
  assert.equal(Buffer.byteLength(svg),info.bytes);
  assert(svg.includes('viewBox="0 0 1024 1024"'));
  assert(!/<(?:image|filter|linearGradient|radialGradient|text|script|foreignObject)\b|href=|url\(|NaN|Infinity/i.test(svg));
  const tags=[...svg.matchAll(/<([A-Za-z][A-Za-z0-9]*)\b/g)].map(m=>m[1]);
  assert(tags.every(t=>['svg','title','desc','g','path','polygon','circle','ellipse'].includes(t)));
  assert(vectors.some(v=>v.Name===`${badge.slug}-${variant}`),`Missing preserved vector: ${badge.slug}-${variant}`);
  checks.push({file:info.file,bytes:info.bytes,sha256:createHash('sha256').update(svg).digest('hex'),nativeVector:true});
}
assert.equal(vectors.length,20);
for(const badge of manifest.badges) {
  const set=resolve(root,`DockMagic/DockMagic/Assets.xcassets/${badge.asset}.imageset`);
  const contents=JSON.parse(readFileSync(resolve(set,'Contents.json'),'utf8'));
  const expected=`${badge.asset}.svg`;
  assert.deepEqual(contents.images,[{filename:expected,idiom:'universal'}]);
  assert.equal(contents.properties?.['preserves-vector-representation'],true);
  assert.deepEqual(readdirSync(set).sort(),['Contents.json',expected].sort(),`Unexpected production files for ${badge.asset}`);
  const production=readFileSync(resolve(set,expected));
  const source=readFileSync(resolve(out,badge.variants.master.file));
  assert.equal(Buffer.compare(production,source),0,`Production SVG differs from approved master: ${badge.asset}`);
  productionAssets.push({asset:badge.asset,file:`${badge.asset}.imageset/${expected}`,source:badge.variants.master.file,sha256:createHash('sha256').update(production).digest('hex'),preservesVectorRepresentation:true});
}
const result={status:'passed',svgCount:checks.length,nativeVectorCount:vectors.length,productionAssetCount:productionAssets.length,totalBytes:checks.reduce((n,c)=>n+c.bytes,0),checks,productionAssets};
writeFileSync(resolve(out,'validation.json'),JSON.stringify(result,null,2)+'\n');
console.log(`PASS: ${checks.length} pure SVGs / ${vectors.length} preserved native vectors / ${productionAssets.length} production replacements / ${result.totalBytes} bytes total`);
