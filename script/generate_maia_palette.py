#!/usr/bin/env python3
"""Convert the pinned Maia OKLCH palette into native sRGB assets (no network)."""
import argparse, json, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'DockMagic/DockMagic/Assets.xcassets'
# L C hue alpha. Neutral colors have C=0; component alpha remains unflattened.
def n(l, alpha=1): return [l, 0, 0, alpha]
PAIRS = {}
def roles(names, light, dark):
    for name in names.split(): PAIRS[name] = [light, dark]
roles('DSSurface DSOpaqueSurface', n(1), n(.145))
roles('DSSurfaceRaised DSOpaqueSurfaceRaised', n(1), n(.205))
roles('DSSurfaceInset DSOpaqueSurfaceInset DSSurfaceChrome DSOpaqueSurfaceChrome DSSelectionFill DSSidebarSelectionFill', n(.97), n(.269))
roles('DSTextPrimary DSDockForeground', n(.145), n(.985))
roles('DSAction DSActionForeground DSSidebarIconFill', n(.205), n(.922))
roles('DSOnAction DSOnSidebarIcon', n(.985), n(.205))
# AX: .545 instead of .556 reaches 4.5:1 on the .97 Light inset.
roles('DSTextSecondary DSTextTertiary', n(.545), n(.708))
roles('DSOutline', n(.922), n(1,.1))
roles('DSInputOutline', n(.922), n(1,.15))
roles('DSOutlineStrong DSFocus DSSelectionOutline', n(.556), n(.708))
roles('DSDanger', [.577,.245,27.325,1], [.704,.191,22.216,1])
# AX: darker foreground on inset; filled danger keeps exact upstream token.
roles('DSDangerForeground', [.565,.245,27.325,1], [.704,.191,22.216,1])
roles('DSOnDanger', n(.985), n(.145))
roles('DSDockBackgroundRaised', n(1), n(.205))
roles('DSDockBackgroundInset', n(.97), n(.269))
roles('DSDockTrack', n(.6), n(.6))
roles('DSDockOutline', n(.145), n(.922))

def srgb(token):
    l,c,h,alpha=token; a=c*math.cos(math.radians(h)); b=c*math.sin(math.radians(h))
    x=(l+.3963377774*a+.2158037573*b)**3
    y=(l-.1055613458*a-.0638541728*b)**3
    z=(l-.0894841775*a-1.291485548*b)**3
    rgb=[4.0767416621*x-3.3077115913*y+.2309699292*z,
        -1.2684380046*x+2.6097574011*y-.3413193965*z,
        -.0041960863*x-.7034186147*y+1.707614701*z]
    def encode(v): return max(0,min(1,12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055))
    return [*map(encode,rgb),alpha]

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    manifest={'preset':'bbVKHJo','style':'base-maia','conversion':'OKLCH -> linear sRGB -> gamma-encoded sRGB, clip out-of-gamut channels; preserve alpha','nativeAdaptations':{'mutedForegroundLight':'.545 (source .556), 4.5:1 on .97 inset','dangerForegroundLight':'.565 .245 27.325 (source L .577), 4.5:1 on inset','focus':'.556 / .708 (source .708 / .556), 3:1','dock':'neutral .6 track, .145/.922 outline; preserve user data colors','selection':'neutral accent including sidebar; no chromatic sidebar-primary'},'assets':{}}
    failures=[]
    for name,pair in PAIRS.items():
        colors=[]
        for i,t in enumerate(pair):
            values={k:f'{v:.8f}' for k,v in zip(['red','green','blue','alpha'],srgb(t))}
            entry={'idiom':'universal','color':{'color-space':'srgb','components':values}}
            if i: entry['appearances']=[{'appearance':'luminosity','value':'dark'}]
            colors.append(entry)
        payload={'colors':colors,'info':{'author':'xcode','version':1}}
        path=ASSETS/(name+'.colorset')/'Contents.json'
        if args.check:
            if not path.exists() or json.loads(path.read_text())!=payload: failures.append(str(path))
        else:
            path.parent.mkdir(exist_ok=True);path.write_text(json.dumps(payload,indent=2)+'\n')
        manifest['assets'][name]={'oklch':{'light':pair[0],'dark':pair[1]},'sRGB':{'light':srgb(pair[0]),'dark':srgb(pair[1])}}
    dest=ROOT/'docs/research/maia-native/palette.json'
    if args.check:
        if json.loads(dest.read_text())!=manifest: failures.append(str(dest))
        if failures: raise SystemExit('Palette drift: '+', '.join(failures))
        print(f'Verified {len(PAIRS)} Light/Dark Maia color assets and alpha.')
    else: dest.write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__': main()
