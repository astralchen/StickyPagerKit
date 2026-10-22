#!/usr/bin/env python3
"""运行显式外部旋转 UI 回归；本脚本只桥接文件，不合成输入或代替方向断言。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--xctestrun", required=True, type=Path)
    parser.add_argument("--device", required=True)
    parser.add_argument("--run-name", required=True)
    parser.add_argument("--only-testing", action="append", default=[])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    os.chdir(root)
    run = root / "Validation/Results" / args.run_name
    if Path(args.run_name).name != args.run_name:
        parser.error("run-name 必须是单层目录名")
    original = args.xctestrun.resolve()
    configuration = plistlib.loads(original.read_bytes())
    # Xcode 当前生成 v1；兼容 v2 的 TestConfigurations，不修改原始构建产物。
    targets = [t for c in configuration.get("TestConfigurations", []) for t in c["TestTargets"]]
    if not targets:
        targets = [v for k, v in configuration.items() if not k.startswith("__") and isinstance(v, dict)]
    target = next(t for t in targets if t.get("BlueprintName") == "StickyPagerDemoUITests")
    target.setdefault("EnvironmentVariables", {})["SP_UI_EXTERNAL_ROTATION"] = "1"
    bundle = target["TestHostBundleIdentifier"]

    def relocate(value):
        if isinstance(value, str):
            return value.replace("__TESTROOT__", str(original.parent))
        if isinstance(value, list):
            return [relocate(v) for v in value]
        if isinstance(value, dict):
            return {k: relocate(v) for k, v in value.items()}
        return value

    run.mkdir(exist_ok=False)
    copied = run / "ExternalRotation.xctestrun"
    copied.write_bytes(plistlib.dumps(relocate(configuration)))
    paths = [Path("Package.swift")]
    for folder in ["Sources", "Tests", "Examples", "Scripts"]:
        paths.extend(p for p in Path(folder).rglob("*") if p.is_file() and "xcuserdata" not in str(p)
                     and p.suffix in {".swift", ".pbxproj", ".xcscheme", ".xcconfig", ".xcworkspacedata", ".json", ".sh", ".py"})
    hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}
    (run / "source-hashes.json").write_text(json.dumps(hashes, indent=2))
    command = ["xcodebuild", "test-without-building", "-xctestrun", str(copied),
               "-destination", f"platform=iOS Simulator,id={args.device}",
               "-resultBundlePath", str(run / "Result.xcresult"),
               "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never"]
    command += [f"-only-testing:{test}" for test in args.only_testing]
    (run / "command.json").write_text(json.dumps(command, indent=2))
    with (run / "toolchain.txt").open("w") as output:
        subprocess.run(["xcodebuild", "-version"], stdout=output, check=True)
        subprocess.run(["xcrun", "swift", "--version"], stdout=output, check=True)
    print(f"外部旋转文件目录：{run}", flush=True)
    documents = None
    last_request = None
    last_response = None
    with (run / "xcodebuild.log").open("w") as output, (run / "rotation-events.jsonl").open("w") as events:
        started = time.time()
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                if documents is None or not documents.exists():
                    container = subprocess.run(["xcrun", "simctl", "get_app_container", args.device, bundle, "data"],
                                               capture_output=True, text=True, timeout=20)
                    if container.returncode == 0:
                        documents = Path(container.stdout.strip()) / "Documents"
                if documents is not None:
                    try:
                        request_file = documents / "rotation-request.json"
                        if request_file.stat().st_mtime < started:
                            time.sleep(0.5)
                            continue
                        request = json.loads(request_file.read_text())
                        if request != last_request:
                            (run / "rotation-request.json").write_text(json.dumps(request))
                            events.write(json.dumps({"time": time.time(), "request": request}) + "\n")
                            events.flush()
                            print(f"等待电脑操作：{request}", flush=True)
                            last_request = request
                        response = json.loads((run / "rotation-response.json").read_text())
                        if response == request and response != last_response:
                            temporary = documents / "rotation-response.tmp"
                            temporary.write_text(json.dumps(response))
                            temporary.replace(documents / "rotation-response.json")
                            events.write(json.dumps({"time": time.time(), "response": response}) + "\n")
                            events.flush()
                            last_response = response
                    except (FileNotFoundError, json.JSONDecodeError):
                        pass
                time.sleep(0.5)
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=30)
    (run / "exit-code.txt").write_text(str(process.returncode))
    print(f"xcodebuild 终态退出码：{process.returncode}", flush=True)
    raise SystemExit(process.returncode)


if __name__ == "__main__":
    main()
