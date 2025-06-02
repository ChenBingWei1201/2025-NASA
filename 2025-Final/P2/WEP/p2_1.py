from scapy.all import rdpcap, Raw
from binascii import hexlify

PLAINTEXT = b"GET /index.html HTTP/1.1\r\nHost: example.com\r\n\r\n"
TARGET_SRC = "de:ad:be:ef:00:01"
TARGET_IV = b"\x8e\x44\xb2"

packets = rdpcap("/home/joe/code/2025-NASA/2025-Final/2025-final-big/2025-final/wireless_final2025/WEP/lab.pcap")

for pkt in packets:
    if pkt.haslayer(Raw) and pkt.src == TARGET_SRC:
        raw = bytes(pkt[Raw].load)
        iv = raw[:3]
        if iv == TARGET_IV:
            cipher = raw[3:]
            keystream = bytes([c ^ p for c, p in zip(cipher, PLAINTEXT)])
            print("Keystream (hex):", hexlify(keystream).decode())
            break
