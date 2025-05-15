from Crypto.Util.number import getPrime, inverse

e = 65537
l = 2048  # bit 長度
p = getPrime(l)
q = getPrime(l)
n = p * q
phi = (p - 1) * (q - 1)
d = inverse(e, phi)  # 計算私鑰 d

print(f"n = {n}\ne = {e}\nd = {d}")
