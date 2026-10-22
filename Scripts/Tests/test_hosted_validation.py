import contextlib
import io
import json
import plistlib
import runpy
from types import SimpleNamespace
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

scripts = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(scripts))
from check_runtime_diagnostics import diagnostics
from prepare_hosted_tests import prepare


class HostedValidationTests(unittest.TestCase):
    def test_preparation_preserves_filters_and_diagnostics_environment(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            products = root / 'Products'
            bundle = products / 'Debug/StickyPagerKitTests.xctest'
            bundle.mkdir(parents=True)
            (bundle / 'binary').write_bytes(b'test bundle')
            host = root / 'Host.app'
            host.mkdir()
            (host / 'Info.plist').write_bytes(plistlib.dumps({
                'CFBundleIdentifier': 'example.host', 'CFBundleExecutable': 'Host'}))
            target = {
                'BlueprintName': 'StickyPagerKitTests',
                'TestBundlePath': '__TESTROOT__/Debug/StickyPagerKitTests.xctest',
                'OnlyTestIdentifiers': ['SPUIKitEnvironmentTests'],
                'TestingEnvironmentVariables': {
                    'DYLD_INSERT_LIBRARIES': 'MainThreadChecker.dylib',
                    'DYLD_FRAMEWORK_PATH': '__TESTROOT__/Debug'},
            }
            source = products / 'Original.xctestrun'
            original = plistlib.dumps({'TestConfigurations': [{'TestTargets': [target]}]})
            source.write_bytes(original)
            output = root / 'Hosted.xctestrun'
            with patch('prepare_hosted_tests.subprocess.run') as sign:
                prepare(source, host, root / 'Frozen', output)
                sign.assert_called_once()
            result = plistlib.loads(output.read_bytes())['TestConfigurations'][0]['TestTargets'][0]
            self.assertEqual(source.read_bytes(), original)
            self.assertEqual(result['OnlyTestIdentifiers'], ['SPUIKitEnvironmentTests'])
            self.assertEqual(result['TestHostBundleIdentifier'], 'example.host')
            self.assertTrue(result['IsAppHostedTestBundle'])
            self.assertEqual(result['TestBundlePath'], '__TESTHOST__/PlugIns/StickyPagerKitTests.xctest')
            environment = result['TestingEnvironmentVariables']
            self.assertIn('libXCTestBundleInject.dylib', environment['DYLD_INSERT_LIBRARIES'])
            self.assertIn('MainThreadChecker.dylib', environment['DYLD_INSERT_LIBRARIES'])
            self.assertEqual(environment['DYLD_FRAMEWORK_PATH'], str((products / 'Debug').resolve()))
            self.assertEqual((root / 'Frozen/Host.app/PlugIns/StickyPagerKitTests.xctest/binary').read_bytes(), b'test bundle')
            with self.assertRaises(FileExistsError):
                prepare(source, host, root / 'Frozen', output)

    def test_unexpected_target_is_rejected_before_copying(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'Original.xctestrun'
            source.write_bytes(plistlib.dumps({'TestConfigurations': [{'TestTargets': [{'BlueprintName': 'OtherTests'}]}]}))
            with self.assertRaises(ValueError):
                prepare(source, root / 'Host.app', root / 'Frozen', root / 'Hosted.xctestrun')
            self.assertFalse((root / 'Frozen').exists())

    def test_runtime_diagnostic_is_not_hidden_by_success_marker(self):
        result = diagnostics('start\nObservation tracking feedback loop detected! object\n** TEST SUCCEEDED **\n')
        self.assertEqual(result['observationFeedbackLoopCount'], 1)
        self.assertEqual(result['lineNumbers'], [2])
        self.assertEqual(result['status'], 'failed')

    def test_unbalanced_appearance_is_a_separate_failure(self):
        result = diagnostics('Unbalanced calls to begin/end appearance transitions for controller')
        self.assertEqual(result['observationFeedbackLoopCount'], 0)
        self.assertEqual(result['unbalancedAppearanceCount'], 1)
        self.assertEqual(result['status'], 'failed')

    def test_missing_xcresult_summary_preserves_execute_terminal_marker(self):
        # 原日志同时有 build-for-testing 与 test-without-building 的终态；不能只报告前者。
        with tempfile.TemporaryDirectory(dir=scripts.parent / 'Validation/Results') as temporary:
            run = Path(temporary)
            (run / 'source-hashes.json').write_text('{}')
            (run / 'xcodebuild.log').write_text('** TEST BUILD SUCCEEDED **\n** TEST EXECUTE SUCCEEDED **\n')
            unavailable = SimpleNamespace(returncode=1, stderr='fixture: summary unavailable', stdout='')
            with patch.object(sys, 'argv', ['summarize_validation.py', str(run)]), \
                    patch('subprocess.run', return_value=unavailable), contextlib.redirect_stdout(io.StringIO()):
                runpy.run_path(str(scripts / 'summarize_validation.py'), run_name='__main__')
            summary = json.loads((run / 'summary.json').read_text())
            self.assertEqual(summary['terminalMarker'], '** TEST EXECUTE SUCCEEDED **')
            self.assertTrue(summary['testSummaryUnavailable'])
            self.assertNotIn('tests', summary)
            self.assertIn('Package.swift', summary['sourceChangedSinceRun'])

    def test_clean_log_has_no_observation_diagnostic(self):
        self.assertEqual(diagnostics('** TEST SUCCEEDED **')['observationFeedbackLoopCount'], 0)


if __name__ == '__main__':
    unittest.main()
