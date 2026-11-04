#!/usr/bin/env python3
"""P5C1：冻结当前 Release 产物，串行采样四批，并独立判定 A/A 重复性。"""
import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import plistlib
import shutil
import statistics
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
TESTS = ('testAFramesFirst', 'testBFramesSecond', 'testIFlushedFirst', 'testJFlushedSecond')
ORDER = (False, True, True, False)
SCHEMA = 'sp-color-repeatability-v1'


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_hashes(root):
    return {str(p.relative_to(root)): digest(p) for p in sorted(root.rglob('*')) if p.is_file()}


def source_hashes():
    paths = [ROOT / 'Package.swift']
    for folder in ('Sources', 'Tests', 'Examples', 'Scripts'):
        paths.extend(p for p in (ROOT / folder).rglob('*') if p.is_file() and 'xcuserdata' not in str(p)
                     and p.suffix in {'.swift', '.pbxproj', '.xcscheme', '.xcconfig', '.xcworkspacedata', '.json', '.sh', '.py'})
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(paths)}


def capture(command, environment):
    return subprocess.check_output(command, env=environment, text=True).strip()


def device_info(device, environment):
    inventory = json.loads(capture(['xcrun', 'simctl', 'list', 'devices', 'available', '--json'], environment))
    for runtime, devices in inventory['devices'].items():
        for item in devices:
            if item['udid'] == device:
                return {'runtime': runtime, 'udid': device, 'name': item['name'],
                        'deviceTypeIdentifier': item['deviceTypeIdentifier']}
    raise ValueError('目标模拟器不可用。')


def target(run):
    configurations = run['TestConfigurations']
    if len(configurations) != 1 or len(configurations[0]['TestTargets']) != 1:
        raise ValueError('只接受单一配置、单一库测试 target。')
    value = configurations[0]['TestTargets'][0]
    if value['BlueprintName'] != 'StickyPagerKitTests' or not value.get('IsAppHostedTestBundle'):
        raise ValueError('需要独立 UIKit 宿主的 StickyPagerKitTests。')
    return value


def replace_paths(value, replacements):
    if isinstance(value, str):
        for old, new in replacements:
            value = value.replace(old, new)
        return value
    if isinstance(value, dict):
        return {k: replace_paths(v, replacements) for k, v in value.items()}
    if isinstance(value, list):
        return [replace_paths(v, replacements) for v in value]
    return value


def prepare(build, experiment, device, developer, max_rsd, max_spread):
    # 在任何采样之前固定预算；这是实验重复性门槛，不是产品性能 SLA。
    if any(not math.isfinite(v) or v <= 0 for v in (max_rsd, max_spread)):
        raise ValueError('重复性阈值必须是有限正数。')
    environment = {**os.environ, 'DEVELOPER_DIR': str(developer)}
    sources = source_hashes()
    if read(build / 'source-hashes.json') != sources:
        raise ValueError('构建输入与当前源码不一致，不能建立当前版本基线。')
    if '** TEST BUILD SUCCEEDED **' not in (build / 'xcodebuild.log').read_text():
        raise ValueError('缺少成功的 build-for-testing 终态。')
    version = capture(['xcodebuild', '-version'], environment)
    if version not in (build / 'toolchain.txt').read_text():
        raise ValueError('构建与采样的 Xcode 版本不同。')
    original = plistlib.loads((build / 'Hosted.xctestrun').read_bytes())
    value = target(original)
    host = Path(value['TestHostPath'])
    products = Path(value['TestingEnvironmentVariables']['__XCODE_BUILT_PRODUCTS_DIR_PATHS'])
    if products.name != 'Release-iphonesimulator' or not host.is_dir() or not products.is_dir():
        raise ValueError('需要存在的 Release 模拟器宿主及构建产物。')
    identity = device_info(device, environment)
    experiment.mkdir(parents=True, exist_ok=False)
    artifacts = experiment / 'artifacts'
    artifacts.mkdir()
    # 同时冻结 DYLD 搜索路径中的构建产物，避免后续构建替换依赖。
    shutil.copytree(host, artifacts / 'Host.app')
    shutil.copytree(products, artifacts / 'Products')
    original = replace_paths(original, [(str(host), str(artifacts / 'Host.app')),
                                        (str(products), str(artifacts / 'Products'))])
    for index, reverse in enumerate(ORDER, 1):
        run = plistlib.loads(plistlib.dumps(original))
        value = target(run)
        value['OnlyTestIdentifiers'] = [f'SPTabBarColorPerformanceTests/{name}' for name in TESTS]
        value.pop('SkipTestIdentifiers', None)
        for key in ('EnvironmentVariables', 'TestingEnvironmentVariables'):
            value.setdefault(key, {}).update(SP_TAB_COLOR_PROFILE='0', SP_TAB_COLOR_REVERSE=str(int(reverse)))
        (artifacts / f'{index}.xctestrun').write_bytes(plistlib.dumps(run))
    write(experiment / 'protocol.json', {
        'schema': SCHEMA, 'createdAt': datetime.now(timezone.utc).isoformat(),
        'revision': capture(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], environment),
        'workingTree': capture(['git', '-C', str(ROOT), 'status', '--short'], environment),
        'buildRun': str(build), 'developerDir': str(developer), 'xcodeVersion': version,
        'device': identity, 'configuration': 'Release', 'tests': list(TESTS),
        'reversedOrder': list(ORDER), 'samplesPerTest': 10, 'profiling': False,
        'maxWithinBatchRSDPercent': max_rsd, 'maxBetweenBatchSpreadPercent': max_spread,
        'sourceHashes': sources, 'artifactHashes': tree_hashes(artifacts),
        'contract': 'P5A 原夹具；6 项、LTR、浅色、红蓝端点；Frames/Flushed 各 360 手动进度点。四批同产物 A/A，不推导 FPS、分配或版本收益。',
    })
    print(f'已固定四批协议：{experiment}')


