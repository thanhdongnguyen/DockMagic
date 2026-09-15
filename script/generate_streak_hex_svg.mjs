// Deterministic vector source for the production Hex Collectibles v1 assets.
// Run with an optional throwaway .xcassets path to prepare native verification.
// No tracing payloads, embedded bitmaps, fonts, filters, gradients or resources.
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import assert from 'node:assert/strict';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = resolve(root, 'docs/streak-concepts/hex-collectibles-v1');
const out = resolve(root, 'docs/streak-concepts/hex-svg-v1');
const badges = JSON.parse(readFileSync(resolve(source, 'manifest.json'), 'utf8')).badges;
mkdirSync(resolve(out, 'assets'), { recursive: true });
const C = {
  ink:'#0d163e', field:'#13245b', fieldSide:'#18255e', ivory:'#fffbea',
  ivorySide:'#d9d8ca', ivoryShade:'#b8bfce', gold:'#ffcb09', goldLight:'#ffeb69',
  goldSide:'#ed9800', goldDark:'#c47800', blue:'#526ee4', blueLight:'#dce4ff',
  blueSide:'#8eabff', mint:'#8cf4c6', mintSide:'#30bc90', white:'#ffffff',
};
const fmt = n => Number(n.toFixed(2));
const path = (d, fill, extra = '') => `<path d="${d}" fill="${fill}" ${extra}/>`;
const poly = (points, fill, extra = '') => `<polygon points="${points.map(p => p.map(fmt).join(',')).join(' ')}" fill="${fill}" ${extra}/>`;
const circle = (x,y,r,fill,extra='') => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" ${extra}/>`;
const ellipse = (x,y,rx,ry,fill,extra='') => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${fill}" ${extra}/>`;
const group = (body, transform='') => `<g${transform ? ` transform="${transform}"` : ''}>${body}</g>`;
const outline = compact => `stroke="${C.ink}" stroke-width="${compact ? 18 : 14}" stroke-linejoin="round" stroke-linecap="round"`;
const stroke = (d, color, width) => path(d,'none',`stroke="${color}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round"`);
const outer = 'M491 80 Q512 68 533 80 L873 276 Q895 289 895 314 L895 710 Q895 736 873 748 L533 944 Q512 956 491 944 L151 748 Q129 736 129 710 L129 314 Q129 289 151 276 Z';

function frame(tier, compact) {
  const p = tier === 'gold'
    ? ['#ffe949','#ffd10a','#f29400','#be7100','#f6a400','#ffce08','#fffaaa','#ffd51b','#cd7700']
    : tier === 'platinum'
      ? ['#e4eeff','#b9cbff','#819aef','#5065b5','#a1b8ef','#cadbff','#ffffff','#fff083','#edac00']
      : ['#a49bff','#6e60ff','#403ce0','#3432b1','#4e3aff','#786cff','#e4e0ff','#4542ff','#9890ff'];
  return [
    path(outer,p[0]),
    path('M512 74 Q523 74 533 80 L873 276 Q884 283 889 296 L824 330 L512 150 Z',p[1]),
    path('M889 296 Q895 304 895 314 L895 710 Q895 724 889 735 L824 694 L824 330 Z',p[2]),
    path('M889 735 Q884 743 873 748 L533 944 Q523 950 512 950 L512 874 L824 694 Z',p[3]),
    path('M512 950 Q501 950 491 944 L151 748 Q140 742 135 734 L200 694 L512 874 Z',p[4]),
    path('M135 734 Q129 724 129 710 L129 314 Q129 304 135 296 L200 330 L200 694 Z',p[5]),
    poly([[512,150],[824,330],[824,694],[512,874],[200,694],[200,330]],p[7]),
    poly([[512,150],[824,330],[799,344],[512,178]],tier === 'gold' ? C.goldSide : p[7]),
    poly([[824,330],[824,694],[799,680],[799,344]],p[8]),
    poly([[824,694],[512,874],[512,846],[799,680]],tier === 'platinum' ? C.goldLight : p[8]),
    poly([[512,874],[200,694],[225,680],[512,846]],tier === 'gold' ? C.goldLight : p[0]),
    poly([[512,178],[799,344],[799,680],[512,846],[225,680],[225,344]],C.field,outline(false)),
    poly([[512,185],[792,348],[792,676],[512,837]],C.fieldSide),
    stroke('M191 276 L321 201',p[6],compact ? 20 : 22),
    compact ? '' : path('M154 442 Q154 436 160 432 L183 418 Q190 414 190 423 L190 538 L154 559 Z',p[6]),
    path(outer,'none',`stroke="${C.ink}" stroke-width="${compact ? 16 : 12}" stroke-linejoin="round"`),
  ].join('\n');
}

