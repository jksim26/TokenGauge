#!/usr/bin/env python3
from pathlib import Path
import json, os, subprocess, shutil
home = Path.home()
data = home / 'Library/Application Support/Token Gauge'
settings_path = home / '.claude/settings.json'
config = json.loads((data / 'config.json').read_text()) if (data / 'config.json').exists() else {}
if settings_path.exists():
    settings = json.loads(settings_path.read_text())
    if settings.get('statusLine', {}).get('command') == config.get('wrapper'):
        if config.get('previousStatusLine') is None: settings.pop('statusLine', None)
        else: settings['statusLine'] = config['previousStatusLine']
        settings_path.write_text(json.dumps(settings, indent=2) + '\n')
subprocess.run(['launchctl', 'bootout', f'gui/{os.getuid()}/local.jksim.tokengauge'], stderr=subprocess.DEVNULL)
(home / 'Library/LaunchAgents/local.jksim.tokengauge.plist').unlink(missing_ok=True)
app = home / 'Applications/Token Gauge.app'
if app.exists():
    subprocess.run(['pluginkit', '-r', str(app / 'Contents/PlugIns/TokenGaugeWidget.appex')])
    shutil.rmtree(app)
# Stop sharing with the iPhone: remove the published data and the Scriptable script.
scriptable = home / 'Library/Mobile Documents/iCloud~dk~simonbs~Scriptable/Documents'
for name in ['Token Gauge.json', 'Token Gauge.js']: (scriptable / name).unlink(missing_ok=True)
print('Removed app and helper; restored original Claude status line. Saved reports remain in:', data)