def verify(experiment, protocol, environment):
    if source_hashes() != protocol['sourceHashes']:
        raise ValueError('采样期间源码输入发生变化。')
    if tree_hashes(experiment / 'artifacts') != protocol['artifactHashes']:
        raise ValueError('冻结产物或 xctestrun 发生变化。')
    if capture(['xcodebuild', '-version'], environment) != protocol['xcodeVersion']:
        raise ValueError('Xcode 工具链发生变化。')
    if device_info(protocol['device']['udid'], environment) != protocol['device']:
        raise ValueError('目标设备身份发生变化。')


def load_protocol(experiment):
    protocol = read(experiment / 'protocol.json')
    if (protocol['schema'] != SCHEMA or protocol['reversedOrder'] != list(ORDER)
            or protocol['tests'] != list(TESTS) or protocol['samplesPerTest'] != 10
            or protocol['profiling'] is not False or protocol['configuration'] != 'Release'):
        raise ValueError('不支持的采样协议。')
    for key in ('maxWithinBatchRSDPercent', 'maxBetweenBatchSpreadPercent'):
        if type(protocol[key]) not in (int, float) or not math.isfinite(protocol[key]) or protocol[key] <= 0:
            raise ValueError('重复性阈值必须是有限正数。')
    return protocol


def read_batch(run, reverse, device):
    summary = read(run / 'summary.json')
    tests = summary.get('tests', {})
    if (summary.get('sourceChangedSinceRun') != [] or tests.get('result') != 'Passed'
            or tests.get('passedTests') != 4 or tests.get('failedTests') != 0
            or tests.get('skippedTests') != 0 or tests.get('expectedFailures') != 0
            or tests.get('totalTestCount') != 4 or tests.get('runtimeWarnings') != []
            or summary.get('runtimeDiagnostics', {}).get('status') != 'passed'):
        raise ValueError('测试终态、源码一致性、运行时警告或诊断不满足采样契约。')
    destinations = tests.get('devicesAndConfigurations', [])
    if len(destinations) != 1 or destinations[0]['device']['deviceId'] != device:
        raise ValueError('结果中的运行设备与协议不符。')
    rows, seen = [], set()
    for entry in read(run / 'metrics/manifest.json'):
        identifier = entry['testIdentifier'].removesuffix('()')
        prefix, name = identifier.split('/')
        if prefix != 'SPTabBarColorPerformanceTests' or name not in TESTS or name in seen:
            raise ValueError('未知、重复或越界的性能指标。')
        seen.add(name)
        filename = entry['metricsFileName']
        if Path(filename).name != filename:
            raise ValueError('指标文件路径越界。')
        path = run / 'metrics' / filename
        if not path.exists() and filename.endswith('.csv.csv'):
            path = path.with_suffix('')
        with path.open(newline='') as handle:
            records = list(csv.DictReader(handle))
        if len(records) != 1:
            raise ValueError('每个测试必须只有一行环境指标。')
        record = records[0]
        if record['Clock Monotonic Time (Average)'].split()[-1] != 's':
            raise ValueError('墙钟单位必须为秒。')
        samples = json.loads(record['Clock Monotonic Time (Iterations)'])
        if len(samples) != 10 or any(type(v) not in (int, float) or not math.isfinite(v) or v <= 0 for v in samples):
            raise ValueError('需要十个有限正数墙钟样本；不接受 profiling 或缺失样本。')
        mean = statistics.mean(samples)
        rows.append({'test': name, 'path': 'Frames' if 'Frames' in name else 'Flushed',
                     'colors': name.endswith('Second') != reverse,
                     'destination': record['Destination'], 'configuration': record['Configuration'],
                     'samplesSeconds': samples, 'meanSeconds': mean,
                     'medianSeconds': statistics.median(samples),
                     'relativeSDPercent': statistics.stdev(samples) / mean * 100})
    if seen != set(TESTS):
        raise ValueError('缺少颜色开关或工作路径对照。')
    return rows, destinations[0]