function star(x,y,r,compact) {
  const pts = Array.from({length:10},(_,i) => {
    const a = (-90 + i*36)*Math.PI/180, radius = i%2 ? r*0.47 : r;
    return [x+Math.cos(a)*radius,y+Math.sin(a)*radius];
  });
  return poly(pts,C.gold,`stroke="${C.ink}" stroke-width="${compact ? 12 : 10}" stroke-linejoin="round"`) +
    (compact ? '' : Array.from({length:5},(_,i) => poly([[x,y],pts[i*2],pts[i*2+1]],i === 0 || i === 4 ? C.goldLight : C.goldSide)).join(''));
}
function rank(count,compact) {
  if (!count) return '';
  const spacing = count === 3 ? 114 : 142, r = count === 1 ? 79 : 65;
  return Array.from({length:count},(_,i)=>star(512+(i-(count-1)/2)*spacing,765,count===3 && i===1 ? 70 : r+(compact?3:0),compact)).join('');
}
function sparkle(x,y,size,fill,compact) {
  return group(path('M0 -100 L29 -30 L100 0 L30 28 L0 100 L-29 29 L-100 0 L-30 -29 Z',fill,`stroke="${C.ink}" stroke-width="14" stroke-linejoin="round"`) +
    (compact ? '' : path('M0 -93 V0 H92 L30 28 L0 93 V0 H-92 L-30 -29 Z',fill===C.gold ? C.goldLight : C.blueSide)),`translate(${x} ${y}) scale(${size/100})`);
}

