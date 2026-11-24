#!/bin/sh
# Stand-in for "nft -a list ruleset": the shape of cats1's mu_fence.
cat <<'R'
table inet mu_fence { # handle 3
	set xtp_peers { # handle 2
		type ipv4_addr
		elements = { 20.0.154.12, 20.118.224.14,
			     80.240.21.156 }
	}

	chain input { # handle 1
		type filter hook input priority filter; policy drop;
		ct state established,related accept # handle 4
		iif "lo" accept # handle 5
		tcp dport 22 accept # handle 6
		udp dport 68 accept # handle 7
		ip saddr @xtp_peers ip protocol 36 accept # handle 8
	}
}
R