def assess(batches, max_rsd, max_spread):
    if len(batches) != 4:
        raise ValueError('必须完成预先声明的四批，不以部分结果判定。')
    if len({(row['destination'], row['configuration']) for batch in batches for row in batch}) != 1:
        raise ValueError('不可混合不同设备或测试配置。')
    groups = []
    for path in ('Frames', 'Flushed'):
        for colors in (False, True):
            rows = []
            for batch in batches:
                selected = [r for r in batch if r['path'] == path and r['colors'] == colors]
                if len(selected) != 1:
                    raise ValueError('每批必须恰有一个相同工作量。')
                rows.extend(selected)
            means = [r['meanSeconds'] for r in rows]
            spread = (max(means) - min(means)) / statistics.median(means) * 100
            worst_rsd = max(r['relativeSDPercent'] for r in rows)
            groups.append({'path': path, 'colors': colors, 'batchMeansSeconds': means,
                           'betweenBatchSpreadPercent': spread, 'maxWithinBatchRSDPercent': worst_rsd,
                           'stable': spread <= max_spread and worst_rsd <= max_rsd})
    return {'status': 'stable' if all(g['stable'] for g in groups) else 'unstable', 'groups': groups,
            'note': '稳定仅指本协议阈值内的 A/A 重复性；不代表提速、严格无回退、FPS、真机或发布预算达标。'}


def summarize(experiment):
    protocol = load_protocol(experiment)
    execution = read(experiment / 'execution.json')
    if execution['protocolSHA256'] != digest(experiment / 'protocol.json') or execution['status'] != 'completed':
        raise ValueError('协议变化或执行不完整。')
    batches, identities = [], []
    for index, reverse in enumerate(ORDER, 1):
        run = experiment / f'batch-{index}'
        audit = read(run / 'audit.json')
        if (audit.get('verifiedBefore') is not True or audit.get('verifiedAfter') is not True
                or audit.get('exitCode') != 0 or audit.get('protocolSHA256') != execution['protocolSHA256']):
            raise ValueError('缺少完整的批次产物核验。')
        if tree_hashes(run / 'metrics') != audit['metricsHashes'] or digest(run / 'summary.json') != audit['summarySHA256']:
            raise ValueError('采样后的摘要或原始指标发生变化。')
        rows, identity = read_batch(run, reverse, protocol['device']['udid'])
        batches.append(rows)
        identities.append(identity)
    if any(identity != identities[0] for identity in identities):
        raise ValueError('批次设备系统或测试配置不一致。')
    report = assess(batches, protocol['maxWithinBatchRSDPercent'], protocol['maxBetweenBatchSpreadPercent'])
    report.update(schema=SCHEMA, protocolSHA256=execution['protocolSHA256'], batches=batches)
    write(experiment / 'repeatability.json', report)
    lines = ['# 默认连续颜色 A/A 重复性', '', f"结论：{report['status']}。{report['note']}", '',
             '| 路径 | 颜色 | 四批均值 ms | 最大批内 RSD | 批间跨度 / 均值中位数 |',
             '| --- | --- | --- | --- | --- |']
    for group in report['groups']:
        means = ' / '.join(f'{v * 1000:.2f}' for v in group['batchMeansSeconds'])
        lines.append(f"| {group['path']} | {'开' if group['colors'] else '关'} | {means} | "
                     f"{group['maxWithinBatchRSDPercent']:.2f}% | {group['betweenBatchSpreadPercent']:.2f}% |")
    (experiment / 'repeatability.md').write_text('\n'.join(lines) + '\n')
    print('\n'.join(lines))
    return 0 if report['status'] == 'stable' else 3