function firstPrompt(compact) {
  const bubble='M405 339 H609 Q710 339 710 436 V546 Q710 643 616 643 H444 L357 698 Q342 707 347 686 L362 627 Q310 607 310 549 V432 Q310 339 405 339 Z';
  return path(bubble,C.ivory,outline(compact)) +
    path('M683 424 V544 Q683 613 615 613 H435 L351 688 L357 698 L444 643 H616 Q710 643 710 546 V436 Q710 414 707 402 Z',C.ivorySide) +
    path(bubble,'none',outline(compact)) +
    stroke('M412 447 L473 501 L412 555',C.ink,compact?35:32) +
    stroke('M516 555 H608',C.ink,compact?34:30) +
    (compact?'':stroke('M339 418 Q348 368 402 369',C.white,20)) +
    sparkle(664,358,78,C.gold,compact);
}
function spark(compact) {
  const d='M501 267 Q512 245 523 267 L589 410 Q598 432 620 442 L731 493 Q758 506 731 520 L616 573 Q595 582 586 602 L523 746 Q512 772 501 746 L434 602 Q425 582 404 573 L283 520 Q258 506 283 493 L403 442 Q425 432 434 411 Z';
  return path(d,C.gold,outline(compact)) +
    path('M512 262 L512 506 L273 506 L404 573 Q425 582 434 602 L501 746 Q512 772 523 746 L586 602 Q595 582 616 573 L748 510 L512 506 Z',C.goldSide) +
    path('M501 267 Q512 245 523 267 L550 329 L469 493 H280 L403 442 Q425 432 434 411 Z',C.goldLight) +
    path(d,'none',outline(compact)) +
    path('M529 366 L418 538 H495 L484 662 L594 483 H521 Z',C.ivory,'stroke="#fffbea" stroke-width="8" stroke-linejoin="round"') +
    sparkle(690,352,69,C.gold,compact);
}
function loop(compact) {
  const upper='M292 548 C274 380 432 248 596 303 L631 319 L648 285 Q658 266 669 288 L706 410 Q709 423 693 427 L570 451 Q551 455 558 436 L574 402 C470 351 381 420 384 514 Q385 527 372 532 L313 554 Q295 561 292 548 Z';
  const lower='M731 480 C749 648 591 780 427 725 L392 709 L375 743 Q365 762 354 740 L317 618 Q314 605 330 601 L453 577 Q472 573 465 592 L449 626 C553 677 642 608 639 514 Q638 501 651 496 L710 474 Q728 467 731 480 Z';
  return path(upper,C.mint,outline(compact)) +
    path('M298 537 C292 411 421 318 538 368 L574 402 C470 351 381 420 384 514 Q385 527 372 532 L313 554 Z',C.mintSide) +
    path(upper,'none',outline(compact)) + path(lower,C.ivory,outline(compact)) +
    path('M725 491 C731 617 602 710 485 660 L449 626 C553 677 642 608 639 514 Q638 501 651 496 L710 474 Z',C.ivorySide) +
    path(lower,'none',outline(compact)) +
    (compact?'':stroke('M364 382 Q386 354 413 341',C.ivory,20) + stroke('M659 647 Q642 665 618 677',C.white,20));
}
function cube(x,y,s,colors,compact) {
  const top=[[0,-s],[s,-s/2],[0,0],[-s,-s/2]], left=[[-s,-s/2],[0,0],[0,s],[-s,s/2]], right=[[0,0],[s,-s/2],[s,s/2],[0,s]];
  return group(poly(top,colors[0])+poly(left,colors[1])+poly(right,colors[2])+
    poly([[0,-s],[s,-s/2],[s,s/2],[0,s],[-s,s/2],[-s,-s/2]],'none',outline(compact))+
    (compact?'':path(`M${-s+24} ${-s/2+35} l40 23 v30 l-40 -23 Z`,C.white,'stroke="#ffffff" stroke-width="8" stroke-linejoin="round"')),`translate(${x} ${y})`);
}
function builder(compact) {
  return cube(390,549,121,[C.ivory,'#edeadd',C.ivoryShade],compact)+
    cube(635,549,121,[C.blueLight,C.blueSide,C.blue],compact)+
    cube(512,367,121,[C.goldLight,C.gold,C.goldSide],compact);
}
function flow(compact) {
  const a='M278 468 C290 374 344 416 389 415 C491 422 551 269 650 301 C710 320 742 367 745 410 C686 344 638 365 578 418 C478 508 433 543 345 490 C314 471 298 468 278 468 Z';
  const b='M282 491 C359 521 387 571 465 536 C557 496 622 395 683 412 C725 420 754 460 750 516 C700 468 657 484 601 535 C488 638 401 674 319 591 C286 558 275 528 282 491 Z';
  const c='M291 597 C401 694 475 661 574 587 C657 525 716 511 741 551 C758 578 751 625 728 654 C725 598 680 596 632 631 C531 706 435 754 348 686 C321 665 304 634 291 597 Z';
  return path(a,C.ivory,outline(compact))+
    (compact?'':path('M278 468 C330 463 367 520 428 500 C519 471 590 350 657 342 C697 338 727 371 745 410 C686 344 638 365 578 418 C478 508 433 543 345 490 Z',C.ivorySide))+
    path(a,'none',outline(compact))+path(b,'#64cfff',outline(compact))+
    path('M296 554 C384 641 458 605 541 542 C642 465 690 450 748 503 L750 516 C700 468 657 484 601 535 C488 638 401 674 319 591 Z','#159eff')+
    path(b,'none',outline(compact))+path(c,C.mint,outline(compact))+
    path('M340 674 C430 730 521 669 612 607 C668 569 708 557 741 588 Q742 625 728 654 C725 598 680 596 632 631 C531 706 435 754 348 686 Z','#1bbca9')+
    path(c,'none',outline(compact))+
    (compact?'':stroke('M309 435 L350 445',C.white,20)+stroke('M311 525 L348 548',C.white,18));
}
function navigator(compact) {
  return circle(512,300,42,C.ivory,outline(compact))+circle(512,300,22,C.field)+
    circle(512,499,202,C.ivory,outline(compact))+
    path('M655 356 A202 202 0 0 1 370 642 L392 620 A172 172 0 0 0 633 378 Z',C.ivorySide)+
    circle(512,499,163,C.blue,outline(compact))+
    path('M512 336 A163 163 0 0 1 674 499 A163 163 0 0 1 397 614 L512 499 Z','#1c43ae')+
    poly([[619,382],[549,532],[405,616],[475,466]],C.gold,outline(compact))+
    poly([[405,616],[475,466],[512,499]],C.blueSide)+
    poly([[405,616],[512,499],[549,532]],'#777eff')+
    poly([[619,382],[549,532],[512,499]],C.goldSide)+
    poly([[619,382],[549,532],[405,616],[475,466]],'none',outline(compact))+
    circle(512,499,34,C.ivory,`stroke="${C.ink}" stroke-width="10"`)+
    (compact?'':stroke('M397 432 Q416 404 441 393',C.blueSide,25));
}
function trophy(compact) {
  const handle='M394 375 H337 Q291 376 298 424 Q307 507 400 523 L412 484 Q349 476 340 424 Q338 414 350 414 H401 Z';
  const cup='M378 348 Q512 322 646 348 L625 478 Q604 570 534 590 H490 Q420 570 399 478 Z';
  return path(handle,C.gold,outline(compact))+group(path(handle,C.gold,outline(compact)),'translate(1024 0) scale(-1 1)')+
    path('M481 566 H543 V607 Q550 620 578 622 V649 H446 V622 Q474 620 481 607 Z',C.gold,outline(compact))+
    path('M512 571 H543 V607 Q550 620 578 622 V642 H512 Z',C.goldSide)+
    path(cup,C.gold,outline(compact))+
    path('M583 341 L646 348 L625 478 Q604 570 534 590 H501 Q565 554 583 341 Z',C.goldSide)+
    path(cup,'none',outline(compact))+
    ellipse(512,346,134,28,C.goldDark,'stroke="#ffeb69" stroke-width="10"')+
    path('M405 390 L455 401 L457 474 L415 451 Z',C.ivory)+
    path('M420 643 L451 625 H573 L604 643 V699 H420 Z',C.ivory,outline(compact))+
    path('M565 643 H604 V699 H565 Z',C.ivoryShade)+
    path('M420 643 H604','none','stroke="#d9d8ca" stroke-width="7"')+
    poly([[512,650],[539,674],[512,695],[484,674]],C.ink);
}
function architect(compact) {
  const arch = (x,y,w,h) => path(`M${x} ${y+h} V${y+w/2} a${w/2} ${w/2} 0 0 1 ${w} 0 V${y+h} Z`,C.ink);
  return path('M350 637 L392 614 V559 L438 536 V437 H417 V397 L449 383 V350 L512 292 L618 365 V405 L639 416 V447 H618 V538 L667 563 V615 L706 638 V713 L655 738 L609 721 L551 737 L486 719 L421 737 L350 711 Z',C.ivory,outline(compact))+
    poly([[551,444],[618,437],[618,538],[667,563],[609,588],[609,721],[551,737]],C.blueSide)+
    poly([[667,615],[706,638],[706,713],[655,738],[655,644]],C.blueSide)+
    poly([[392,559],[438,536],[438,705],[421,737],[392,720]],C.blueLight)+
    poly([[392,614],[421,631],[421,737],[377,721],[377,637]],C.blueSide)+
    poly([[449,350],[512,292],[618,365],[551,392]],C.goldLight)+
    poly([[512,292],[551,392],[618,365]],C.goldSide)+
    poly([[449,350],[551,372],[551,407],[449,383]],C.gold)+
    poly([[551,372],[618,365],[618,405],[551,417]],C.goldSide)+
    path('M449 350 L512 292 L618 365 V405 L551 427 L449 399 Z','none',outline(compact))+
    path('M417 397 L551 418 L639 405 V444 L551 463 L417 440 Z',C.blueLight,`stroke="${C.ink}" stroke-width="10" stroke-linejoin="round"`)+
    path('M417 397 L551 418 V446 L417 425 Z',C.ivory)+
    arch(490,483,49,77)+arch(485,611,60,111)+
    (compact?'':path('M474 349 L498 320 L490 360 Z',C.ivory));
}
function keystone(compact) {
  // Broad voussoirs follow the same open arch; joints are structural, not texture.
  const block = (d, shade='') => path(d,C.ivory,outline(compact))+(shade?path(shade,C.blueSide):'');
  return [
    block('M285 640 H401 V707 H285 Z','M369 640 H401 V707 H369 Z'),
    block('M288 538 L407 553 V640 H288 Z','M374 549 L407 553 V640 H374 Z'),
    block('M301 464 L408 505 L407 553 L288 538 V483 Q288 470 301 464 Z','M378 493 L408 505 L407 553 L375 549 Z'),
    block('M359 378 L444 445 L408 505 L301 464 Z','M420 426 L444 445 L408 505 L381 495 Z'),
    block('M434 332 L480 430 L444 445 L359 378 Z','M457 381 L480 430 L444 445 L423 428 Z'),
    block('M623 640 H739 V707 H623 Z','M707 640 H739 V707 H707 Z'),
    block('M617 553 L736 538 V640 H617 Z','M704 542 L736 538 V640 H704 Z'),
    block('M616 505 L723 464 Q736 470 736 483 V538 L617 553 Z','M697 474 L723 464 Q736 470 736 483 V538 L699 543 Z'),
    block('M580 445 L665 378 L723 464 L616 505 Z','M641 397 L665 378 L723 464 L697 474 Z'),
    block('M544 430 L590 332 L665 378 L580 445 Z','M567 381 L590 332 L665 378 L641 397 Z'),
    path('M454 306 H570 Q586 306 580 323 L547 429 Q544 441 533 441 H491 Q480 441 477 429 L444 323 Q438 306 454 306 Z',C.gold,outline(compact)),
    path('M548 312 H578 L547 429 Q544 441 533 441 H491 L487 425 H520 Z',C.goldSide),
    compact?'':path('M460 324 H480 L489 354 H469 Z',C.ivory),
    path('M279 707 H408 V735 H279 Z',C.blueLight,`stroke="${C.ink}" stroke-width="10" stroke-linejoin="round"`),
    path('M616 707 H745 V735 H616 Z',C.blueSide,`stroke="${C.ink}" stroke-width="10" stroke-linejoin="round"`),
  ].join('');
}
function continuum(compact) {
  // A closed centerline has no exposed ribbon ends. Broad, open lobes survive 32pt.
  const ribbon='M512 500 C445 418 419 378 366 378 C251 378 251 622 366 622 C419 622 459 561 512 500 C565 439 605 378 658 378 C773 378 773 622 658 622 C605 622 579 582 512 500 Z';
  const front='M366 378 C419 378 445 418 512 500 C579 582 605 622 658 622';
  const lineWidth=compact?84:80;
  return sparkle(512,300,65,C.blueLight,compact)+
    stroke(ribbon,C.ink,lineWidth+26)+stroke(ribbon,C.gold,lineWidth)+
    stroke(front,C.goldLight,lineWidth-10)+
    (compact?'':stroke(front,C.ivory,40));
}

