"""Root on ephemeral Ubuntu runner. Restrict tester UID, not the emulator's transit APIs."""
import ipaddress
import os
import pwd
import socket
import subprocess
from urllib.parse import urlsplit

url = urlsplit(os.environ['LLM_BASE_URL'])  # already checked by probe.py
uid = str(pwd.getpwnam('yabus-agent').pw_uid)
try:
    addresses = {ipaddress.ip_address(row[4][0]) for row in socket.getaddrinfo(url.hostname, url.port or 443, type=socket.SOCK_STREAM)}
except (OSError, ValueError):
    raise SystemExit('Cannot resolve the CPA host for the agent egress allowlist.') from None
with open('/etc/resolv.conf') as resolv:
    dns = {ipaddress.ip_address(r.split()[1]) for r in resolv if r.startswith('nameserver ')}
for ipversion, binary in ((4, 'iptables'), (6, 'ip6tables')):
    def rule(*args):
        # Do not let a CalledProcessError print rule arguments (CPA addresses).
        if subprocess.run([binary, *args], capture_output=True).returncode:
            raise SystemExit('Failed to install the tester egress policy.')
    chain = 'YABUS_AGENT'
    rule('-N', chain)
    for addr in dns:
        if addr.version == ipversion:
            for proto in ('tcp', 'udp'):
                rule('-A', chain, '-d', str(addr), '-p', proto, '--dport', '53', '-j', 'ACCEPT')
    if ipversion == 4:
        for port in ('5037', '5554'):  # adb server and emulator console (geo fix)
            rule('-A', chain, '-d', '127.0.0.1', '-p', 'tcp', '--dport', port, '-j', 'ACCEPT')
    for addr in addresses:
        if addr.version == ipversion:
            rule('-A', chain, '-d', str(addr), '-p', 'tcp', '--dport', str(url.port or 443), '-j', 'ACCEPT')
    rule('-A', chain, '-j', 'REJECT')
    rule('-I', 'OUTPUT', '1', '-m', 'owner', '--uid-owner', uid, '-j', chain)
