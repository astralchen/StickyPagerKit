import copy
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from analyze_color_hitches import analyze, read_table


class ColorHitchesTests(unittest.TestCase):
    def setUp(self):
        self.ready = {'pid': 42, 'colors': True}
        self.done = {'status': 'passed', 'colors': True, 'rounds': [
            {'index': (i + 1) % 6, 'start': i, 'end': i + .4,
             'samples': [{'blue': v} for v in (.1, .5, 1)]} for i in range(12)]}
        self.execution = {'status': 'captured', 'traceExitCode': 0, 'sourceUnchanged': True, 'appUnchanged': True}
        self.protocol = {'colors': True, 'rounds': 12}
        self.recording = {'endReason': 'User pressed Stop', 'durationSeconds': 0.000001}
        self.tables = {'os-signpost': [
            {'name': 'NativeColorSelections', 'subsystem': 'StickyPagerKit.Validation', 'process': 42,
             'identifier': '1', 'event-type': kind, 'time': str(t)} for kind, t in [('Begin', 100), ('End', 900)]],
            'hitches-updates': [{'process': 42, 'start': '150', 'duration': '40', 'display': '1', 'swap-id': '5'}],
            'hitches-frame-lifetimes': [{'start': '140', 'duration': '100', 'display': '1', 'swap-id': '5'}],
            'hitches': []}

    def result(self):
        return analyze(self.ready, self.done, self.execution, self.protocol, self.tables, self.recording)

    def test_tool_success_does_not_hide_disconnect_or_truncation(self):
        self.recording['endReason'] = 'Device disconnected'
        with self.assertRaises(ValueError): self.result()
        self.recording['endReason'] = 'User pressed Stop'
        for value in (0.0000005, 0, float('nan')):
            self.recording['durationSeconds'] = value
            with self.assertRaises(ValueError): self.result()

    def test_zero_requires_frame_coverage(self):
        self.assertEqual(self.result()['targetHitchesInInterval'], 0)
        self.tables['hitches-frame-lifetimes'] = []
        with self.assertRaises(ValueError): self.result()

    def test_pid_interval_and_display_are_respected(self):
        self.tables['hitches'] = [
            {'process': 42, 'start': '80', 'duration': '30'},
            {'process': 43, 'start': '150', 'duration': '30'},
            {'process': 42, 'start': '900', 'duration': '30'}]
        self.assertEqual(self.result()['targetHitchesInInterval'], 1)
        self.tables['hitches-frame-lifetimes'][0]['display'] = '2'
        with self.assertRaises(ValueError): self.result()

    def test_invalid_boundaries_rejected(self):
        for change in ['pid', 'id', 'time', 'missing', 'duplicate']:
            with self.subTest(change=change):
                original = copy.deepcopy(self.tables)
                points = self.tables['os-signpost']
                if change == 'pid': points[0]['process'] = 43
                if change == 'id': points[0]['identifier'] = '2'
                if change == 'time': points[1]['time'] = '50'
                if change == 'missing': points.pop()
                if change == 'duplicate': points.append(dict(points[0]))
                with self.assertRaises(ValueError): self.result()
                self.tables = original

    def test_incomplete_or_changed_evidence_rejected(self):
        for key, value in [('status', 'failed'), ('traceExitCode', 1), ('sourceUnchanged', False), ('appUnchanged', False)]:
            with self.subTest(key=key):
                previous = self.execution[key]; self.execution[key] = value
                with self.assertRaises(ValueError): self.result()
                self.execution[key] = previous
        self.done['rounds'][0]['samples'] = [{'blue': 1}] * 3
        with self.assertRaises(ValueError): self.result()

    def test_xml_reference_duplicates_and_missing_schema(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'table.xml'
            path.write_text('<trace-query-result><node><schema id="s" name="hitches"><col><mnemonic>process</mnemonic></col></schema><row><process id="p"><pid id="n">42</pid></process></row></node><node><schema ref="s"/><row><process ref="p"/></row></node></trace-query-result>')
            self.assertEqual(read_table(path, 'hitches'), [{'process': 42}])
            with self.assertRaises(ValueError): read_table(path, 'hitches-updates')
            path.write_text('<trace-query-result><node><schema name="hitches"><col><mnemonic>process</mnemonic></col></schema><row><process ref="missing"/></row></node></trace-query-result>')
            with self.assertRaises(ValueError): read_table(path, 'hitches')

    def test_schema_omission_keeps_new_rows_and_deduplicates_references(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'table.xml'
            path.write_text('<trace-query-result><node><schema name="os-signpost"><col><mnemonic>name</mnemonic></col></schema><row><string id="a">Other</string></row></node><node><row><string id="b">NativeColorSelections</string></row></node><node><row><string ref="b"/></row></node></trace-query-result>')
            self.assertEqual(read_table(path, 'os-signpost'), [{'name': 'Other'}, {'name': 'NativeColorSelections'}])
            path.write_text('<trace-query-result><node><row><string>Unspecified</string></row></node></trace-query-result>')
            with self.assertRaises(ValueError): read_table(path, 'os-signpost')


if __name__ == '__main__': unittest.main()