const symbols = [firstPrompt,spark,loop,builder,flow,navigator,trophy,architect,keystone,continuum];
const records=[];
for (const [i,badge] of badges.entries()) {
  const tier = i<6 ? 'violet' : i<9 ? 'gold' : 'platinum';
  const stars = i<3 ? 0 : i<6 ? 1 : i<9 ? 2 : 3;
  const record={day:badge.day,title:badge.title,slug:badge.slug,asset:badge.asset,tier,stars,source:`../hex-collectibles-v1/${badge.file}`,variants:{}};
  for (const compact of [false,true]) {
    const variant=compact?'compact':'master', file=`assets/${badge.slug}${compact?'-compact':''}.svg`;
    // Optical normalization against the concept: symbols clear the larger rank stars.
    const symbol=symbols[i](compact);
    const placement = {4:'translate(0 -25)',6:'translate(512 475) scale(1.12) translate(-512 -505)',7:'translate(512 -45) scale(1.14 1) translate(-512 0)',8:'translate(0 -48)'};
    const placed = placement[i] ? group(symbol,placement[i]) : symbol;
    const svg=`<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-labelledby="title desc">\n<title id="title">DockMagic ${badge.title} — ${variant}</title>\n<desc id="desc">${badge.day}-day streak collectible. ${stars} rank stars. Solid vector reconstruction of the approved hexagonal concept; transparent canvas.</desc>\n${frame(tier,compact)}\n${placed}\n${rank(stars,compact)}\n</svg>\n`;
    assert(!/NaN|Infinity|<image\b|<filter\b|<linearGradient\b|<radialGradient\b|<text\b|href=|url\(/i.test(svg),`Forbidden or invalid SVG: ${file}`);
    writeFileSync(resolve(out,file),svg);
    record.variants[variant]={file,bytes:Buffer.byteLength(svg)};
    console.log(`${file}: ${Buffer.byteLength(svg)} bytes`);
  }
  records.push(record);
}
writeFileSync(resolve(out,'manifest.json'),JSON.stringify({status:'production-svg-source',format:'pure-svg',viewBox:'0 0 1024 1024',generator:'script/generate_streak_hex_svg.mjs',badges:records},null,2)+'\n');
// A native catalog is always temporary; product Assets.xcassets is never touched.
const catalog=process.argv[2];
if(catalog) {
  const catalogPath=resolve(catalog);
  assert(!catalogPath.startsWith(resolve(root,'DockMagic')),'Refusing to write a production catalog');
  mkdirSync(catalogPath,{recursive:true});
  writeFileSync(resolve(catalogPath,'Contents.json'),JSON.stringify({info:{author:'xcode',version:1}}));
  for(const badge of records) for(const variant of ['png','master','compact']) {
    const dir=resolve(catalogPath,`${badge.slug}-${variant}.imageset`);
    mkdirSync(dir,{recursive:true});
    const filename=`badge.${variant==='png'?'png':'svg'}`;
    copyFileSync(variant==='png'?resolve(source,`assets/${badge.slug}.png`):resolve(out,badge.variants[variant].file),resolve(dir,filename));
    writeFileSync(resolve(dir,'Contents.json'),JSON.stringify({images:[{filename,idiom:'universal',...(variant==='png'?{scale:'1x'}:{})}],info:{author:'xcode',version:1},...(variant==='png'?{}:{properties:{'preserves-vector-representation':true}})}));
  }
}
