#!/usr/bin/env python3
"""读取终态 xcresult 并校验本次运行对应的源码；不把构建成功误报为测试通过。"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from check_runtime_diagnostics import diagnostics

root = Path(__file__).resolve().parents[1]
run = Path(sys.argv[1]).resolve()
recorded = json.loads((run / 'source-hashes.json').read_text())
changed = [name for name, digest in recorded.items() if not (root / name).is_file() or hashlib.sha256((root / name).read_bytes()).hexdigest() != digest]
current = {'Package.swift'}
for folder in ['Sources', 'Tests', 'Examples', 'Scripts']:
    current.update(str(p.relative_to(root)) for p in (root / folder).rglob('*')
                   if p.is_file() and 'xcuserdata' not in str(p)
                   and p.suffix in {'.swift', '.pbxproj', '.xcscheme', '.xcconfig', '.xcworkspacedata', '.json', '.sh', '.py'})
changed = sorted(set(changed) | (current - recorded.keys()))
log = (run / 'xcodebuild.log').read_text()
summary = {'run': str(run.relative_to(root)), 'sourceChangedSinceRun': changed,
           'runtimeDiagnostics': diagnostics(log)}
result = subprocess.run(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(run / 'Result.xcresult'), '--format', 'json'], capture_output=True, text=True)
if result.returncode == 0:
    summary['tests'] = json.loads(result.stdout)
else:
    summary['terminalMarker'] = next((marker for marker in ['** TEST EXECUTE FAILED **', '** TEST FAILED **', '** TEST EXECUTE SUCCEEDED **', '** TEST SUCCEEDED **', '** TEST BUILD SUCCEEDED **', '** BUILD SUCCEEDED **', '** BUILD FAILED **'] if marker in log), None)
    summary['summaryError'] = result.stderr.strip()
    summary['testSummaryUnavailable'] = True
(run / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(summary, ensure_ascii=False, indent=2))
