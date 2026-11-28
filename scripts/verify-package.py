#!/usr/bin/env python3
import plistlib, subprocess, tempfile
from pathlib import Path

root=Path(__file__).resolve().parents[1]
def output(*args):
    return subprocess.check_output(args,text=True).strip()
packages=sorted((root/'packages').glob('*.deb'))
assert len(packages)==1, f'expected exactly one deb, found {len(packages)}'
deb=packages[0]
fields={k:output('dpkg-deb','-f',str(deb),k) for k in ('Package','Version','Architecture','Depends')}
assert fields['Package']=='com.local.ios27statusbar', fields
assert fields['Architecture']=='iphoneos-arm64e', fields
assert 'mobilesubstrate' in fields['Depends'], fields
with tempfile.TemporaryDirectory(prefix='i27re-package-') as tmp:
    subprocess.run(['dpkg-deb','-x',str(deb),tmp],check=True)
    payload=Path(tmp)
    dylibs=list(payload.rglob('iOS27StatusBar.dylib'))
    plists=list(payload.rglob('iOS27StatusBar.plist'))
    assert len(dylibs)==1, f'expected one tweak dylib, got {dylibs}'
    assert len(plists)==1, f'expected one filter plist, got {plists}'
    data=dylibs[0].read_bytes()
    assert len(data)>=32 and data[:4]==b'\xcf\xfa\xed\xfe', 'not a thin little-endian Mach-O64'
    import struct
    magic,cputype,cpusubtype=struct.unpack_from('<Iii',data,0)
    assert (cputype & 0xffffffff)==0x0100000c, hex(cputype & 0xffffffff)
    assert (cpusubtype & 0xffffffff)==0x80000002, hex(cpusubtype & 0xffffffff)
    with plists[0].open('rb') as f: filter_data=plistlib.load(f)
    bundles=filter_data.get('Filter',{}).get('Bundles',[])
    assert bundles==['com.apple.springboard','com.apple.UIKit'], bundles
print('PASS: package metadata:',fields)
print('PASS: one thin arm64e Mach-O:',dylibs[0].relative_to(payload))
print('PASS: original SpringBoard/UIKit injection filter preserved')
