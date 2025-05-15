from Crypto.Util.number import long_to_bytes
from secret import c, d, n

msg = pow(c, d, n)
flag = long_to_bytes(msg).decode()

print(f"Flag: {flag}")
