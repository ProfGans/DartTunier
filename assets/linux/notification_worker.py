#!/usr/bin/env python3
"""User-session notification receiver. No account password or refresh token."""
import fcntl
import html
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.request
import urllib.parse

def poll(config, acknowledged):
    url = config['url']
    if urllib.parse.urlparse(url).scheme != 'https':
        raise ValueError('HTTPS required')
    request = urllib.request.Request(url.rstrip('/') + '/rest/v1/rpc/poll_linux_notifications',
        data=json.dumps({'p_secret': config['secret'], 'p_ack': acknowledged}).encode(),
        headers={'apikey': config['key'], 'Content-Type': 'application/json'}, method='POST')
    with urllib.request.urlopen(request, timeout=20) as response:
        raw = response.read(1024 * 1024 + 1)
    if len(raw) > 1024 * 1024:
        raise ValueError('Response too large')
    return json.loads(raw)

def deliver(message):
    # notify-send interprets body markup; escape remote text and terminate options.
    subprocess.run(['notify-send', '--app-name=Dart Turnierverwaltung', '--',
        str(message['title'])[:200], html.escape(str(message['body'])[:2000])],
        timeout=10, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def run(config_path):
    os.umask(0o077)
    config_path = pathlib.Path(config_path)
    with open(str(config_path) + '.lock', 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # Persist delivered IDs before ack so a restart does not redisplay them.
        state_path = config_path.with_suffix('.delivered.json')
        try:
            acknowledged = json.loads(state_path.read_text())
        except (OSError, ValueError):
            acknowledged = []
        while config_path.exists():
            try:
                config = json.loads(config_path.read_text())
                if config.get('schemaVersion') != 1:
                    raise ValueError('Unsupported configuration')
                messages = poll(config, acknowledged)
                acknowledged = []
                for message in messages:
                    deliver(message)
                    acknowledged.append(message['id'])
                    temporary = state_path.with_suffix('.new')
                    temporary.write_text(json.dumps(acknowledged))
                    temporary.replace(state_path)
                # Clear old acks only after the server accepted the previous list.
                state_path.write_text(json.dumps(acknowledged))
                time.sleep(30)
            except Exception:
                # Never log credentials or notification contents. Retry after offline,
                # missing desktop bus, locked session or unavailable server migration.
                print('Notification delivery unavailable; retrying.', file=sys.stderr, flush=True)
                time.sleep(60)

if __name__ == '__main__':
    run(sys.argv[1])
