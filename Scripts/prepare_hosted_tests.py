#!/usr/bin/env python3
"""为 SwiftPM 生成的测试包配置独立 UIKit 宿主；不修改原始 xctestrun。"""
import argparse
import plistlib
import shutil
import subprocess
from pathlib import Path


def prepare(source, host, destination, output):
    source, host, destination, output = map(Path, (source, host, destination, output))
    source, host, destination, output = (p.resolve() for p in (source, host, destination, output))
    products = source.parent

    def resolve(value):
        if isinstance(value, str):
            return value.replace('__TESTROOT__', str(products))
        if isinstance(value, list):
            return [resolve(item) for item in value]
        if isinstance(value, dict):
            return {key: resolve(item) for key, item in value.items()}
        return value

    run = resolve(plistlib.loads(source.read_bytes()))
    targets = [target for config in run['TestConfigurations'] for target in config['TestTargets']]
    if len(targets) != 1 or targets[0]['BlueprintName'] != 'StickyPagerKitTests':
        raise ValueError('预期根 Package 的唯一 StickyPagerKitTests target')
    target = targets[0]
    bundle = Path(target['TestBundlePath'])
    if not bundle.is_dir():
        raise FileNotFoundError(bundle)
    info = plistlib.loads((host / 'Info.plist').read_bytes())
    destination.mkdir(parents=True, exist_ok=False)
    app = destination / host.name
    shutil.copytree(host, app)
    embedded = app / 'PlugIns' / bundle.name
    shutil.copytree(bundle, embedded)
    # Package 测试包保持原签名，重新签名包含它的最外层模拟器宿主。
    subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
    target['TestHostPath'] = str(app)
    target['TestHostBundleIdentifier'] = info['CFBundleIdentifier']
    target['IsAppHostedTestBundle'] = True
    target['TestBundlePath'] = f'__TESTHOST__/PlugIns/{bundle.name}'
    target['DependentProductPaths'] = [str(app), str(embedded)]
    environment = target['TestingEnvironmentVariables']
    injection = '__PLATFORMS__/iPhoneSimulator.platform/Developer/usr/lib/libXCTestBundleInject.dylib'
    existing = environment.get('DYLD_INSERT_LIBRARIES', '').split(':')
    environment['DYLD_INSERT_LIBRARIES'] = ':'.join(dict.fromkeys([injection, *filter(None, existing)]))
    environment['XCInjectBundleInto'] = f"__TESTHOST__/{info['CFBundleExecutable']}"
    output.write_bytes(plistlib.dumps(run))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source')
    parser.add_argument('host')
    parser.add_argument('destination')
    parser.add_argument('output')
    args = parser.parse_args()
    prepare(args.source, args.host, args.destination, args.output)
