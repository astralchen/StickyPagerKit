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
SP_DERIVED="Validation/Products/$(basename "$(dirname "$(dirname "$DEVELOPER_DIR")")")-$SP_CONFIGURATION-$SP_SCOPE"
SP_STATUS=0
if [[ "$SP_SCOPE" == library && ( "$SP_ACTION" == test || "$SP_ACTION" == build-for-testing ) ]]; then
  # SwiftPM 的默认 xctest 进程没有 UIApplication。先生成原测试包，再通过
  # xctestrun 的 application host 配置运行；不把库测试加入 Demo 工程。
  SP_HOST_DERIVED="Validation/Products/UIKitTestHost-$SP_CONFIGURATION"
  xcodebuild build -project Tests/UIKitTestHost/UIKitTestHost.xcodeproj -scheme UIKitTestHost \
    -configuration "$SP_CONFIGURATION" -destination "platform=iOS Simulator,id=$SP_DEVICE" \
    -derivedDataPath "$SP_HOST_DERIVED" ONLY_ACTIVE_ARCH=YES > "$SP_EVIDENCE/host-build.log" 2>&1
  xcodebuild build-for-testing "${SP_INPUT[@]}" -configuration "$SP_CONFIGURATION" \
    -destination "platform=iOS Simulator,id=$SP_DEVICE" -derivedDataPath "$SP_DERIVED" \
    -resultBundlePath "$SP_EVIDENCE/Build.xcresult" -parallel-testing-enabled NO \
    -collect-test-diagnostics never ONLY_ACTIVE_ARCH=YES "$@" > "$SP_EVIDENCE/xcodebuild.log" 2>&1
  SP_XCTESTRUN="$(python3 - "$SP_DERIVED/Build/Products" <<'PYRUN'
import sys
from pathlib import Path
paths = list(Path(sys.argv[1]).glob('StickyPagerKit_*.xctestrun'))
if not paths:
    raise SystemExit('Package 未生成 xctestrun')
print(max(paths, key=lambda path: path.stat().st_mtime).resolve())
PYRUN
)"
  python3 Scripts/prepare_hosted_tests.py "$SP_XCTESTRUN" \
    "$SP_HOST_DERIVED/Build/Products/$SP_CONFIGURATION-iphonesimulator/UIKitTestHost.app" \
    "Validation/Products/LibraryHosted/$SP_RUN" "$SP_EVIDENCE/Hosted.xctestrun" \
    >> "$SP_EVIDENCE/xcodebuild.log" 2>&1
  if [[ "$SP_ACTION" == test ]]; then
    xcodebuild test-without-building -xctestrun "$SP_EVIDENCE/Hosted.xctestrun" \
      -destination "platform=iOS Simulator,id=$SP_DEVICE" -resultBundlePath "$SP_EVIDENCE/Result.xcresult" \
      -parallel-testing-enabled NO -collect-test-diagnostics never "$@" \
      >> "$SP_EVIDENCE/xcodebuild.log" 2>&1 || SP_STATUS=$?
  fi
else
  xcodebuild "$SP_ACTION" "${SP_INPUT[@]}" -configuration "$SP_CONFIGURATION" \
    -destination "platform=iOS Simulator,id=$SP_DEVICE" -derivedDataPath "$SP_DERIVED" \
    -resultBundlePath "$SP_EVIDENCE/Result.xcresult" -parallel-testing-enabled NO \
    -collect-test-diagnostics never ONLY_ACTIVE_ARCH=YES "$@" > "$SP_EVIDENCE/xcodebuild.log" 2>&1 || SP_STATUS=$?
fi
# 保留 XCTest 原始退出码与日志；即便 XCTest 通过，feedback loop 或 appearance 不平衡也使验证失败。
python3 Scripts/check_runtime_diagnostics.py "$SP_EVIDENCE" || { if [[ "$SP_STATUS" == 0 ]]; then SP_STATUS=1; fi; }
printf '%s\n' "Evidence: $SP_EVIDENCE"
exit "$SP_STATUS"
