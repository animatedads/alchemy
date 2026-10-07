#!/usr/bin/env python3
import collections, json, sys

def norm_path(path):
    parts=path.replace('\\','/').split('/')
    if parts and parts[0].startswith('oorexx_development_floor_'):
        parts=parts[1:]
    return '/'.join(parts)

def fp(path, finding):
    return (norm_path(path), finding.get('rule',''), finding.get('snippet',''))

if len(sys.argv) != 3:
    raise SystemExit('usage: check_standards_warning_delta.py BASELINE REPORT')
baseline=json.load(open(sys.argv[1],encoding='utf-8'))
report=json.load(open(sys.argv[2],encoding='utf-8'))
if report.get('errors',0) != 0 or report.get('verdict') != 'PASS':
    raise SystemExit(f"FAIL standards errors/verdict errors={report.get('errors')} verdict={report.get('verdict')}")
allowed=collections.Counter((x['path'],x['rule'],x.get('snippet','')) for x in baseline['allowed'])
current=collections.Counter()
for item in report.get('reports',[]):
    for finding in item.get('findings',[]):
        if finding.get('severity') == 'WARN':
            current[fp(item.get('path',''),finding)] += 1
new=current-allowed
resolved=allowed-current
if new:
    print('FAIL new standards warnings:')
    for x,count in sorted(new.items()): print('  ',count,x)
    raise SystemExit(1)
print(f"PASS standards warning delta current={sum(current.values())} allowed={sum(allowed.values())} resolved={sum(resolved.values())} new=0")
for x,count in sorted(resolved.items()):
    print('RESOLVED',count,x)
