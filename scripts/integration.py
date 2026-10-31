#!/usr/bin/env python3
"""Real, reversible open-lid API checks. Never synthesizes a lid event or sleep.
Run with the lid open, no external monitor, Clamshell and LidLid UI both quit.
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

def wait(messages, phase, seconds=6):
    end = time.monotonic() + seconds
    last = None
    while time.monotonic() < end:
        try:
            last = messages.get(timeout=max(0.01, end - time.monotonic()))
        except queue.Empty:
            break
        if last.get("error"):
            raise AssertionError(last)
        if last["phase"] == phase:
            return last
    raise AssertionError(f"Waiting for {phase}: {last}")

def send(child, action):
    child.stdin.write(json.dumps({"action": action, "minutes": 0}) + "\n")
    child.stdin.flush()

for scenario in ("manual cancel", "parent pipe EOF", "heartbeat timeout", "agent SIGTERM"):
    child, messages = start()
    try:
        wait(messages, "off")
        send(child, "arm")
        armed = wait(messages, "armed")
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
        # Heartbeat case intentionally sends nothing for 12 seconds.
        child.wait(timeout=18)
        assert child.returncode == 0, child.returncode
        assert not assertions_for(agent_pid)
        events = (container / "Library/Application Support/LidOnce/events.log").read_text()
        assert any(f"pid={agent_pid} restore: selector12(false) accepted; assertions released" in line
                   for line in events.splitlines()), "Cleanup call was not recorded as successful"
        report.append({"case": scenario, "passed": True, "assertionsWhileArmed": len(holds),
                       "inheritedSandbox": True, "restoreCallAccepted": True,
                       "onBattery": armed["onBattery"],
                       "duplicateAgentRejected": scenario == "manual cancel"})
    finally:
        if child.poll() is None:
            try: child.stdin.close()
            except Exception: pass
            child.wait(timeout=8)

print(json.dumps({"tests": report, "physicalLidTest": "not performed"}, ensure_ascii=False, indent=2))
