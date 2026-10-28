"""Mirror of readFacts subject rules: a code block after a blank line or a heading names the SUBJECT;
a code block right after a text line names a SUB subject (subject + its first word); 'the code:' etc. are examples."""
import re,sys,collections
def subject_of(line):
    t=re.sub(r'\[[^\]]*\]',' ',line)          # drop [optional] parts (one level is enough for names)
    t=t.split('(')[0] if not t.lstrip().startswith('(') else t
    p=t.split()
    if not p: return line.split()[0] if line.split() else '-'
    out=[p[0]]
    for w in p[1:4]:
        if re.fullmatch(r'[+-]?\d+',w) or re.fullmatch(r'[A-Z][A-Z0-9_.]*',w): out.append(w)
        else: break
    return ' '.join(out)
def sub_of(main, line):
    s=subject_of(line)
    return s if s.split()[0]==main.split()[0] else main+' '+s
def subjects(f):
    out=[]; incode=False; pending=False; first=False; prev_blank=True; main='-'; kind=''
    for l in open(f):
        s=l.strip()
        if s.startswith('```'):
            incode=not incode
            if incode:
                kind='EX' if pending else ('SUBJECT' if prev_blank else 'SUB'); pending=False; first=True
            prev_blank=False; continue
        if incode:
            if first and kind=='SUBJECT': main=subject_of(s); out.append(main)
            elif first and kind=='SUB': out.append(sub_of(main,s))
            first=False; continue
        if s in('the code:','the result:','the reference says:'): pending=True
        prev_blank = (s=='' or s.startswith('#'))
    return out
if __name__=='__main__':
    for f in sys.argv[1:]:
        o=subjects(f); print(f,len(o),'subjects:', ' | '.join(o[:45]))
