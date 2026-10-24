"""Governed, non-executable learning: reviewed named aliases of vetted intentions.

Never accepts raw executables, scripts, shell fragments or arbitrary providers.
Staged -> exact rendered-command attestation -> confirm -> activation.
"""
import hashlib
import json
import re
import shlex
import time

NAME = r'[a-z][a-z0-9_-]{0,31}'


def classify(command, error):
    """A narrow capability whitelist; each underlying executor validates again."""
    s = command.strip()
    if '\x00' in s or '\n' in s or '\r' in s or len(s) > 1024:
        raise error('Learn target must be a single bounded Computer utterance', 2)
    l = s.lower()
    if re.fullmatch(r'search scopes|list search scopes|list search locations', l):
        return 'SEARCH_SCOPES'
    if re.fullmatch(r'find (?:new files|files received)(?: in my find files? location)? in (?:the )?(?:last|past) \d+ (?:minutes?|hours?) in '+NAME, l):
        return 'SEARCH_NAMED'
    if re.fullmatch(r'find dependency (?:rexx )?.+ in '+NAME, l):
        return 'SEARCH_NAMED'
    if re.fullmatch(r'(?:check free space|check free memory)(?: on ed209[a-z0-9]+)?', l):
        return 'CHECK_FREE_MEMORY' if 'memory' in l else 'CHECK_FREE_SPACE'
    if re.fullmatch(r'github (?:status|inspect|remotes|ssh) .+', l):
        return 'GITHUB'
    if re.fullmatch(r'(?:sha256|sha512|sha1|inspect) .+', l):
        return 'FILE_INTEGRITY'
    raise error('Learning permits aliases of existing inspected/read-only intentions only; new executable implementations require audited specialist registration', 4)


def _target(raw, error):
    try:
        parts = shlex.split(raw)
    except ValueError as e:
        raise error(f'Invalid quoted learning target: {e}', 2) from e
    if not parts:
        raise error('Missing learning target', 3)
    text = ' '.join(parts).strip()
    if text.casefold().startswith('computer '):
        text = text[9:].strip()
    return text


def learn(text, load, create, error, consume=None):
    if text.lower() == 'learn help':
        print('LEARN STEP 1: Computer learn NAME as "find dependency rexx crypto in dependencies"')
        print('LEARN STEP 2: Read INTENT, positional arguments and options, and COMMAND.')
        print('LEARN STEP 3: Copy the printed Computer learn review command exactly; wrong placement is refused.')
        print('LEARN STEP 4: Computer confirm TOKEN_2 activates a named read-only alias.')
        print('RUN: Computer do NAME. Inspect: Computer learn list. Unknown executables are never learned.')
        return 0
    if text.lower() == 'learn list':
        obj = load()
        for k, v in sorted(obj.get('learned', {}).items()):
            print('LEARNED name=' + k + ' intent=' + v['intent'] + ' command=' + shlex.join(['Computer', v['utterance']]))
        return 0
    m = re.fullmatch(r'learn\s+review\s+([A-Za-z0-9_-]{32})\s+(.+)', text, re.I)
    if m:
        if consume is None:
            raise error('Learning-review authority unavailable', 4)
        token, supplied = m.groups()
        doc = consume(token)
        if doc.get('intent') != 'LEARN_REVIEW':
            raise error('This token is not a learning-review record', 4)
        target = doc['utterance']
        actual = supplied.strip()
        expected = shlex.join(['Computer', target])
        if actual != expected:
            raise error('Rendered command or option/argument ordering differs; restart learning', 4)
        if classify(target, error) != doc['underlying_intent']:
            raise error('Learned command classification changed', 4)
        doc2 = {'schema': 'scotty.computer.pending/1', 'created_at': time.time(),
                'intent': 'LEARN_ACTIVATE', 'name': doc['name'], 'utterance': target,
                'underlying_intent': doc['underlying_intent'], 'command_sha256': doc['command_sha256']}
        token2 = create(doc2)
        print('STRUCTURE_ATTESTED name=' + doc['name'] + ' options/positional-order=exact')
        print('COMMAND=' + expected)
        print('NOT ACTIVATED until: Computer confirm ' + token2)
        return 3
    m = re.fullmatch(r'learn\s+('+NAME+r')\s+as\s+(.+)', text, re.I)
    if not m:
        raise error('Use: Computer learn NAME as "existing read-only Computer utterance"', 3)
    name = m.group(1).lower()
    if name in {'help', 'list', 'review', 'learn', 'confirm'}:
        raise error('Reserved learned intention name', 3)
    target = _target(m.group(2), error)
    ident = classify(target, error)
    if name in load().get('learned', {}):
        raise error('A learned intention with that name already exists; no overwrite permitted', 4)
    rendered = shlex.join(['Computer', target])
    data = {'schema': 'scotty.computer.pending/1', 'intent': 'LEARN_REVIEW',
            'created_at': time.time(), 'name': name, 'utterance': target,
            'underlying_intent': ident, 'command_sha256': hashlib.sha256(rendered.encode()).hexdigest()}
    token = create(data)
    print('LEARN_DRAFT name=' + name + ' intent=' + ident)
    print('NOT EXECUTED; NOT ACTIVATED')
    print('STRUCTURE: Computer <one quoted utterance>; subcommand and arguments inside utterance exactly as printed')
    print('POSITIONAL/OPTIONS: examine this complete argument vector: ' + json.dumps(['Computer', target]))
    print('COMMAND=' + rendered)
    print('Codex MUST present this exact command and confirm intent, options and positional order before attestation.')
    print('REVIEW: ' + shlex.join(['Computer', f'learn review {token} {rendered}']))
    print('The review consumes token 1. An exact match yields a separate activation token; command edits are refused.')
    return 3


def activate(doc, load, save, error):
    target = doc.get('utterance')
    rendered = shlex.join(['Computer', target])
    if hashlib.sha256(rendered.encode()).hexdigest() != doc.get('command_sha256'):
        raise error('Learn record changed since review', 4)
    if classify(target, error) != doc.get('underlying_intent'):
        raise error('Learned intention no longer whitelisted', 4)
    name = doc['name']
    state = load()
    learned = state.setdefault('learned', {})
    if name in learned:
        raise error('Learned intention name was registered by another process', 4)
    learned[name] = {'utterance': target, 'intent': doc['underlying_intent'],
                     'command_sha256': doc['command_sha256'], 'approved_at': time.time()}
    save(state)
    print('ACTIVATED named intention=' + name + ' intent=' + doc['underlying_intent'])
    print('RUN: Computer do ' + name)
    return 0


def run_learned(text, load, execute, error):
    m = re.fullmatch(r'do\s+('+NAME+r')', text, re.I)
    if not m:
        raise error('Use: Computer do LEARNED_NAME', 2)
    name = m.group(1).lower()
    record = load().get('learned', {}).get(name)
    if not record:
        raise error(f'Unknown learned intention {name}', 2)
    intent = classify(record['utterance'], error)
    if record['intent'] != intent:
        raise error('Learned intention classification drift', 4)
    if hashlib.sha256(shlex.join(['Computer', record['utterance']]).encode()).hexdigest() != record['command_sha256']:
        raise error('Learned intention definition drift', 4)
    print('LEARNED_DISPATCH name=' + name + ' intent=' + intent)
    return execute(intent, record['utterance'])
