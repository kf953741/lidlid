#!/usr/bin/env python3
"""Real, reversible open-lid API checks. Never synthesizes a lid event or sleep.
Run with the lid open, no external monitor, Clamshell and LidLid UI both quit.
"""
import json
import os
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
        if last["phase"] == phase:
            return last
        if last.get("error"):
            raise AssertionError(last)
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
        holds = assertions_for(child.pid)
        assert len(holds) == 2, holds
        if scenario == "manual cancel":
            send(child, "stop")
            stopped = wait(messages, "off")
            assert not assertions_for(child.pid)
            send(child, "quit")
        elif scenario == "parent pipe EOF":
            child.stdin.close()
        elif scenario == "agent SIGTERM":
            child.send_signal(signal.SIGTERM)
        # Heartbeat case intentionally sends nothing for 12 seconds.
        child.wait(timeout=18)
        assert child.returncode == 0, child.returncode
        assert not assertions_for(child.pid)
        report.append({"case": scenario, "passed": True, "assertionsWhileArmed": len(holds)})
    finally:
        if child.poll() is None:
            try: child.stdin.close()
            except Exception: pass
            child.wait(timeout=8)

print(json.dumps({"tests": report, "physicalLidTest": "not performed"}, ensure_ascii=False, indent=2))
