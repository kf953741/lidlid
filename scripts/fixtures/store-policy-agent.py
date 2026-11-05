#!/usr/bin/env python3
"""Pipe-only worker for controller tests. Never accesses macOS power APIs."""
import json
from pathlib import Path
import sys

template, log, phase = sys.argv[1:]
state = json.loads(Path(template).read_text())

def emit():
    print(json.dumps(state), flush=True)

emit()
for line in sys.stdin:
    command = json.loads(line)
    with open(log, 'a') as output:
        output.write(json.dumps(command) + '\n')
    action = command['action']
    if action == 'arm':
        state['phase'] = phase
    elif action in ('stop', 'test-reopened'):
        state['phase'] = 'off'
    elif action == 'open-awake-on':
        state['openAwakeRequested'] = state['openAwakeActive'] = True
    elif action == 'open-awake-off':
        state['openAwakeRequested'] = state['openAwakeActive'] = False
    elif action == 'quit':
        state['phase'] = 'off'
        state['openAwakeRequested'] = state['openAwakeActive'] = False
        emit()
        break
    emit()
