#!/bin/bash
# 指定工具链、设备和独立结果目录；不修改全局 xcode-select。
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${SP_DEVELOPER_DIR:-/Applications/Xcode-26.6.app/Contents/Developer}"
SP_DEVICE="${SP_SIMULATOR_ID:-294027E9-350F-4CA3-8B9F-222AA5281556}"
SP_RUN="${SP_RUN_NAME:-$(date +%Y%m%d-%H%M%S)}"
SP_CONFIGURATION="${SP_CONFIGURATION:-Debug}"
SP_SCOPE="${SP_SCOPE:-demo}"
case "$SP_SCOPE" in
  demo) SP_INPUT=(-project Examples/StickyPagerDemo/StickyPagerDemo.xcodeproj -scheme StickyPagerDemo) ;;
  library) SP_INPUT=(-scheme StickyPagerKit) ;;
  *) printf '未知 SP_SCOPE：%s；请使用 demo 或 library。\n' "$SP_SCOPE" >&2; exit 2 ;;
esac
SP_ACTION="${1:-test}"
shift || true
SP_EVIDENCE="Validation/Results/$SP_RUN"
mkdir -p "$SP_EVIDENCE"
xcrun swift --version > "$SP_EVIDENCE/toolchain.txt" 2>&1
xcodebuild -version >> "$SP_EVIDENCE/toolchain.txt"
python3 - "$SP_EVIDENCE" <<'PY'
import hashlib, json, sys
from pathlib import Path
paths = [Path('Package.swift')]
for folder in ['Sources', 'Tests', 'Examples', 'Scripts']:
    paths.extend(p for p in Path(folder).rglob('*') if p.is_file() and 'xcuserdata' not in str(p) and p.suffix in {'.swift','.pbxproj','.xcscheme','.xcconfig','.xcworkspacedata','.json','.sh','.py'})
Path(sys.argv[1], 'source-hashes.json').write_text(json.dumps({str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}, indent=2))
PY
xcodebuild "$SP_ACTION" "${SP_INPUT[@]}" -configuration "$SP_CONFIGURATION" \
  -destination "platform=iOS Simulator,id=$SP_DEVICE" \
  -derivedDataPath "Validation/Products/$(basename "$(dirname "$(dirname "$DEVELOPER_DIR")")")-$SP_CONFIGURATION-$SP_SCOPE" \
  -resultBundlePath "$SP_EVIDENCE/Result.xcresult" \
  -parallel-testing-enabled NO -collect-test-diagnostics never ONLY_ACTIVE_ARCH=YES "$@" > "$SP_EVIDENCE/xcodebuild.log" 2>&1
printf '%s\n' "Result: $SP_EVIDENCE/Result.xcresult"
