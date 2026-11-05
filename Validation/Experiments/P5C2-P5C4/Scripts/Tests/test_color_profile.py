import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from profile_colors import recording_started


class ColorProfileTests(unittest.TestCase):
    def test_waits_for_recording_prompt(self):
        self.assertFalse(recording_started('Starting recording...'))
        self.assertTrue(recording_started('Starting recording...\nCtrl-C to stop the recording'))

    def test_disconnect_precedes_prompt_even_if_tool_reports_success(self):
        log = ('Starting recording...\nDevice got disconnected, ending recording...\n'
               'Ctrl-C to stop the recording\nRecording completed. Saving output file...')
        with self.assertRaises(RuntimeError):
            recording_started(log)


if __name__ == '__main__':
    unittest.main()
