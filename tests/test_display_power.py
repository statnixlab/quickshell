#!/usr/bin/env python3
"""Verify bounded DPMS recovery and preservation of user-disabled outputs."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'display_power', Path(__file__).resolve().parents[1] / 'scripts/system/display_power.py')
POWER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POWER)

ON = dict(status='connected', dpms='On', enabled='enabled')
OFF = dict(status='connected', dpms='Off', enabled='disabled')


class FakeDisplay:
    def __init__(self, state):
        self.active = {'DP-1': {'current_mode': 0, 'logical': {'scale': 2}}}
        self.states = {'DP-1': dict(state), 'HDMI-A-1': dict(OFF)}
        self.commands = []
        self.locked_now = False
        self.fail_off = False
        self.fail_on = 0
        self.stuck = False

    def outputs(self):
        return copy.deepcopy(self.active)

    def state(self, name):
        return dict(self.states[name])

    def power(self, action):
        self.commands.append(('power', action))

    def output(self, name, action):
        if not self.locked_now:
            raise AssertionError('Recovery must hold the shared display lock')
        self.commands.append((name, action))
        if action == 'Off':
            self.states[name] = dict(OFF)
            if self.fail_off:
                raise TimeoutError('Off acknowledgement lost')
        else:
            if self.fail_on:
                self.fail_on -= 1
                raise TimeoutError('On acknowledgement lost')
            if not self.stuck:
                self.states[name] = dict(ON)

    def locked(self, operation):
        self.locked_now = True
        try:
            return operation()
        finally:
            self.locked_now = False


class RecoveryContracts(unittest.TestCase):
    def wake(self, display, sleep=lambda _: None, reconnect_outputs=frozenset()):
        return POWER.wake(display, sleep=sleep, report=lambda *args, **kwargs: None,
                          reconnect_outputs=reconnect_outputs)

    def test_opted_in_panel_is_reconnected_even_when_kernel_reports_on(self):
        d = FakeDisplay(ON)
        original = d.outputs()
        self.assertTrue(self.wake(d, reconnect_outputs={'DP-1'}))
        self.assertEqual(d.commands, [('power', 'on'), ('DP-1', 'Off'), ('DP-1', 'On')])
        self.assertEqual(d.outputs(), original)

    def test_opt_in_never_enables_a_user_disabled_output(self):
        d = FakeDisplay(ON)
        self.assertTrue(self.wake(d, reconnect_outputs={'HDMI-A-1'}))
        self.assertEqual(d.commands, [('power', 'on')])

    def test_panel_removed_during_settling_is_not_reenabled(self):
        d = FakeDisplay(ON)
        def unplug(delay):
            if delay == 4.0:
                d.active.clear()
        self.assertTrue(self.wake(d, sleep=unplug, reconnect_outputs={'DP-1'}))
        self.assertEqual(d.commands, [('power', 'on')])

    def test_config_requires_matching_monitor_identity(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'display-wake.json'
            path.write_text(json.dumps({'outputs': [dict(name='DP-1', make='Vendor', model='Panel')]}))
            self.assertEqual(POWER.configured_reconnects(path, {
                'DP-1': dict(name='DP-1', make='Vendor', model='Different')}), set())
            self.assertEqual(POWER.configured_reconnects(path, {
                'DP-1': dict(name='DP-1', make='Vendor', model='Panel')}), {'DP-1'})

    def test_healthy_output_is_not_reset(self):
        d = FakeDisplay(ON)
        self.assertTrue(self.wake(d))
        self.assertEqual(d.commands, [('power', 'on')])

    def test_stalled_output_is_reset_once_without_touching_disabled_output(self):
        d = FakeDisplay(OFF)
        self.assertTrue(self.wake(d))
        self.assertEqual(d.commands, [('power', 'on'), ('DP-1', 'Off'), ('DP-1', 'On')])
        self.assertEqual(d.states['HDMI-A-1'], OFF)

    def test_delayed_modeset_gets_time_to_complete(self):
        d = FakeDisplay(OFF)
        def finish(_):
            d.states['DP-1'] = dict(ON)
        self.assertTrue(self.wake(d, finish))
        self.assertEqual(d.commands, [('power', 'on')])

    def test_user_disabling_output_during_wait_is_respected(self):
        d = FakeDisplay(OFF)
        self.assertTrue(self.wake(d, lambda _: d.active.clear()))
        self.assertEqual(d.commands, [('power', 'on')])

    def test_unknown_kernel_state_does_not_trigger_a_reset(self):
        d = FakeDisplay({'verification': 'ambiguous'})
        self.assertTrue(self.wake(d))
        self.assertEqual(d.commands, [('power', 'on')])

    def test_lost_off_acknowledgement_still_restores_the_output(self):
        d = FakeDisplay(OFF)
        d.fail_off = True
        with self.assertRaises(TimeoutError):
            self.wake(d)
        self.assertEqual(d.states['DP-1'], ON)
        self.assertEqual(d.commands[-1], ('DP-1', 'On'))

    def test_on_failure_retries_once(self):
        d = FakeDisplay(OFF)
        d.fail_on = 2
        with self.assertRaises(TimeoutError):
            self.wake(d)
        self.assertEqual(d.commands.count(('DP-1', 'On')), 2)

    def test_persistent_failure_is_reported_without_looping(self):
        d = FakeDisplay(OFF)
        d.stuck = True
        self.assertFalse(self.wake(d))
        self.assertEqual(d.commands.count(('DP-1', 'Off')), 1)

    def test_ambiguous_connected_connectors_are_not_guessed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('card0-DP-1', 'card1-DP-1'):
                path = root / name
                path.mkdir()
                for key, value in OFF.items():
                    (path / key).write_text(value + '\n')
            self.assertEqual(POWER.connector_state('DP-1', root), {'verification': 'ambiguous'})
            (root / 'card0-DP-1' / 'status').write_text('disconnected\n')
            self.assertEqual(POWER.connector_state('DP-1', root)['connector'], 'card1-DP-1')


if __name__ == '__main__':
    unittest.main()
