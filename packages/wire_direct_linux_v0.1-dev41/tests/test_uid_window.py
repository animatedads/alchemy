class CompactUidSet:
    def __init__(self,n): self.n=n; self.calls=[]
    def count(self): return self.n
    def uid_at(self,n): self.calls.append(n); return 1000000+n
u=CompactUidSet(200000); start,count=8700,100
rows=[u.uid_at(o) for o in range(start+1,min(start+count,u.count())+1)]
assert len(rows)==100 and u.calls==list(range(8701,8801))
print('PASS 200000-message IMAP ordinal window: 100 identities touched')
