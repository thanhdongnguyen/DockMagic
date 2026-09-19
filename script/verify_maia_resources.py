#!/usr/bin/env python3
"""Verify the pinned native font/icon/palette resources without network access."""
import argparse, hashlib, json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'docs/research/maia-native/resources.json'

def inventory():
    files=list((ROOT/'DockMagic/DockMagic/Resources/MaiaFonts').glob('*'))
    for directory in (ROOT/'DockMagic/DockMagic/Assets.xcassets').glob('Maia-*.imageset'):
        files.extend(directory.glob('*'))
    files.extend(ROOT/'docs/research/maia-native'/name for name in ['icons.json','palette.json'])
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files) if p.is_file()}

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--record-reviewed-update',action='store_true',help='Record a reviewed source/resource upgrade; never use in build')
args=parser.parse_args()
if args.record_reviewed_update:
    MANIFEST.write_text(json.dumps({'geistRevision':'10dc7658f13c38a474cde201bb09a4617267545b','hugeiconsFreeVersion':'4.3.3','sha256':inventory()},indent=2)+'\n')
else:
    expected=json.loads(MANIFEST.read_text())['sha256'];actual=inventory()
    drift=[key for key in expected.keys()|actual.keys() if expected.get(key)!=actual.get(key)]
    if drift: raise SystemExit('Maia resource drift: '+', '.join(drift))
    subprocess.run(['python3',str(ROOT/'script/generate_maia_palette.py'),'--check'],check=True)
    archive=ROOT/'docs/research/shadcn-bbVKHJo-2026-09-17'
    for line in (archive/'SHA256SUMS.txt').read_text().splitlines():
        digest,path=line.split(maxsplit=1)
        assert hashlib.sha256((archive/path.strip().lstrip('*')).read_bytes()).hexdigest()==digest,path
    print(f'Verified {len(actual)} native resources and immutable registry snapshot.')
