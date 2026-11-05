#!/usr/bin/env python3
"""只重读 P5C2 真机证据，按 PID、signpost 和 display/swap ID 核对动画区间。"""
import argparse
import json
import math
from pathlib import Path
import statistics
import xml.etree.ElementTree as ET


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_table(path, schema):
    root = ET.parse(path).getroot()
    identifiers = {e.get('id'): e for e in root.iter() if e.get('id')}

    def resolve(element):
        if element.get('ref'):
            require(element.get('ref') in identifiers, 'XML 引用缺失。')
            return identifiers[element.get('ref')]
        return element

    found, rows, seen = False, [], set()
    previous_definition = None
    for node in root.findall('node'):
        definition = node.find('schema')
        if definition is None:
            # 同一 schema 的后续 TOC 节点可省略定义，但仍包含新事件。
            # 省略 schema 不等于整张表的引用副本；逐行解析后再去重。
            definition = previous_definition
        if definition is None:
            require(not node.findall('row'), 'XML 数据行没有可用列定义。')
            continue
        definition = resolve(definition)
        previous_definition = definition
        if definition.get('name') != schema:
            continue
        found = True
        columns = [e.findtext('mnemonic') for e in definition.findall('col')]
        require(columns and len(set(columns)) == len(columns), 'XML 列定义无效。')
        for row in node.findall('row'):
            require(len(row) == len(columns), 'XML 行与列不匹配。')
            values = {}
            for key, element in zip(columns, row):
                element = resolve(element)
                if key == 'process':
                    pid = element.find('pid')
                    values[key] = int(resolve(pid).text) if pid is not None else None
                else:
                    values[key] = element.text
            # 同一底层表可从不同 TOC 路径导出，避免引用副本重复计数。
            identity = tuple(sorted(values.items()))
            if identity not in seen:
                seen.add(identity)
                rows.append(values)
    require(found, f'缺少 {schema} 表，不能把缺数据当作零记录。')
    return rows


def analyze(ready, done, execution, protocol, tables, recording):
    require(execution.get('status') == 'captured' and execution.get('traceExitCode') == 0,
            '采集没有成功结束。')
    require(execution.get('sourceUnchanged') is True and execution.get('appUnchanged') is True,
            '运行期间输入或产物变化。')
    require(done.get('status') == 'passed', '自然动画检查没有通过。')
    require(recording['endReason'] == 'User pressed Stop', 'trace 并非正常主动停止。')
    require(math.isfinite(recording['durationSeconds']) and recording['durationSeconds'] > 0,
            'trace 时长无效。')
    require(ready.get('colors') == done.get('colors') == protocol.get('colors'), '颜色模式不一致。')
    rounds = done.get('rounds', [])
    require(len(rounds) == 12 and protocol.get('rounds') == 12, '必须完整执行 12 次自然选择。')
    for index, row in enumerate(rounds):
        require(row['index'] == (index + 1) % 6 and row['end'] > row['start'], '选择顺序或时间无效。')
        require(len(row['samples']) > 2, '观察回调覆盖不足。')
        if done['colors']:
            require(any(0.05 < s['blue'] < 0.95 for s in row['samples']), '缺少中间颜色。')
    pid = ready['pid']
    points = [r for r in tables['os-signpost'] if r.get('name') == 'NativeColorSelections'
              and r.get('subsystem') == 'StickyPagerKit.Validation' and r.get('process') == pid]
    require(len(points) == 2 and {r['event-type'] for r in points} == {'Begin', 'End'},
            '目标 PID 缺少唯一的完整 signpost。')
    require(points[0]['identifier'] == points[1]['identifier'], 'signpost 标识不匹配。')
    start = int(next(r['time'] for r in points if r['event-type'] == 'Begin'))
    end = int(next(r['time'] for r in points if r['event-type'] == 'End'))
    require(end > start, 'signpost 时间无效。')
    require(start >= 0 and end <= recording['durationSeconds'] * 1e9,
            'signpost 超出实际录制时段。')
    updates = [r for r in tables['hitches-updates'] if r['process'] == pid and start <= int(r['start']) < end]
    require(updates, '目标区间没有应用更新，不能判定零 hitch。')
    swaps = {(r['display'], r['swap-id']) for r in updates}
    frames = [r for r in tables['hitches-frame-lifetimes'] if (r['display'], r['swap-id']) in swaps
              and int(r['start']) < end and int(r['start']) + int(r['duration']) > start]
    require(swaps == {(r['display'], r['swap-id']) for r in frames}, '应用更新未完整关联帧生命周期。')
    hitches = [r for r in tables['hitches'] if r['process'] == pid and int(r['start']) < end
               and int(r['start']) + int(r['duration']) > start]
    durations = sorted(int(r['duration']) / 1e6 for r in updates)
    require(all(v >= 0 for v in durations), '更新时长无效。')
    return {'pid': pid, 'colors': done['colors'], 'rounds': len(rounds),
            'signpostStartNS': start, 'signpostEndNS': end, 'intervalSeconds': (end - start) / 1e9,
            'recording': recording,
            'targetUpdateRows': len(updates), 'matchedFrameLifetimes': len(frames),
            'targetHitchesInInterval': len(hitches), 'hitchRowsEntireTrace': len(tables['hitches']),
            'updateDurationMS': {'median': statistics.median(durations), 'mean': statistics.mean(durations),
                                 'p95NearestRank': durations[math.ceil(len(durations) * .95) - 1], 'max': max(durations)},
            'thermalState': done.get('thermalState'), 'lowPowerMode': done.get('lowPowerMode'),
            'note': '工具的应用更新阶段耗时，不是函数独占 CPU；零 hitch 仅适用于本次有数据覆盖的区间。'}


def summarize(run):
    load = lambda name: json.loads((run / name).read_text())
    recordings = ET.parse(run / 'trace-toc.xml').getroot().findall('run')
    require(len(recordings) == 1, '只接受单次录制。')
    info = recordings[0].find('info/summary')
    require(info is not None, '缺少 trace 终止信息。')
    recording = {'endReason': info.findtext('end-reason'),
                 'durationSeconds': float(info.findtext('duration', 'nan'))}
    tables = {name: read_table(run / f'{name}.xml', name)
              for name in ('os-signpost', 'hitches', 'hitches-updates', 'hitches-frame-lifetimes')}
    result = analyze(load('ready.json'), load('done.json'), load('execution.json'), load('protocol.json'), tables, recording)
    result['traceWarnings'] = [line for line in (run / 'xctrace.log').read_text().splitlines()
                               if 'failed' in line.lower() or 'warning' in line.lower()]
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    # 保留旧分析与失败，不覆盖现有证据。
    result = summarize(args.run)
    with args.output.open('x') as output:
        json.dump(result, output, ensure_ascii=False, indent=2)
        output.write('\n')
