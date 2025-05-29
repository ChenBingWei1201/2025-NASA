#!/usr/bin/env python3

from pwn import *
from Crypto.Util.number import *
import gmpy2
import time
from functools import reduce

def chinese_remainder_theorem(remainders, moduli):
    # 中國剩餘定理
    total = 0
    prod = reduce(lambda a, b: a * b, moduli)
    
    for r_i, n_i in zip(remainders, moduli):
        p = prod // n_i
        total += r_i * pow(p, -1, n_i) * p
    
    return total % prod

def hastad_attack(ciphertexts, e):
    # Håstad attack
    print(f"[+] Attempting Håstad's attack with e = {e}")
    
    if len(ciphertexts) < e:
        print(f"[-] Need at least {e} ciphertexts")
        return None
    
    # 取前 e 個密文
    selected = ciphertexts[:e]
    remainders = [c for n, c in selected]
    moduli = [n for n, c in selected]
    
    print(f"[+] Using {len(selected)} ciphertexts:")
    for i, (n, c) in enumerate(selected):
        print(f"    #{i+1}: n = {n.bit_length()} bits, c = {c.bit_length()} bits")
    
    try:
        # 使用中國剩餘定理解出 m^e
        m_to_e = chinese_remainder_theorem(remainders, moduli)
        print(f"[+] Computed m^e from CRT: {m_to_e.bit_length()} bits")
        
        # 計算 e 次方根
        m, is_exact = gmpy2.iroot(m_to_e, e)
        print(f"[+] Computed {e}-th root: exact = {is_exact}")
        
        if is_exact:
            print(f"[+] Håstad attack successful!")
            return int(m)
        else:
            print(f"[-] Root is not exact")
            return None
            
    except Exception as ex:
        print(f"[-] Håstad attack failed: {ex}")
        return None

def main():
    # ========= Step 1: 簽名偽造 =========
    print(f"\n{'='*20} STEP 1: SIGNATURE FORGERY {'='*20}")
    
    soyo = remote("140.112.91.4", 11452)
    
    # 取得 Soyo 公鑰
    soyo.recvuntil(b'> ')
    soyo.sendline(b'1')
    soyo.recvuntil(b'(e, n): (')
    e_n = soyo.recvline().strip().decode().split(', ')
    e_soyo = int(e_n[0])
    n_soyo = int(e_n[1][:-1])
    print(f"[+] Soyo public key: e = {e_soyo}, n = {n_soyo.bit_length()} bits")

    # 偽造簽名
    target = b"name=soyo"
    m_target = bytes_to_long(target)
    m1 = b"hello"
    m1_int = bytes_to_long(m1)
    m2_int = (m_target * inverse(m1_int, n_soyo)) % n_soyo
    m2 = long_to_bytes(m2_int)

    def sign(msg: bytes):
        soyo.recvuntil(b'> ')
        soyo.sendline(b'2')
        soyo.recvuntil(b'message you')
        soyo.send(msg + b'\n')
        soyo.recvuntil(b'signature: ')
        return int(soyo.recvline().strip())

    s1 = sign(m1)
    s2 = sign(m2)
    fake_sig = (s1 * s2) % n_soyo
    print(f"[+] Signature forgery complete!")
    
    soyo.close()

    # ========= Step 2: 收集密文 =========
    print(f"\n{'='*20} STEP 2: COLLECTING CIPHERTEXTS {'='*20}")
    
    ciphertexts = []
    flag1 = None
    
    # 收集 8 個密文 (e=7 只需要 7 個)
    for i in range(8):
        print(f"\n[+] Connection #{i+1}/8")
        
        anon = remote("140.112.91.4", 11451)
        
        # 身份驗證
        anon.recvuntil(b'ID: ')
        anon.sendline(b'name=soyo')
        anon.recvuntil(b'Signature: ')
        anon.sendline(str(fake_sig).encode())

        # 取得 FLAG1 (只在第一次)
        response = anon.recvuntil(b'> ')
        if i == 0:
            if b"Here is the flag just for you" in response:
                print("[+] Authentication successful!")
                for line in response.decode().splitlines():
                    if "NASA_HW11{" in line:
                        flag1 = line.strip()
                        print(f"[+] FLAG1: {flag1}")

        # 取得公鑰和密文
        anon.sendline(b'1')
        anon.recvuntil(b'(e, n): (')
        e_n = anon.recvline().strip().decode().split(', ')
        e = int(e_n[0])
        n = int(e_n[1][:-1])

        anon.recvuntil(b'> ')
        anon.sendline(b'2')
        anon.recvuntil(b'c: ')
        c = int(anon.recvline().strip())
        
        ciphertexts.append((n, c))
        print(f"    e = {e}, n = {n.bit_length()} bits, c = {c.bit_length()} bits")
        
        anon.close()
        time.sleep(0.1)

    # ========= Step 3: Håstad 攻擊 =========
    print(f"\n{'='*20} STEP 3: HÅSTAD ATTACK {'='*20}")
    
    # 執行 Håstad attack
    result = hastad_attack(ciphertexts, 7)
    
    flag2 = None
    if result:
        flag_bytes = long_to_bytes(result)
        flag_text = flag_bytes.decode('utf-8')
        print(f"[+] Decrypted diary: {flag_text}")
        
        # 提取 FLAG2
        import re
        flag_match = re.search(r'NASA_HW11\{[^}]+\}', flag_text)
        if flag_match:
            flag2 = flag_match.group(0)

    return flag1, flag2

if __name__ == "__main__":
    main()
