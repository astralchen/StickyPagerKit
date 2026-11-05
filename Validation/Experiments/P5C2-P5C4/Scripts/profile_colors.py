#!/usr/bin/env python3
"""P5C2 单次独立采集：测试握手后附加 Instruments，固定负载结束后停止采集。"""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET
# 归档入口显式复用仓库正式采样工具；不依赖调用者的工作目录。
sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "Scripts"))
from color_repeatability import ROOT, capture, device_info, digest, read, replace_paths, source_hashes, target, tree_hashes, write


def wait_until(check, processes, timeout=180):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        if any(process.poll() is not None for process in processes):
            raise RuntimeError('握手完成前子进程已退出。')
        time.sleep(0.2)
    raise TimeoutError('采集握手超时。')


def recording_started(log):
    # xctrace 可能先报告断连，再打印 Ctrl-C 提示并以 0 退出。
    # 不能仅凭提示行释放工作负载；终态仍需核对 trace 的实际覆盖。
    if 'Device got disconnected' in log:
        raise RuntimeError('采集器已报告设备断连，拒绝释放工作负载。')
    return 'Ctrl-C to stop' in log


def profile(build, run, device, developer, template, test, platform='simulator'):
    environment = {**os.environ, 'DEVELOPER_DIR': str(developer)}
    sources = source_hashes()
    if sources != read(build / 'source-hashes.json'):
        raise ValueError('当前输入与构建记录不一致。')
    if '** TEST BUILD SUCCEEDED **' not in (build / 'xcodebuild.log').read_text():
        raise ValueError('需要成功的 build-for-testing。')
    toolchain = capture(['xcodebuild', '-version'], environment)
    if toolchain not in (build / 'toolchain.txt').read_text():
        raise ValueError('构建与采样工具链不同。')
    configuration = plistlib.loads((build / 'Hosted.xctestrun').read_bytes())
    value = target(configuration)
    host = Path(value['TestHostPath'])
    products = Path(value['TestingEnvironmentVariables']['__XCODE_BUILT_PRODUCTS_DIR_PATHS'])
    expected_products = 'Release-iphoneos' if platform == 'device' else 'Release-iphonesimulator'
    if products.name != expected_products:
        raise ValueError(f'只接受 {expected_products} 产物。')
    identity = ({'udid': device, 'platform': 'iOS', 'details': capture(
        ['xcrun', 'devicectl', 'device', 'info', 'details', '--device', device], environment)}
        if platform == 'device' else device_info(device, environment))
    run.mkdir(parents=True, exist_ok=False)
    artifacts = run / 'artifacts'
    artifacts.mkdir()
    frozen_host = artifacts / (host.name if platform == 'device' else 'Host.app')
    shutil.copytree(host, frozen_host)
    shutil.copytree(products, artifacts / 'Products')
    configuration = replace_paths(configuration, [(str(host), str(frozen_host)),
                                                   (str(products), str(artifacts / 'Products'))])
    value = target(configuration)
    value['OnlyTestIdentifiers'] = [f'SPTabBarColorAttributionTests/{test}']
    value.pop('SkipTestIdentifiers', None)
    token = uuid.uuid4().hex
    for key in ('EnvironmentVariables', 'TestingEnvironmentVariables'):
        value.setdefault(key, {}).update(SP_P5C2_HANDSHAKE='1', SP_P5C2_TOKEN=token)
    (artifacts / 'Hosted.xctestrun').write_bytes(plistlib.dumps(configuration))
    frozen = tree_hashes(artifacts)
    write(run / 'source-hashes.json', sources)
    write(run / 'protocol.json', {'schema': 'sp-color-profile-v1', 'template': template, 'test': test,
                                 'device': identity, 'toolchain': toolchain, 'token': token,
                                 'artifacts': frozen, 'sourceBuild': str(build)})
    command = ['xcodebuild', 'test-without-building', '-xctestrun', str(artifacts / 'Hosted.xctestrun'),
               '-destination', f'platform={"iOS" if platform == "device" else "iOS Simulator"},id={device}', '-resultBundlePath', str(run / 'Result.xcresult'),
               '-parallel-testing-enabled', 'NO', '-collect-test-diagnostics', 'never', '-jobs', '2', '-scmProvider', 'system']
    write(run / 'command.json', command)
    state = {'status': 'running'}
    trace_process, folder = None, None
    # 真机通过公开 devicectl 文件服务握手；不读取设备内部文件系统或修改被测实现。
    remote = f'tmp/sp-p5c2/{token}'
    transfer_log = run / 'device-transfer.log'

    def transfer(direction, name):
        local = run / 'handshake' / name
        local.parent.mkdir(exist_ok=True)
        if direction == 'to':
            local.touch()
        source, destination = ((str(local), f'{remote}/{name}') if direction == 'to'
                               else (f'{remote}/{name}', str(local)))
        command = ['xcrun', 'devicectl', 'device', 'copy', direction, '--device', device,
                   '--source', source, '--destination', destination, '--domain-type', 'appDataContainer',
                   '--domain-identifier', value['TestHostBundleIdentifier'], '--timeout', '10']
        with transfer_log.open('a') as output:
            result = subprocess.run(command, env=environment, stdout=output, stderr=subprocess.STDOUT)
        return local if result.returncode == 0 else None

    def notify(name):
        if platform == 'device':
            if not transfer('to', name):
                raise RuntimeError(f'真机握手写入失败：{name}')
        else:
            (folder / name).touch()

    with (run / 'xcodebuild.log').open('w') as log, (run / 'xctrace.log').open('w') as trace_log:
        process = subprocess.Popen(command, env=environment, stdout=log, stderr=subprocess.STDOUT)
        try:
            def ready_folder():
                if platform == 'device':
                    candidate = transfer('from', 'ready.json')
                    return candidate.parent if candidate else None
                result = subprocess.run(['xcrun', 'simctl', 'get_app_container', device,
                                         'com.stickypagerkit.UIKitTestHost', 'data'], env=environment,
                                        capture_output=True, text=True)
                if result.returncode == 0:
                    candidate = Path(result.stdout.strip()) / 'tmp/sp-p5c2' / token
                    if (candidate / 'ready.json').exists():
                        return candidate
                return None

            folder = wait_until(ready_folder, [process])
            ready = read(folder / 'ready.json')
            write(run / 'ready.json', ready)
            trace_command = ['xcrun', 'xctrace', 'record', '--template', template, '--device', device,
                             '--attach', str(ready['pid']), '--output', str(run / 'Profile.trace'),
                             '--time-limit', '120s', '--no-prompt']
            write(run / 'trace-command.json', trace_command)
            trace_process = subprocess.Popen(trace_command, env=environment, stdout=trace_log, stderr=subprocess.STDOUT)
            wait_until(lambda: recording_started((run / 'xctrace.log').read_text()), [process, trace_process], 90)
            notify('go')
            wait_until(lambda: transfer('from', 'done.json') if platform == 'device'
                       else (folder / 'done.json').exists(), [process, trace_process], 110)
            shutil.copy2(folder / 'done.json', run / 'workload.json')
            trace_process.send_signal(signal.SIGINT)
            # Allocations 的停止、符号化和落盘可能长于负载本身；不缩减采样来迁就保存时间。
            finalize_start = time.monotonic()
            state['traceExitCode'] = trace_process.wait(timeout=180)
            state['traceFinalizeSeconds'] = time.monotonic() - finalize_start
            notify('release')
            state['testExitCode'] = process.wait(timeout=60)
            if state['traceExitCode'] or state['testExitCode']:
                raise RuntimeError('采集或测试未成功终止。')
            for name, arguments in [('trace-toc.xml', ['--toc']),
                                    ('signposts.xml', ['--xpath', '/trace-toc/run/data/table[@schema="os-signpost"]'])]:
                subprocess.run(['xcrun', 'xctrace', 'export', '--input', str(run / 'Profile.trace'),
                                *arguments, '--output', str(run / name)], env=environment, check=True,
                               stdout=trace_log, stderr=subprocess.STDOUT)
            toc = ET.parse(run / 'trace-toc.xml')
            if not any(item.get('pid') == str(ready['pid']) for item in toc.findall('.//process')):
                raise ValueError('trace 未包含本次测试宿主 PID。')
            state['capturedExpectedPID'] = True
            state['status'] = 'captured'
        except (Exception, KeyboardInterrupt) as error:
            state.update(status='failed', error=str(error))
        finally:
            if trace_process and trace_process.poll() is None:
                trace_process.send_signal(signal.SIGINT)
                try:
                    trace_process.wait(timeout=60)
                except subprocess.TimeoutExpired:
                    trace_process.terminate()
                    trace_process.wait(timeout=30)
            if trace_process:
                state['traceExitCode'] = trace_process.returncode
            if folder:
                try:
                    notify('release')
                except RuntimeError as error:
                    state['releaseError'] = str(error)
            if process.poll() is None:
                try:
                    process.wait(timeout=130)
                except subprocess.TimeoutExpired:
                    process.send_signal(signal.SIGINT)
                    process.wait(timeout=60)
            state['testExitCode'] = process.returncode
            state['sourceUnchanged'] = source_hashes() == sources
            state['artifactsUnchanged'] = tree_hashes(artifacts) == frozen
            write(run / 'execution.json', state)
    with (run / 'summary-output.txt').open('w') as log:
        subprocess.run([sys.executable, str(ROOT / 'Scripts/summarize_validation.py'), str(run)],
                       env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
    summary = read(run / 'summary.json')
    passed = (summary.get('tests', {}).get('result') == 'Passed'
              and summary['tests']['passedTests'] == 1 and summary['tests']['skippedTests'] == 0
              and summary['tests']['runtimeWarnings'] == [] and summary['runtimeDiagnostics']['status'] == 'passed')
    print(json.dumps(state, ensure_ascii=False, indent=2))
    return 0 if state['status'] == 'captured' and state['sourceUnchanged'] and state['artifactsUnchanged'] and passed else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build', type=Path)
    parser.add_argument('run', type=Path)
    parser.add_argument('--device', required=True)
    parser.add_argument('--platform', choices=['simulator', 'device'], default='simulator')
    parser.add_argument('--developer-dir', type=Path, required=True)
    parser.add_argument('--template', choices=['Time Profiler', 'Allocations', 'Animation Hitches'], required=True)
    parser.add_argument('--test', choices=['testWorkloadColorsOff', 'testWorkloadColorsOn',
                                         'testWorkloadTitleOnly', 'testWorkloadIconOnly',
                                         'testNativeStandardColorsOff', 'testNativeStandardColorsOn'], required=True)
    args = parser.parse_args()
    sys.exit(profile(args.build.resolve(), args.run.resolve(), args.device, args.developer_dir.resolve(), args.template, args.test, args.platform))
