#!/usr/bin/env python3
"""Register this extracted bundle for the current desktop user, without sudo."""
import os
import pathlib
import subprocess

bundle = pathlib.Path(__file__).resolve().parent
exe = bundle / 'dart_tournament_manager'
if not exe.is_file():
    raise SystemExit('Start this installer inside the fully extracted app bundle.')
if '\n' in str(exe) or '\r' in str(exe):
    raise SystemExit('The bundle path must not contain line breaks.')

def desktop_quote(value):
    # Desktop Entry Exec quoting, followed by desktop-file string escaping.
    value = str(value).replace('%', '%%')
    for char in ['\\', '"', '`', '$']:
        value = value.replace(char, '\\' + char)
    return '"' + value.replace('\\', '\\\\') + '"'

data = pathlib.Path(os.environ.get('XDG_DATA_HOME') or pathlib.Path.home() / '.local/share')
applications = data / 'applications'
applications.mkdir(parents=True, exist_ok=True)
entry = applications / 'com.example.dart_tournament_manager.desktop'
entry.write_text('[Desktop Entry]\nType=Application\nName=Dart Turnierverwaltung\n'
    f'Exec={desktop_quote(exe)} %u\nTerminal=false\nCategories=Game;\n'
    'MimeType=x-scheme-handler/dartturnier;\n', encoding='utf-8')
subprocess.run(['xdg-mime', 'default', entry.name, 'x-scheme-handler/dartturnier'], check=True)
print('Desktop entry and dartturnier:// links registered for this user.')
