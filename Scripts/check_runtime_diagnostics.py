#!/usr/bin/env python3
"""独立记录 UIKit observation、appearance 与内容视图替换诊断；XCTest 通过不能覆盖运行时诊断失败。"""
import json
import sys
from pathlib import Path


MARKER = 'Observation tracking feedback loop detected!'
CONTENT_MARKER = 'existing content view does not support the new configuration'
APPEARANCE_MARKER = 'Unbalanced calls to begin/end appearance transitions'


def diagnostics(log):
    lines = [number for number, line in enumerate(log.splitlines(), 1) if MARKER in line]
    appearance = [number for number, line in enumerate(log.splitlines(), 1) if APPEARANCE_MARKER in line]
    replacements = [number for number, line in enumerate(log.splitlines(), 1) if CONTENT_MARKER in line]
    return {'observationFeedbackLoopCount': len(lines), 'lineNumbers': lines,
            'unbalancedAppearanceCount': len(appearance), 'appearanceLineNumbers': appearance,
            'contentViewReplacementCount': len(replacements), 'contentViewReplacementLineNumbers': replacements,
            'status': 'failed' if lines or appearance or replacements else 'passed'}


if __name__ == '__main__':
    run = Path(sys.argv[1])
    result = diagnostics((run / 'xcodebuild.log').read_text())
    (run / 'runtime-diagnostics.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    sys.exit(1 if result['status'] == 'failed' else 0)
