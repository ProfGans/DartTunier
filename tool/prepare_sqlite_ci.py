"""Prefetch sqlite3 3.3.4 hook assets with HTTP checks and SHA-256 validation.

Run after pub get, before Flutter tests/builds. The package hook rechecks these
cached files itself. Keep the cache layout in sync when upgrading sqlite3.
"""
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import time
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname


def prepare(targets):
    config = pathlib.Path('.dart_tool/package_config.json').resolve()
    packages = json.loads(config.read_text(encoding='utf-8'))['packages']
    package = next(p for p in packages if p['name'] == 'sqlite3')
    uri = urljoin(config.as_uri(), package['rootUri'])
    root = pathlib.Path(url2pathname(urlparse(uri).path))
    hashes = (root / 'lib/src/hook/asset_hashes.dart').read_text(encoding='utf-8')
    tag = re.search(r"releaseTag = '(sqlite3-[\w.+-]+)'", hashes)[1]
    if tag != 'sqlite3-3.3.4':
        raise RuntimeError('Review CI hook cache compatibility for ' + tag)
    assets = dict(re.findall(r"'([^']+)': '([0-9a-f]{64})'", hashes))
    for target in targets:
        windows = target.endswith('.windows')
        name = f'sqlite3.{target}.dll' if windows else f'libsqlite3.{target}.so'
        expected = assets[name]
        folder = config.parent / 'hooks_runner/shared/sqlite3/build' / ('download-' + expected[:8])
        folder.mkdir(parents=True, exist_ok=True)
        destination = folder / ('sqlite3.dll' if windows else 'libsqlite3.so')
        if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() == expected:
            print('Verified cached SQLite:', target)
            continue
        temporary = destination.with_suffix('.download')
        url = f'https://github.com/simolus3/sqlite3.dart/releases/download/{tag}/{name}'
        for attempt in range(3):
            try:
                subprocess.run(['curl', '--fail', '--location', '--retry', '3',
                                '--connect-timeout', '30', '--max-time', '180',
                                '--output', str(temporary), url], check=True)
                actual = hashlib.sha256(temporary.read_bytes()).hexdigest()
                if actual != expected:
                    raise RuntimeError(f'{name}: SHA-256 {actual}, expected {expected}')
                temporary.replace(destination)
                print('Downloaded and verified SQLite:', target)
                break
            except (subprocess.CalledProcessError, RuntimeError):
                if attempt == 2:
                    raise
                time.sleep(2 ** attempt)
            finally:
                temporary.unlink(missing_ok=True)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit('Usage: prepare_sqlite_ci.py x64.linux [arm64.android ...]')
    prepare(sys.argv[1:])
