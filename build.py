#!/usr/bin/env python3
"""Build and ad-hoc sign the app and WidgetKit extension without an account."""
from pathlib import Path
import plistlib, subprocess, platform, shutil, time

ROOT = Path(__file__).resolve().parent
APP = ROOT / 'build' / 'Token Gauge.app'
EXT = APP / 'Contents' / 'PlugIns' / 'TokenGaugeWidget.appex'
BUILD_VERSION = str(int(time.time()))
LSREGISTER = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
def run(*args): subprocess.run([str(a) for a in args], check=True)
def plist(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(value))
def bundle(path, identifier, executable, package):
    (path / 'Contents' / 'MacOS').mkdir(parents=True, exist_ok=True)
    value = dict(CFBundleIdentifier=identifier, CFBundleName='Token Gauge', CFBundleDisplayName='Token Gauge',
                 CFBundleExecutable=executable, CFBundlePackageType=package, CFBundleVersion=BUILD_VERSION,
                 CFBundleSupportedPlatforms=['MacOSX'], DTPlatformName='macosx',
                 CFBundleShortVersionString='1.0', LSMinimumSystemVersion='14.0',
                 NSAppTransportSecurity={'NSAllowsLocalNetworking': True, 'NSExceptionDomains': {'127.0.0.1': {'NSExceptionAllowsInsecureHTTPLoads': True}}})
    return value
if APP.exists(): shutil.rmtree(APP)
sdk = subprocess.check_output(['xcrun', '--show-sdk-path'], text=True).strip()
arch = 'arm64' if platform.machine() == 'arm64' else 'x86_64'
base = ['xcrun', 'swiftc', '-parse-as-library', '-O', '-sdk', sdk, '-target', f'{arch}-apple-macos14.0', '-framework', 'SwiftUI', '-framework', 'WidgetKit']
app_info = bundle(APP, 'local.jksim.TokenGauge', 'TokenGauge', 'APPL')
app_info.update(NSPrincipalClass='NSApplication', CFBundleIconFile='AppIcon', CFBundleURLTypes=[{'CFBundleURLName': 'Token Gauge', 'CFBundleURLSchemes': ['tokengauge']}])
plist(APP / 'Contents' / 'Info.plist', app_info)
widget_info = bundle(EXT, 'local.jksim.TokenGauge.Widget', 'TokenGaugeWidget', 'XPC!')
widget_info['NSExtension'] = {'NSExtensionPointIdentifier': 'com.apple.widgetkit-extension'}
plist(EXT / 'Contents' / 'Info.plist', widget_info)
entitlements = ROOT / 'build' / 'Widget.entitlements'
plist(entitlements, {'com.apple.security.app-sandbox': True, 'com.apple.security.network.client': True})
shared = [ROOT / 'Sources/Shared.swift', ROOT / 'Sources/ProviderMark.swift']
run(*base, '-application-extension', '-Xlinker', '-e', '-Xlinker', '_NSExtensionMain', '-Xlinker', '-u', '-Xlinker', '_main', '-module-name', 'TokenGaugeWidget', *shared, ROOT / 'Sources/Widget.swift', '-o', EXT / 'Contents/MacOS/TokenGaugeWidget')
run(*base, '-module-name', 'TokenGauge', *shared, ROOT / 'Sources/App.swift', '-o', APP / 'Contents/MacOS/TokenGauge')
run(*base, ROOT / 'Sources/ClaudeWebRequest.swift', '-o', ROOT / 'build/claude-web-request')
icon_tool = ROOT / 'build/icon-maker'
icon_set = ROOT / 'build/AppIcon.iconset'
run('xcrun', 'swiftc', '-parse-as-library', ROOT / 'Sources/Icon.swift', '-o', icon_tool)
run(icon_tool, icon_set)
(APP / 'Contents/Resources').mkdir(parents=True, exist_ok=True)
run('iconutil', '-c', 'icns', icon_set, '-o', APP / 'Contents/Resources/AppIcon.icns')
run('codesign', '--force', '--sign', '-', '--entitlements', entitlements, EXT)
run('codesign', '--force', '--sign', '-', APP)
run('codesign', '--verify', '--deep', '--strict', APP)
# Keep the build copy out of LaunchServices; a second registration of the same bundle ID unregisters the widget.
subprocess.run([LSREGISTER, '-u', str(APP)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print(APP)
