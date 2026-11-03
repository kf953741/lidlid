#!/usr/bin/env python3
"""Real sandboxed idle-assertion lifecycle tests. Keep the lid open and UI quit.
No fake sensors or forced physical sleep are used. Idle-only cases never change
global power settings; the coexistence case explicitly toggles the existing
closed-lid session and verifies its independent cleanup.
The optional --untrusted-helper flag proves idle mode still works when this
ad-hoc signed client is rejected by the separately installed privileged service.
"""
import json
import os
from pathlib import Path
import queue
import signal
import subprocess
import sys
import threading
import time

binary = str(Path(sys.argv[1]).resolve())
untrusted_helper = '--untrusted-helper' in sys.argv[2:]
selected = [x for x in sys.argv[2:] if not x.startswith('--')]


def disabled():
    rows = subprocess.check_output(['/usr/bin/pmset', '-g'], text=True).splitlines()
    return next(x.split()[1] == '1' for x in rows if x.split()[:1] == ['SleepDisabled'])


def holds(pid):
    rows = subprocess.check_output(['/usr/bin/pmset', '-g', 'assertions'], text=True, errors='replace').splitlines()
    result = []
    for index, row in enumerate(rows):
        if f'pid {pid}(' in row and 'LidLid' in row:
            timeout = next((x.strip() for x in rows[index+1:index+3] if 'Timeout' in x), '')
            result.append(row.strip() + ' ' + timeout)
    return result


def wait_for(messages, condition, timeout=12):
    until = time.monotonic() + timeout
    last = None
    while time.monotonic() < until:
        try:
            last = messages.get(timeout=max(0.01, until-time.monotonic()))
        except queue.Empty:
            break
        if condition(last):
            return last
    raise AssertionError(last)


assert not disabled(), 'Quit the LidLid UI and end other closed-lid sessions first'
if untrusted_helper:
    check = subprocess.run([binary, '--compatibility-status'], capture_output=True, text=True)
    assert check.returncode != 0, 'Expected the ad-hoc client to be rejected by the privileged service'
scenarios = ['manual off and sustained renewal', 'parent EOF', 'heartbeat timeout', 'agent SIGTERM', 'agent SIGKILL', 'frozen assertion expiry']
if not untrusted_helper:
    scenarios.append('independent closed-lid switch')
if '--allow-display-sleep' in sys.argv[2:]:
    scenarios.append('display can sleep')
if selected:
    assert all(x in scenarios for x in selected)
    scenarios = selected
