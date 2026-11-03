#!/usr/bin/env python3
"""汇总 P5A 的十组原始 CSV；保留样本，不混合设备、配置或不同测量路径。"""
import csv
import json
import math
from pathlib import Path
import statistics
import sys


def summarize(run):
    metrics = run / 'metrics'
    manifest = json.loads((metrics / 'manifest.json').read_text())
    summary = json.loads((run / 'summary.json').read_text())
    contract = json.loads((run / 'sampling-contract.json').read_text())
    if type(contract.get('reversed')) is not bool or contract.get('profiling') is not False:
        raise ValueError('需要明确的颜色执行顺序与非 profiling 采样契约。')
    if summary.get('tests', {}).get('result') != 'Passed':
        raise ValueError('只汇总已有通过终态的采样；失败证据保留，不合入基线。')
    expected = {f'test{letter}{name}' for letter, name in zip(
        'ABCDEFGHIJ', ['FramesFirst', 'FramesSecond', 'CommitFirst', 'CommitSecond',
                     'CompleteFirst', 'CompleteSecond', 'CombinedFirst', 'CombinedSecond', 'FlushedFirst', 'FlushedSecond'])}
    rows = []
    seen = set()
    for entry in manifest:
        identifier = entry['testIdentifier']
        if not identifier.startswith('SPTabBarColorPerformanceTests/'):
            continue
        test = identifier.split('/')[-1].removesuffix('()')
        if test not in expected:
            raise ValueError(f'未知颜色基准：{identifier}')
        filename = entry['metricsFileName']
        if Path(filename).name != filename:
            raise ValueError('指标文件必须位于 metrics 目录内。')
        path = metrics / filename
        # 部分 xcresulttool 版本的清单多带一个 .csv；保留原始清单并记录实际路径。
        if not path.exists() and filename.endswith('.csv.csv'):
            path = metrics / filename[:-4]
        with path.open(newline='') as handle:
            records = list(csv.DictReader(handle))
        for record in records:
            key = (test, record['Destination'], record['Configuration'])
            if key in seen:
                raise ValueError(f'同一测试环境出现重复指标行：{key}')
            seen.add(key)
            values = {}
            for column, raw in record.items():
                if not column.endswith(' (Iterations)'):
                    continue
                name = column.removesuffix(' (Iterations)')
                samples = json.loads(raw)
                if len(samples) != 10 or any(not math.isfinite(v) for v in samples):
                    raise ValueError(f'{test}/{name} 不是 10 个有限样本；profiling 不并入基线。')
                mean = statistics.mean(samples)
                average = record[name + ' (Average)']
                unit = average.partition(' ')[2]
                values[name] = {
                    'unit': unit, 'samples': samples, 'mean': mean,
                    'median': statistics.median(samples), 'min': min(samples), 'max': max(samples),
                    'sampleRelativeSDPercent': statistics.stdev(samples) / abs(mean) * 100 if mean else None,
                }
            if 'Clock Monotonic Time' not in values:
                raise ValueError(f'{test} 缺少墙钟时间指标。')
            colors = test.endswith('Second') != contract['reversed']
            rows.append({'test': test, 'colors': colors, 'destination': key[1], 'configuration': key[2],
                         'sourceCSV': path.name, 'metrics': values})
    environments = {(row['destination'], row['configuration']) for row in rows}
    if not environments:
        raise ValueError('未找到颜色单因素指标。')
    for destination, configuration in environments:
        found = {row['test'] for row in rows if (row['destination'], row['configuration']) == (destination, configuration)}
        if found != expected:
            raise ValueError(f'颜色对照不完整：缺少 {sorted(expected - found)}')
    rows.sort(key=lambda row: (row['destination'], row['configuration'], row['test']))
    output = {'run': str(run), 'sourceChangedSinceRun': summary.get('sourceChangedSinceRun'),
              'note': '仅批次统计；标准差使用 n-1。环境和路径分别保留，无性能阈值，不推导 FPS 或分配次数。',
              'rows': rows}
    (metrics / 'color-performance.json').write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    lines = ['| 测试 | 环境 | 平均批次 ms | 中位数 ms | 最小—最大 ms | 样本相对标准差 |',
             '| --- | --- | ---: | ---: | --- | ---: |']
    for row in rows:
        clock = row['metrics']['Clock Monotonic Time']
        if clock['unit'] != 's':
            raise ValueError('墙钟指标单位变化，请先核对导出格式。')
        lines.append(f"| {row['test']} / 颜色{'开' if row['colors'] else '关'} | {row['destination']} / {row['configuration']} | "
                     f"{clock['mean'] * 1000:.3f} | {clock['median'] * 1000:.3f} | "
                     f"{clock['min'] * 1000:.3f}—{clock['max'] * 1000:.3f} | "
                     f"{clock['sampleRelativeSDPercent']:.2f}% |")
    (metrics / 'color-performance.md').write_text('\n'.join(lines) + '\n')
    print('\n'.join(lines))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('用法：python3 Scripts/summarize_color_performance.py Validation/Results/<运行名>')
    summarize(Path(sys.argv[1]))
