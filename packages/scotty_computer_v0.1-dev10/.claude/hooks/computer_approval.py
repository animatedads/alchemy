#!/usr/bin/env python3
"""Claude Code PreToolUse guard for Computer approval operations.

This is a tool-use permission request, not cryptographic proof of a human
identity. It applies only when installed/enabled in Claude Code.
"""
import json
import re
import sys

PROTECTED = re.compile(
    r'(?i)\b(?:confirm\b|job\s+(?:approve|policy|revoke|exception\s+(?:register|add))\b)'
)
COMPUTER = re.compile(r'(?i)\bcomputer\b')
EXECUTOR = re.compile(r'(?i)\bComputerActions\.py\b')


def classify(command):
    if EXECUTOR.search(command) and re.search(r'(?i)\s--intent\s+', command):
        return ('deny', 'Call the ooRexx Computer front-end, not its private backend.')
    if COMPUTER.search(command) and PROTECTED.search(command):
        return ('ask', 'Computer requires operator review of the exact command, target, positional arguments, and options before approval or confirmation. Inspect the rendered command and effects.')
    return None


def main():
    try:
        context = json.load(sys.stdin)
    except (ValueError, TypeError):
        context = {}
    if context.get('tool_name') != 'Bash':
        return 0
    command = context.get('tool_input', {}).get('command', '')
    if not isinstance(command, str):
        return 0
    verdict = classify(command)
    if verdict:
        decision, reason = verdict
        print(json.dumps({'hookSpecificOutput': {
            'hookEventName': 'PreToolUse',
            'permissionDecision': decision,
            'permissionDecisionReason': reason
        }}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
