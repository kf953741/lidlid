#!/usr/bin/env python3
"""Real, reversible open-lid API checks. Never synthesizes a lid event or sleep.
Run with the lid open, no external monitor, Clamshell and LidLid UI both quit,
and the independently installed compatibility service approved in macOS.
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

binary = os.path.abspath(sys.argv[1])
report = []

def assertions_for(pid):
    result = subprocess.check_output(["/usr/bin/pmset", "-g", "assertions"], text=True)
    return [line.strip() for line in result.splitlines() if f"pid {pid}(" in line and any(name in line for name in ("LidLid", "LidOnce"))]

def start():
    child = subprocess.Popen([binary, "--agent"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
    messages = queue.Queue()
    def read():
        for line in child.stdout:
            messages.put(json.loads(line))
    threading.Thread(target=read, daemon=True).start()
    return child, messages

def wait(messages, phase, seconds=16, require_ready=False):
    end = time.monotonic() + seconds
    last = None
    while time.monotonic() < end:
        try:
            last = messages.get(timeout=max(0.01, end - time.monotonic()))
        except queue.Empty:
            break
        if last.get("error"):
            raise AssertionError(last)
        if last["phase"] == phase and (not require_ready or last.get("compatibilityReady")):
            return last
    raise AssertionError(f"Waiting for {phase}: {last}")

def send(child, action):
    child.stdin.write(json.dumps({"action": action, "minutes": 0}) + "\n")
    child.stdin.flush()

def sleep_disabled():
    output = subprocess.check_output(["/usr/bin/pmset", "-g"], text=True)
    values = [line.split()[1] for line in output.splitlines() if line.split()[:1] == ["SleepDisabled"]]
    assert len(values) == 1, output
    return values[0] == "1"

assert not sleep_disabled(), "Quit other sleep controllers before running this test"
for scenario in ("manual cancel", "parent pipe EOF", "heartbeat timeout", "agent SIGTERM", "agent SIGKILL"):
    child, messages = start()
    try:
        wait(messages, "off", require_ready=True)
        send(child, "arm")
        armed = wait(messages, "armed")
        assert sleep_disabled(), "Service must read back the global override before reporting On"
        agent_pid = armed["agentPID"]
        assert agent_pid != child.pid, "Test must use the embedded session agent"
        container = Path(armed["sandboxContainer"])
        assert str(container).endswith("/Library/Containers/dev.kf.lidonce/Data"), armed
        holds = assertions_for(agent_pid)
        assert len(holds) == 1 and "PreventUserIdleSystemSleep" in holds[0], holds
        if scenario == "manual cancel":
            # A rejected second process must not clear the first process's hold.
            duplicate, duplicate_messages = start()
            try:
                rejected = duplicate_messages.get(timeout=6)
                assert rejected.get("error") and "另一个盖盖会话" in rejected["message"], rejected
                duplicate.wait(timeout=6)
                assert duplicate.returncode == 1, duplicate.returncode
                assert len(assertions_for(agent_pid)) == 1
            finally:
                if duplicate.poll() is None:
                    duplicate.stdin.close()
                    duplicate.wait(timeout=8)
            send(child, "stop")
            stopped = wait(messages, "off")
            assert not assertions_for(agent_pid)
            send(child, "quit")
        elif scenario == "parent pipe EOF":
            child.stdin.close()
        elif scenario == "agent SIGTERM":
            os.kill(agent_pid, signal.SIGTERM)
        elif scenario == "agent SIGKILL":
            os.kill(agent_pid, signal.SIGKILL)
        # Heartbeat case intentionally sends nothing for 12 seconds.
        child.wait(timeout=18)
        assert child.returncode == (9 if scenario == "agent SIGKILL" else 0), child.returncode
        end = time.monotonic() + 35
        while sleep_disabled() and time.monotonic() < end:
            time.sleep(0.25)
        assert not sleep_disabled(), "Original global sleep setting was not restored"
        assert not assertions_for(agent_pid)
        events = (container / "Library/Application Support/LidOnce/events.log").read_text()
        if scenario != "agent SIGKILL":
            assert any(f"pid={agent_pid} restore: original sleep setting confirmed;" in line
                       for line in events.splitlines()), "Cleanup confirmation was not recorded"
        report.append({"case": scenario, "passed": True, "assertionsWhileArmed": len(holds),
                       "inheritedSandbox": True, "originalSleepSettingRestored": True,
                       "onBattery": armed["onBattery"],
                       "duplicateAgentRejected": scenario == "manual cancel"})
    finally:
        if child.poll() is None:
            try: child.stdin.close()
            except Exception: pass
            child.wait(timeout=8)

print(json.dumps({"tests": report, "physicalLidTest": "not performed"}, ensure_ascii=False, indent=2))
