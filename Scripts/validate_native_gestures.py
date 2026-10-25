#!/usr/bin/env python3
"""复用 Demo build-for-testing 产物，以 serve-sim 0.1.48 执行连续折返触摸。

先为 SP_SIMULATOR_ID 启动 serve-sim，再传入 xctestrun 与新的证据目录。
桥接只生成 HID 输入；断言仍由 Demo UI 测试执行，失败不重试。
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
source, evidence = (Path(p).resolve() for p in sys.argv[1:3])
device = os.environ['SP_SIMULATOR_ID']
state = Path(os.environ.get('TMPDIR', '/tmp')) / 'serve-sim' / f'server-{device}.json'
bridge = json.loads(state.read_text())
assert bridge['device'] == device
assert bridge['wsUrl'].startswith('ws://127.0.0.1:')
os.kill(bridge['pid'], 0)
evidence.mkdir(parents=True, exist_ok=False)
os.environ['DEVELOPER_DIR'] = os.environ['SP_DEVELOPER_DIR']

def relocate(value):
    if isinstance(value, str):
        return value.replace('__TESTROOT__', str(source.parent))
    if isinstance(value, list):
        return [relocate(v) for v in value]
    if isinstance(value, dict):
        return {k: relocate(v) for k, v in value.items()}
    return value

config = relocate(plistlib.loads(source.read_bytes()))
if 'TestConfigurations' in config:
    targets = [target for c in config['TestConfigurations'] for target in c['TestTargets']]
else:
    targets = [target for target in config.values() if isinstance(target, dict) and 'TestBundlePath' in target]
for target in targets:
    target.setdefault('EnvironmentVariables', {})['SP_SIM_HID_WS'] = bridge['wsUrl']
    if target.get('BlueprintName') == 'StickyPagerDemoUITests':
        target['OnlyTestIdentifiers'] = [
            'StickyPagerDemoUITests/testSystemSplitReversingNativePaging',
            'StickyPagerDemoUITests/testSystemSplitWindowsRTLReversingNativePaging',
        ]
prepared = evidence / 'NativeGestures.xctestrun'
prepared.write_bytes(plistlib.dumps(config))
(evidence / 'bridge.json').write_text(json.dumps({'version': '0.1.48', 'device': device, 'wsUrl': bridge['wsUrl']}, indent=2))
paths = [root / 'Package.swift']
for folder in ['Sources', 'Tests', 'Examples', 'Scripts']:
    paths.extend(p for p in (root / folder).rglob('*') if p.is_file() and 'xcuserdata' not in str(p)
                 and p.suffix in {'.swift', '.pbxproj', '.xcscheme', '.xcconfig', '.xcworkspacedata', '.json', '.sh', '.py'})
(evidence / 'source-hashes.json').write_text(json.dumps({str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}, indent=2))
with (evidence / 'toolchain.txt').open('w') as log:
    subprocess.run(['xcodebuild', '-version'], stdout=log, stderr=subprocess.STDOUT, check=True)
    subprocess.run(['xcrun', 'swift', '--version'], stdout=log, stderr=subprocess.STDOUT, check=True)
with (evidence / 'xcodebuild.log').open('w') as log:
    result = subprocess.run([
        'xcodebuild', 'test-without-building', '-xctestrun', str(prepared),
        '-destination', f'platform=iOS Simulator,id={device}', '-parallel-testing-enabled', 'NO',
        '-collect-test-diagnostics', 'never', '-resultBundlePath', str(evidence / 'Result.xcresult'),
        '-only-testing:StickyPagerDemoUITests',
    ], cwd=root, stdout=log, stderr=subprocess.STDOUT)
diagnostics = subprocess.run([sys.executable, str(root / 'Scripts/check_runtime_diagnostics.py'), str(evidence)], cwd=root)
# xcodebuild 可能在过滤未命中时返回成功，必须确认两项实际执行且无 skip。
summary = subprocess.run(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path',
                          str(evidence / 'Result.xcresult'), '--format', 'json'], capture_output=True, text=True)
verified = False
if summary.returncode == 0:
    counts = json.loads(summary.stdout)
    (evidence / 'test-counts.json').write_text(summary.stdout)
    verified = counts.get('totalTestCount') == 2 and counts.get('passedTests') == 2 and counts.get('skippedTests') == 0
sys.exit(result.returncode or diagnostics.returncode or (0 if verified else 1))
