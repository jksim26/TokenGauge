#!/usr/bin/env python3
"""Install the local helper, preserve Claude's existing status line, register widget."""
from pathlib import Path
import json, os, plistlib, shutil, subprocess, sys, time

ROOT = Path(__file__).resolve().parent
HOME = Path.home()
DATA = HOME / 'Library/Application Support/Token Gauge'
APP = HOME / 'Applications/Token Gauge.app'
SETTINGS = HOME / '.claude/settings.json'
AGENT = HOME / 'Library/LaunchAgents/local.jksim.tokengauge.plist'
LSREGISTER = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
NODE = shutil.which('node')
CODEX = shutil.which('codex')
GROK = (HOME / 'Library/Application Support/Grok Bot').exists()  # Optional: Grok Bot's local weekly usage cache.
if not NODE or not CODEX: sys.exit('Install Node.js and sign in to the Codex CLI first.')
DATA.mkdir(parents=True, exist_ok=True, mode=0o700)
config_path = DATA / 'config.json'
settings = json.loads(SETTINGS.read_text()) if SETTINGS.exists() else {}
config = json.loads(config_path.read_text()) if config_path.exists() else {}
wrapper = f'"{NODE}" "{DATA / "Bridge/claude-statusline.cjs"}"'
current = settings.get('statusLine')
if not (isinstance(current, dict) and current.get('command') == wrapper):
    if isinstance(current, dict) and 'claude-statusline.cjs' in current.get('command', ''):
        sys.exit('A different Token Gauge status-line wrapper is configured. Restore it before reinstalling.')
    config['previousStatusLine'] = current
    backup = DATA / 'claude-settings-before-install.json'
    if not backup.exists():
        backup.write_text(json.dumps(settings, indent=2) + '\n'); backup.chmod(0o600)
config.update(nodePath=NODE, codexPath=CODEX, path=os.environ.get('PATH', ''), wrapper=wrapper)
config_path.write_text(json.dumps(config, indent=2) + '\n'); config_path.chmod(0o600)
shutil.copytree(ROOT / 'Bridge', DATA / 'Bridge', dirs_exist_ok=True)
for stale in ['grok-cli.cjs', 'grok-pty.py']: (DATA / 'Bridge' / stale).unlink(missing_ok=True)  # earlier Cursor Agent reader
shutil.rmtree(DATA / 'grok-workspace', ignore_errors=True)
shutil.copy2(ROOT / 'build/claude-web-request', DATA / 'Bridge/claude-web-request')
if isinstance(current, dict) and current.get('command') == wrapper:
    if config.get('previousStatusLine') is None: settings.pop('statusLine', None)
    else: settings['statusLine'] = config['previousStatusLine']
    tmp = SETTINGS.with_suffix('.tokengauge.tmp')
    tmp.write_text(json.dumps(settings, indent=2) + '\n'); tmp.chmod(0o600); tmp.replace(SETTINGS)
# iPhone: put the Scriptable widget script in Scriptable's iCloud folder, if Scriptable syncs there.
SCRIPTABLE = HOME / 'Library/Mobile Documents/iCloud~dk~simonbs~Scriptable/Documents'
if SCRIPTABLE.exists(): shutil.copy2(ROOT / 'iPhone/Token Gauge.js', SCRIPTABLE / 'Token Gauge.js')
AGENT.parent.mkdir(parents=True, exist_ok=True)
agent = dict(Label='local.jksim.tokengauge', ProgramArguments=[NODE, str(DATA / 'Bridge/collector.cjs')],
             RunAtLoad=True, KeepAlive=True, ThrottleInterval=30,
             StandardErrorPath=str(DATA / 'helper.log'), StandardOutPath=str(DATA / 'helper.log'),
             EnvironmentVariables={'PATH': os.environ.get('PATH', '')})
AGENT.write_bytes(plistlib.dumps(agent))
uid = str(os.getuid())
subprocess.run(['launchctl', 'bootout', f'gui/{uid}/local.jksim.tokengauge'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
for attempt in range(5):
    result = subprocess.run(['launchctl', 'bootstrap', f'gui/{uid}', str(AGENT)], capture_output=True)
    if result.returncode == 0: break
    time.sleep(1)
else: sys.exit('The local helper could not restart. ' + result.stderr.decode())
subprocess.run(['pkill', '-x', 'TokenGauge'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(['pkill', '-KILL', '-x', 'TokenGaugeWidget'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(0.5)
if APP.exists(): shutil.rmtree(APP)
APP.parent.mkdir(exist_ok=True)
# Move rather than copy: two bundles with the same ID make macOS drop the widget registration.
BUILT = ROOT / 'build/Token Gauge.app'
if not BUILT.exists(): sys.exit('Run build.py first.')
subprocess.run([LSREGISTER, '-u', str(BUILT)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
shutil.move(BUILT, APP)
subprocess.run([LSREGISTER, '-f', str(APP)], check=True)
subprocess.run(['pluginkit', '-a', str(APP / 'Contents/PlugIns/TokenGaugeWidget.appex')], check=True)
time.sleep(1)
registered = subprocess.run(['pluginkit', '-m', '-v', '-i', 'local.jksim.TokenGauge.Widget'], capture_output=True, text=True).stdout
if str(APP) not in registered: sys.exit('The widget did not register with macOS. Run Install.command again.')
subprocess.run(['killall', 'chronod'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(['open', str(APP)], check=True)
print('Installed:', APP)
print('Claude, Codex' + (' and Grok' if GROK else '') + ' usage refresh every three minutes. Original Claude status line restored.')
if SCRIPTABLE.exists(): print('iPhone: the Token Gauge script and data are in Scriptable\'s iCloud folder.')