def execute(experiment):
    protocol = load_protocol(experiment)
    environment = {**os.environ, 'DEVELOPER_DIR': protocol['developerDir']}
    state = {'protocolSHA256': digest(experiment / 'protocol.json'), 'status': 'running'}
    # 不覆盖、不续跑已有实验，避免删掉失败或选择性补样本。
    with (experiment / 'execution.json').open('x') as handle:
        json.dump(state, handle)
    try:
        for index, reverse in enumerate(ORDER, 1):
            print(f'开始串行批次 {index}/4，反向颜色顺序={reverse}', flush=True)
            verify(experiment, protocol, environment)
            run = experiment / f'batch-{index}'
            run.mkdir()
            write(run / 'source-hashes.json', protocol['sourceHashes'])
            write(run / 'sampling-contract.json', {'reversed': reverse, 'profiling': False})
            audit = {'protocolSHA256': state['protocolSHA256'], 'verifiedBefore': True,
                     'startedAt': datetime.now(timezone.utc).isoformat()}
            write(run / 'audit.json', audit)
            command = ['xcodebuild', 'test-without-building', '-xctestrun', str(experiment / 'artifacts' / f'{index}.xctestrun'),
                       '-destination', f"platform=iOS Simulator,id={protocol['device']['udid']}",
                       '-resultBundlePath', str(run / 'Result.xcresult'), '-parallel-testing-enabled', 'NO',
                       '-collect-test-diagnostics', 'never', '-jobs', '2', '-scmProvider', 'system']
            write(run / 'command.json', command)
            with (run / 'xcodebuild.log').open('w') as log:
                result = subprocess.run(command, env=environment, stdout=log, stderr=subprocess.STDOUT)
            audit['exitCode'] = result.returncode
            audit['finishedAt'] = datetime.now(timezone.utc).isoformat()
            write(run / 'audit.json', audit)
            with (run / 'summary-output.txt').open('w') as log:
                subprocess.run([sys.executable, str(ROOT / 'Scripts/summarize_validation.py'), str(run)],
                               env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
            verify(experiment, protocol, environment)
            if digest(experiment / 'protocol.json') != state['protocolSHA256']:
                raise ValueError('运行期间协议被修改。')
            audit['verifiedAfter'] = True
            write(run / 'audit.json', audit)
            if result.returncode:
                raise ValueError(f'批次 {index} 失败；保留证据，不自动重试。')
            with (run / 'metrics-export.log').open('w') as log:
                subprocess.run(['xcrun', 'xcresulttool', 'export', 'metrics', '--path', str(run / 'Result.xcresult'),
                                '--output-path', str(run / 'metrics')], env=environment,
                               stdout=log, stderr=subprocess.STDOUT, check=True)
            read_batch(run, reverse, protocol['device']['udid'])
            audit.update(metricsHashes=tree_hashes(run / 'metrics'), summarySHA256=digest(run / 'summary.json'))
            write(run / 'audit.json', audit)
        state['status'] = 'completed'
    except (Exception, KeyboardInterrupt) as error:
        state.update(status='incomplete', error=str(error))
        raise
    finally:
        write(experiment / 'execution.json', state)
    return summarize(experiment)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    setup = commands.add_parser('prepare', help='在采样前冻结产物和固定协议')
    setup.add_argument('build_run', type=Path)
    setup.add_argument('experiment', type=Path)
    setup.add_argument('--device', required=True)
    setup.add_argument('--developer-dir', required=True, type=Path)
    setup.add_argument('--max-rsd-percent', required=True, type=float)
    setup.add_argument('--max-spread-percent', required=True, type=float)
    for name in ('run', 'summarize'):
        commands.add_parser(name).add_argument('experiment', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'prepare':
            prepare(args.build_run.resolve(), args.experiment.resolve(), args.device, args.developer_dir.resolve(),
                    args.max_rsd_percent, args.max_spread_percent)
            return 0
        return (execute if args.command == 'run' else summarize)(args.experiment.resolve())
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f'证据无效或未完成：{error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
