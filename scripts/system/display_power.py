#!/usr/bin/python3
"""Wake Niri outputs and verify the kernel display state, with one bounded recovery."""
import importlib.util
import json
from pathlib import Path
import sys
import time


def emit(event, **data):
    print(json.dumps({'event': event, **data}, ensure_ascii=False), flush=True)


def connector_state(name, directory=Path('/sys/class/drm')):
    # Connector names are not globally unique on machines with several GPUs.
    candidates = []
    for path in directory.iterdir():
        if not path.name.startswith('card') or not path.name.endswith('-' + name):
            continue
        try:
            state = {key: (path / key).read_text().strip()
                     for key in ('status', 'dpms', 'enabled')}
        except OSError:
            continue
        if state['status'] == 'connected':
            candidates.append(dict(connector=path.name, **state))
    if len(candidates) == 1:
        return candidates[0]
    return {'verification': 'ambiguous' if candidates else 'unavailable'}


def inactive(state):
    return (state.get('status') == 'connected' and state.get('dpms') == 'Off'
            and state.get('enabled') == 'disabled')


def configured_reconnects(path, outputs):
    """Opt in by connector AND monitor identity, never by connector alone."""
    try:
        data = json.loads(path.read_text())
        profiles = data['outputs']
        if not isinstance(profiles, list):
            raise ValueError('outputs must be a list')
        matches = set()
        for profile in profiles:
            if not isinstance(profile, dict) or not all(
                    isinstance(profile.get(key), str) and profile[key]
                    for key in ('name', 'make', 'model')):
                raise ValueError('each output requires name, make and model')
            name = profile['name']
            if name in outputs and all(outputs[name].get(key) == value
                                       for key, value in profile.items()):
                matches.add(name)
        return matches
    except FileNotFoundError:
        return set()
    except (OSError, ValueError, KeyError, TypeError) as error:
        emit('display-reconnect-config-error', error=str(error))
        return set()


class Backend:
    def __init__(self):
        # Share the primary-display watcher's lock so a temporary output reset
        # cannot make it enable another display or move workspaces midway.
        spec = importlib.util.spec_from_file_location(
            'clavis_primary_display', Path(__file__).with_name('primary_display.py'))
        self.primary = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.primary)

    def outputs(self):
        return self.primary.active_outputs(self.primary.query('Outputs'))

    def power(self, action):
        self.primary.action('PowerOnMonitors' if action == 'on' else 'PowerOffMonitors')

    def output(self, name, action):
        return self.primary.request({'Output': {'output': name, 'action': action}})

    def locked(self, operation):
        return self.primary.locked(operation)

    def state(self, name):
        return connector_state(name)


def wake(backend, sleep=time.sleep, report=emit, reconnect_outputs=frozenset()):
    targets = backend.outputs()
    report('wake-request', outputs={name: backend.state(name) for name in targets})
    backend.power('on')
    states = {}
    # The IPC acknowledgement precedes the actual modeset/page flip.
    for delay in (0.25, 0.75, 1.0):
        sleep(delay)
        current = backend.outputs()
        states = {name: backend.state(name) for name in targets if name in current}
        if not any(inactive(state) for state in states.values()):
            break
    report('wake-observed', outputs=states)
    recovered = []
    if reconnect_outputs.intersection(targets):
        # Leave a short window for normal link training and diagnostic samples.
        # A configured panel may remain black even while DRM reports DPMS On.
        sleep(4.0)

    def recover():
        for name, state in states.items():
            forced = name in reconnect_outputs and state.get('status') == 'connected'
            if not inactive(state) and not forced:
                continue
            # Recheck hotplug and user changes immediately before any reset.
            current = backend.outputs()
            now = backend.state(name)
            if (current.get(name) != targets[name]
                    or now.get('status') != 'connected'
                    or (not forced and not inactive(now))):
                continue
            report('output-recovery-started', output=name, kernel=now,
                   reason='configured-link-reset' if forced else 'kernel-output-off')
            try:
                backend.output(name, 'Off')
                sleep(2.0)
            finally:
                # Even an IPC timeout can mean Off was applied. Always restore
                # the original active output, with one retry on an IPC error.
                try:
                    backend.output(name, 'On')
                except Exception:
                    backend.output(name, 'On')
            recovered.append(name)
        if recovered:
            sleep(1.0)
        current = backend.outputs()
        final = {name: backend.state(name) for name in targets if name in current}
        failed = [name for name, state in final.items() if inactive(state)]
        failed.extend(name for name in recovered if name not in current
                      and backend.state(name).get('status') == 'connected')
        report('wake-result', outputs=final, resetOutputs=recovered, failedOutputs=failed)
        return not failed

    return backend.locked(recover)


def main():
    try:
        if len(sys.argv) != 2 or sys.argv[1] not in ('on', 'off', 'status'):
            raise ValueError('Usage: display_power.py on|off|status')
        backend = Backend()
        if sys.argv[1] == 'status':
            emit('display-status', outputs={name: backend.state(name) for name in backend.outputs()})
            return 0
        if sys.argv[1] == 'off':
            backend.locked(lambda: backend.power('off'))
            return 0
        reconnects = configured_reconnects(backend.primary.CONFIG_HOME / 'display-wake.json',
                                           backend.outputs())
        return 0 if wake(backend, reconnect_outputs=reconnects) else 1
    except Exception as error:
        emit('display-power-error', error=str(error))
        return 1


if __name__ == '__main__':
    sys.exit(main())
