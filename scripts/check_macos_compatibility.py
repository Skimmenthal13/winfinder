#!/usr/bin/env python3
"""Check the built app and all embedded Mach-O images; does not run the app."""
import argparse
import plistlib
import re
import subprocess
from pathlib import Path


def version(value):
    parts = tuple(int(part) for part in value.split('.'))
    return (parts + (0, 0, 0))[:3]


def check(app, minimum):
    with (app / 'Contents/Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if version(info['LSMinimumSystemVersion']) != version(minimum):
        raise ValueError(f"App minimum is {info['LSMinimumSystemVersion']}, expected {minimum}")
    main = app / 'Contents/MacOS' / info['CFBundleExecutable']
    magic = {bytes.fromhex(x) for x in ('feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
                                       'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}
    checked = set()
    for candidate in app.rglob('*'):
        if not candidate.is_file():
            continue
        path = candidate.resolve()
        if path in checked:
            continue
        with path.open('rb') as stream:
            if stream.read(4) not in magic:
                continue
        checked.add(path)
        archs = subprocess.check_output(['lipo', '-archs', str(path)], text=True).split()
        if not {'arm64', 'x86_64'}.issubset(archs):
            raise ValueError(f'{candidate}: missing arm64 or x86_64 ({archs})')
        for arch in ('arm64', 'x86_64'):
            output = subprocess.check_output(
                ['xcrun', 'vtool', '-arch', arch, '-show-build', str(path)], text=True)
            # Supports LC_BUILD_VERSION and legacy LC_VERSION_MIN_MACOSX.
            values = re.findall(r'^\s*(?:minos|version)\s+(\d+(?:\.\d+)+)\s*$', output, re.M)
            values = values[:1]  # Subsequent 'version' entries describe build tools.
            if not values:
                raise ValueError(f'{candidate} ({arch}): no minimum OS load command')
            required = version(values[0])
            if required > version(minimum):
                raise ValueError(f'{candidate} ({arch}) requires macOS {values[0]}')
            if path == main.resolve() and required != version(minimum):
                raise ValueError(f'Main executable ({arch}) must target {minimum}')
        print(f'OK: {candidate.relative_to(app)}')
    if main.resolve() not in checked:
        raise ValueError('Main executable is not a Mach-O binary')
    print(f'PASS: {len(checked)} Mach-O images, arm64 + x86_64, macOS {minimum}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--minimum', default='14.0')
    args = parser.parse_args()
    check(args.app, args.minimum)
