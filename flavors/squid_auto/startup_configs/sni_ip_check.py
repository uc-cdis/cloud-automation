#!/usr/bin/env python3
"""Squid external ACL: OK only if the TLS SNI resolves to the intercepted destination IP.
Input per line: "<sni> <original-dst-ip>". Output: OK / ERR."""
import socket, sys
for line in sys.stdin:
    parts = line.split()
    if len(parts) < 2 or parts[0] == "-":
        print("ERR message=no-sni", flush=True); continue
    sni, dst = parts[0], parts[1].strip("[]")
    try:
        ips = {ai[4][0] for ai in socket.getaddrinfo(sni, 443, proto=socket.IPPROTO_TCP)}
    except Exception as e:
        print(f"ERR message=resolve-fail", flush=True); continue
    ok = dst in ips
    sys.stderr.write(f"sni_ip_check sni={sni} dst={dst} resolved={sorted(ips)} -> {'OK' if ok else 'ERR'}\n")
    print("OK" if ok else "ERR message=sni-dst-mismatch", flush=True)
