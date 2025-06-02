#!/usr/bin/env python3
from scapy.all import *
from Crypto.Cipher import ARC4
import os, random

KEY        = b"nasa2025xxxxx"        #find the password by youself
IV_LEN     = 3
N_REAL     = 100
N_FAKE     = 100
PLAINTEXT  = b"GET /index.html HTTP/1.1\r\nHost: example.com\r\n\r\n"
assert len(PLAINTEXT) == 47 
REAL_SRC   = "de:ad:be:ef:00:01"
FAKE_SRC   = "ba:dd:fa:ce:00:01"
DST        = "ff:ff:ff:ff:ff:ff"


def rc4(iv: bytes, plain: bytes, key: bytes) -> bytes:
    return ARC4.new(iv + key).encrypt(plain)

pkts, ivs = [], set()

for _ in range(N_REAL):
    iv = os.urandom(IV_LEN)
    while iv in ivs:                       
        iv = os.urandom(IV_LEN)
    ivs.add(iv)

    cipher = rc4(iv, PLAINTEXT, KEY)       
    load   = iv + cipher
    pkts.append(Ether(src=REAL_SRC, dst=DST) / Raw(load))

for _ in range(N_FAKE):
    iv     = os.urandom(IV_LEN)
    noise  = os.urandom(len(PLAINTEXT))
    load   = iv + noise
    pkts.append(Ether(src=FAKE_SRC, dst=DST) / Raw(load))

random.shuffle(pkts)
wrpcap("lab.pcap", pkts)

with open("plain.txt", "wb") as f:
    f.write(PLAINTEXT)

print("✅  generated  lab.pcap  (+  plain.txt)")