report = []
for scenario in scenarios:
    child = subprocess.Popen([binary, '--agent'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
    messages = queue.Queue()
    def read(source=child.stdout, target=messages):
        for line in source:
            target.put(json.loads(line))
    reader = threading.Thread(target=read, daemon=True)
    reader.start()
    lock = threading.Lock()
    stopped = threading.Event()
    def send(action):
        with lock:
            if child.poll() is None and child.stdin and not child.stdin.closed:
                child.stdin.write(json.dumps({'action': action, 'minutes': 0}) + '\n')
                child.stdin.flush()
    def heartbeat():
        while not stopped.wait(2):
            try: send('ping')
            except (BrokenPipeError, ValueError): return
    agent_pid = None
    heartbeat_thread = None
    try:
        initial = wait_for(messages, lambda x: x.get('agentPID') is not None)
        assert not initial.get('error'), initial
        agent_pid = initial['agentPID']
        assert initial['sandboxContainer'].endswith('/Library/Containers/dev.kf.lidonce/Data')
        assert agent_pid != child.pid
        send('open-awake-on')
        awake = wait_for(messages, lambda x: x.get('openAwakeRequested') and x.get('openAwakeActive'))
        assert not awake['openAwakeError'], awake
        live = holds(agent_pid)
        assert len(live) == 1 and 'PreventUserIdleSystemSleep' in live[0], live
        assert 'TimeoutActionRelease' in live[0], live
        assert not disabled(), 'Open-lid mode must never change global SleepDisabled'
        if scenario != 'heartbeat timeout':
            heartbeat_thread = threading.Thread(target=heartbeat, daemon=True)
            heartbeat_thread.start()
        if scenario == 'manual off and sustained renewal':
            time.sleep(36)  # Longer than the system's 30-second expiry.
            assert holds(agent_pid), 'Timed assertion was not renewed'
            send('open-awake-off')
            off = wait_for(messages, lambda x: not x.get('openAwakeRequested') and not x.get('openAwakeActive'))
            assert not off['openAwakeError'], off
            assert not holds(agent_pid)
            send('quit')
        elif scenario == 'display can sleep':
            # Purpose-built power command and public display-power state only;
            # no pixels, UI input, fake user activity or display assertion.
            import ctypes
            graphics = ctypes.CDLL('/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics')
            graphics.CGMainDisplayID.restype = ctypes.c_uint32
            graphics.CGDisplayIsAsleep.argtypes = [ctypes.c_uint32]
            graphics.CGDisplayIsAsleep.restype = ctypes.c_bool
            subprocess.run(['/usr/bin/pmset', 'displaysleepnow'], check=True)
            asleep = False
            for _ in range(20):
                asleep = graphics.CGDisplayIsAsleep(graphics.CGMainDisplayID())
                if asleep: break
                time.sleep(.25)
            assert asleep, 'Display did not enter sleep during open-lid protection'
            time.sleep(3)
            assert len(holds(agent_pid)) == 1 and not disabled()
            send('open-awake-off')
            wait_for(messages, lambda x: not x.get('openAwakeActive') and not x.get('openAwakeRequested'))
            send('quit')
        elif scenario == 'parent EOF':
            stopped.set()
            with lock: child.stdin.close()
        elif scenario == 'agent SIGTERM': os.kill(agent_pid, signal.SIGTERM)
        elif scenario == 'agent SIGKILL': os.kill(agent_pid, signal.SIGKILL)
        elif scenario == 'frozen assertion expiry':
            os.kill(agent_pid, signal.SIGSTOP)
            expiry = time.monotonic() + 35
            while holds(agent_pid) and time.monotonic() < expiry:
                time.sleep(0.25)
            assert not holds(agent_pid), 'Frozen worker retained its assertion after timeout'
            os.kill(agent_pid, signal.SIGCONT)
            send('quit')
        elif scenario == 'independent closed-lid switch':
            send('arm')
            armed = wait_for(messages, lambda x: x.get('phase') == 'armed')
            assert armed['openAwakeActive'] and disabled(), armed
            send('stop')
            closed_off = wait_for(messages, lambda x: x.get('phase') == 'off')
            assert closed_off['openAwakeActive'] and closed_off['openAwakeRequested'], closed_off
            assert not disabled() and len(holds(agent_pid)) == 1
            send('open-awake-off')
            wait_for(messages, lambda x: not x.get('openAwakeActive') and not x.get('openAwakeRequested'))
            send('quit')
        child.wait(timeout=18)
        assert child.returncode == (9 if scenario == 'agent SIGKILL' else 0), child.returncode
        assert not holds(agent_pid) and not disabled()
        report.append({'case': scenario, 'passed': True, 'inheritedSandbox': True,
                       'assertionType': 'PreventUserIdleSystemSleep', 'systemTimeoutSeconds': 30,
                       'idleModeDoesNotChangeSleepDisabled': True,
                       'closedLidModeAlsoExercised': scenario == 'independent closed-lid switch',
                       'finalSleepDisabled': False,
                       'displaySleepObserved': scenario == 'display can sleep',
                       'privilegedServiceUnavailable': untrusted_helper})
    finally:
        stopped.set()
        if heartbeat_thread:
            heartbeat_thread.join(timeout=3)
        if scenario == 'frozen assertion expiry' and agent_pid:
            try: os.kill(agent_pid, signal.SIGCONT)
            except ProcessLookupError: pass
        if child.poll() is None:
            try: send('quit')
            except (BrokenPipeError, ValueError): pass
            child.wait(timeout=18)
print(json.dumps({'tests': report, 'displaySleepHeldByLidLid': False,
                  'physicalLidTest': 'not performed by this script'}, indent=2))
