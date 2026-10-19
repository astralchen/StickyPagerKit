#!/bin/bash
# 框架、测试与独立 Demo 共用入口；额外参数（如 --lint）转发给 SwiftFormat。
set -euo pipefail
cd -P "$(dirname "$0")/.."
SP_FORMAT_ROOT="$PWD"

# 格式化工具运行在 macOS；覆盖 Xcode Build Phase 继承的 iOS SDK。
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

# 只选择一个 Package target，避免重复扫描；显式补入清单、测试和独立 Demo。
# Release 仅指格式化工具的编译配置，不改变框架和 Demo 的构建配置。
exec xcrun --sdk macosx swift package -c release plugin \
  --allow-writing-to-package-directory swiftformat \
  --target StickyPagerKit "$SP_FORMAT_ROOT/Package.swift" "$SP_FORMAT_ROOT/Tests" "$SP_FORMAT_ROOT/Examples" \
  --config "$SP_FORMAT_ROOT/.swiftformat" --cache ignore "$@"
