"""验证性能证据的拒绝条件和判定边界，不运行模拟器。"""
import copy
import csv
import json
import plistlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import color_repeatability as color


class ColorRepeatabilityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.run = self.root / 'batch-1'
        (self.run / 'metrics').mkdir(parents=True)
        self.summary = {
            'sourceChangedSinceRun': [], 'runtimeDiagnostics': {'status': 'passed'},
            'tests': {'result': 'Passed', 'passedTests': 4, 'totalTestCount': 4, 'failedTests': 0,
                      'skippedTests': 0, 'expectedFailures': 0, 'runtimeWarnings': [],
                      'devicesAndConfigurations': [{'device': {'deviceId': 'device', 'osVersion': '27.2'}}]},
        }
        color.write(self.run / 'summary.json', self.summary)
        self.manifest = [{'testIdentifier': f'SPTabBarColorPerformanceTests/{name}()',
                          'metricsFileName': f'{name}.csv.csv'} for name in color.TESTS]
        color.write(self.run / 'metrics/manifest.json', self.manifest)
        for index, name in enumerate(color.TESTS):
            self.csv(name, [0.1 * (index + 1)] * 10)

    def csv(self, name, samples, unit='s', destination='iPhone Simulator', duplicates=1):
        with (self.run / 'metrics' / f'{name}.csv').open('w', newline='') as handle:
            writer = csv.writer(handle)
            writer.writerow(['Destination', 'Configuration', 'Clock Monotonic Time (Average)',
                             'Clock Monotonic Time (Iterations)'])
            for _ in range(duplicates):
                writer.writerow([destination, 'Test Scheme Action', f'0.1 {unit}', json.dumps(samples)])

    def rows(self, reverse=False):
        return color.read_batch(self.run, reverse, 'device')[0]

    def test_original_csv_suffix_and_reverse_mapping_preserve_samples(self):
        normal, reverse = self.rows(), self.rows(True)
        self.assertEqual([r['colors'] for r in normal], [False, True, False, True])
        self.assertEqual([r['colors'] for r in reverse], [True, False, True, False])
        self.assertEqual(normal[1]['samplesSeconds'], [0.2] * 10)

    def test_invalid_terminal_evidence_is_rejected(self):
        changes = [('sourceChangedSinceRun', ['new.swift']), ('runtimeDiagnostics', {'status': 'failed'})]
        for key, value in changes:
            with self.subTest(key=key):
                summary = copy.deepcopy(self.summary)
                summary[key] = value
                color.write(self.run / 'summary.json', summary)
                with self.assertRaises(ValueError):
                    self.rows()
        for key, value in [('result', 'Failed'), ('passedTests', 3), ('skippedTests', 1),
                           ('expectedFailures', 1), ('totalTestCount', 5), ('runtimeWarnings', ['warning'])]:
            with self.subTest(key=key):
                summary = copy.deepcopy(self.summary)
                summary['tests'][key] = value
                color.write(self.run / 'summary.json', summary)
                with self.assertRaises(ValueError):
                    self.rows()

    def test_wrong_device_is_rejected(self):
        with self.assertRaises(ValueError):
            color.read_batch(self.run, False, 'another-device')

    def test_missing_duplicate_unknown_and_escaped_metrics_are_rejected(self):
        invalid = [self.manifest[:-1], self.manifest + [self.manifest[0]],
                   [{'testIdentifier': 'OtherTests/testA()', 'metricsFileName': 'x.csv'}],
                   [{**self.manifest[0], 'metricsFileName': '../x.csv'}]]
        for manifest in invalid:
            with self.subTest(manifest=manifest):
                color.write(self.run / 'metrics/manifest.json', manifest)
                with self.assertRaises(ValueError):
                    self.rows()

    def test_bad_sample_counts_values_units_and_duplicate_rows_are_rejected(self):
        for samples in ([0.1] * 9, [0.1] * 200, [0.1] * 9 + [float('nan')],
                        [0.1] * 9 + [float('inf')], [0.1] * 9 + [0], [True] * 10):
            with self.subTest(samples=samples):
                self.csv(color.TESTS[0], samples)
                with self.assertRaises(ValueError):
                    self.rows()
        for options in ({'unit': 'ms'}, {'duplicates': 2}):
            self.csv(color.TESTS[0], [0.1] * 10, **options)
            with self.assertRaises(ValueError):
                self.rows()

    def test_stable_batches_are_not_reported_as_speedup(self):
        rows = self.rows()
        report = color.assess([rows] * 4, 10, 10)
        self.assertEqual(report['status'], 'stable')
        self.assertEqual(report['groups'][0]['betweenBatchSpreadPercent'], 0)
        self.assertIn('不代表提速', report['note'])

    def test_slow_sample_is_retained_and_causes_instability(self):
        self.csv(color.TESTS[0], [0.1] * 9 + [1.0])
        rows = self.rows()
        self.assertEqual(rows[0]['samplesSeconds'][-1], 1.0)
        report = color.assess([rows] * 4, 10, 10)
        self.assertEqual(report['status'], 'unstable')
        self.assertGreater(report['groups'][0]['maxWithinBatchRSDPercent'], 10)

    def test_between_batch_drift_is_detected_without_pooling_samples(self):
        rows = self.rows()
        changed = copy.deepcopy(rows)
        changed[0]['meanSeconds'] *= 2
        report = color.assess([rows, rows, rows, changed], 10, 10)
        self.assertEqual(report['status'], 'unstable')
        self.assertAlmostEqual(report['groups'][0]['betweenBatchSpreadPercent'], 100)

    def test_partial_or_mixed_batches_are_rejected(self):
        rows = self.rows()
        for batches in ([rows] * 3, [rows, rows, rows, rows[:-1]]):
            with self.assertRaises(ValueError):
                color.assess(batches, 10, 10)
        changed = copy.deepcopy(rows)
        changed[0]['destination'] = 'another-device'
        with self.assertRaises(ValueError):
            color.assess([rows, rows, rows, changed], 10, 10)

    def test_source_and_artifact_changes_are_rejected_before_launch(self):
        artifacts = self.root / 'artifacts'
        artifacts.mkdir()
        (artifacts / 'binary').write_bytes(b'original')
        protocol = {'sourceHashes': {'a': 'hash'}, 'artifactHashes': color.tree_hashes(artifacts)}
        with patch.object(color, 'source_hashes', return_value={'a': 'changed'}):
            with self.assertRaisesRegex(ValueError, '源码'):
                color.verify(self.root, protocol, {})
        (artifacts / 'binary').write_bytes(b'mutated')
        with patch.object(color, 'source_hashes', return_value={'a': 'hash'}):
            with self.assertRaisesRegex(ValueError, '产物'):
                color.verify(self.root, protocol, {})

    def make_experiment(self):
        protocol = {'schema': color.SCHEMA, 'reversedOrder': list(color.ORDER), 'tests': list(color.TESTS),
                    'samplesPerTest': 10, 'profiling': False, 'configuration': 'Release',
                    'device': {'udid': 'device'}, 'maxWithinBatchRSDPercent': 10, 'maxBetweenBatchSpreadPercent': 10}
        color.write(self.root / 'protocol.json', protocol)
        protocol_hash = color.digest(self.root / 'protocol.json')
        color.write(self.root / 'execution.json', {'protocolSHA256': protocol_hash, 'status': 'completed'})
        for index in range(1, 5):
            run = self.root / f'batch-{index}'
            if index != 1:
                color.shutil.copytree(self.run, run)
            color.write(run / 'audit.json', {'verifiedBefore': True, 'verifiedAfter': True, 'exitCode': 0,
                                            'protocolSHA256': protocol_hash,
                                            'metricsHashes': color.tree_hashes(run / 'metrics'),
                                            'summarySHA256': color.digest(run / 'summary.json')})

    def test_report_integrity_rejects_modified_samples_and_protocol(self):
        self.make_experiment()
        # 反向批次的原始测试名相同，颜色角色必须重映射；这里四批样本相同但开关成本不同，应不稳定。
        self.assertEqual(color.summarize(self.root), 3)
        self.csv(color.TESTS[0], [0.001] * 10)
        with self.assertRaisesRegex(ValueError, '原始指标'):
            color.summarize(self.root)
        protocol = color.read(self.root / 'protocol.json')
        protocol['maxWithinBatchRSDPercent'] = 100
        color.write(self.root / 'protocol.json', protocol)
        with self.assertRaisesRegex(ValueError, '协议变化'):
            color.summarize(self.root)

    def test_incomplete_execution_cannot_produce_a_report(self):
        self.make_experiment()
        state = color.read(self.root / 'execution.json')
        state['status'] = 'incomplete'
        color.write(self.root / 'execution.json', state)
        with self.assertRaisesRegex(ValueError, '执行不完整'):
            color.summarize(self.root)

    def test_prepare_freezes_dependencies_and_sets_explicit_test_environment(self):
        build = self.root / 'build'
        build.mkdir()
        host = self.root / 'Original.app'
        host.mkdir()
        (host / 'binary').write_bytes(b'host')
        products = self.root / 'Release-iphonesimulator'
        products.mkdir()
        (products / 'dependency').write_bytes(b'library')
        original = plistlib.dumps({'TestConfigurations': [{'TestTargets': [{
            'BlueprintName': 'StickyPagerKitTests', 'IsAppHostedTestBundle': True,
            'TestHostPath': str(host), 'DependentProductPaths': [str(host)],
            'SkipTestIdentifiers': ['old'],
            'TestingEnvironmentVariables': {'__XCODE_BUILT_PRODUCTS_DIR_PATHS': str(products),
                                            'DYLD_FRAMEWORK_PATH': str(products)},
        }]}]})
        (build / 'Hosted.xctestrun').write_bytes(original)
        (build / 'xcodebuild.log').write_text('** TEST BUILD SUCCEEDED **')
        (build / 'toolchain.txt').write_text('Xcode fixture')
        color.write(build / 'source-hashes.json', {'a': 'hash'})
        experiment = self.root / 'experiment'
        with patch.object(color, 'source_hashes', return_value={'a': 'hash'}), \
                patch.object(color, 'capture', return_value='Xcode fixture'), \
                patch.object(color, 'device_info', return_value={'udid': 'device'}):
            color.prepare(build, experiment, 'device', Path('/Xcode'), 10, 10)
        protocol = color.load_protocol(experiment)
        self.assertEqual(color.tree_hashes(experiment / 'artifacts'), protocol['artifactHashes'])
        self.assertEqual((build / 'Hosted.xctestrun').read_bytes(), original)
        for index, reverse in enumerate(color.ORDER, 1):
            value = color.target(plistlib.loads((experiment / 'artifacts' / f'{index}.xctestrun').read_bytes()))
            self.assertNotIn('SkipTestIdentifiers', value)
            self.assertEqual(len(value['OnlyTestIdentifiers']), 4)
            self.assertEqual(value['EnvironmentVariables']['SP_TAB_COLOR_PROFILE'], '0')
            self.assertEqual(value['EnvironmentVariables']['SP_TAB_COLOR_REVERSE'], str(int(reverse)))
            self.assertEqual(value['TestingEnvironmentVariables']['DYLD_FRAMEWORK_PATH'],
                             str(experiment / 'artifacts/Products'))
        (products / 'dependency').write_bytes(b'rebuilt')
        self.assertEqual((experiment / 'artifacts/Products/dependency').read_bytes(), b'library')

    def test_failed_execution_stops_without_retry_and_preserves_exit_code(self):
        self.make_experiment()
        (self.root / 'execution.json').unlink()
        for index in range(1, 5):
            color.shutil.rmtree(self.root / f'batch-{index}')
        protocol = color.read(self.root / 'protocol.json')
        protocol.update(developerDir='/Xcode', sourceHashes={})
        color.write(self.root / 'protocol.json', protocol)
        with patch.object(color, 'verify'), patch.object(color.subprocess, 'run',
                                                     side_effect=[SimpleNamespace(returncode=65), SimpleNamespace(returncode=0)]) as run:
            with self.assertRaisesRegex(ValueError, '批次 1 失败'):
                color.execute(self.root)
            self.assertEqual(run.call_count, 2)  # 一次测试及一次终态摘要，无第二批或重试。
        self.assertEqual(color.read(self.root / 'execution.json')['status'], 'incomplete')
        self.assertEqual(color.read(self.root / 'batch-1/audit.json')['exitCode'], 65)
        self.assertFalse((self.root / 'batch-2').exists())
        with self.assertRaises(FileExistsError):
            color.execute(self.root)


if __name__ == '__main__':
    unittest.main()
