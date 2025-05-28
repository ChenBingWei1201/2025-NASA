#!/usr/bin/env python3

from pwn import *
from binascii import unhexlify
import re
import hashlib

def crack_lcg(s0, s1, s2, m):
    """Crack LCG parameters a and c"""
    numerator = (s2 - s1) % m
    denominator = (s1 - s0) % m
    
    if denominator == 0:
        return None, None
        
    try:
        a = (numerator * pow(denominator, -1, m)) % m
        c = (s1 - a * s0) % m
        return a, c
    except:
        return None, None

def find_valid_flag_in_text(text):
    """Extract valid flag from decrypted text"""
    pattern = r'NASA_HW11\{[0-9A-Za-z_\':/@]+\}'
    matches = re.findall(pattern, text)
    return matches[0] if matches else None

def try_decrypt_comprehensive(encrypted_hex):
    """Try comprehensive decryption approaches"""
    encrypted = unhexlify(encrypted_hex)
    
    # Try "NASA_HW11{" at different positions
    test_string = "NASA_HW11{"
    test_bytes = test_string.encode('ascii')
    
    best_results = []
    
    for pos in range(len(encrypted) - len(test_bytes) + 1):
        # Extract key bytes for this position
        key_fragment = []
        for i in range(len(test_bytes)):
            key_byte = encrypted[pos + i] ^ test_bytes[i]
            key_fragment.append(key_byte)
        
        # Try 10-byte repeating key
        key = [None] * 10
        
        # Fill known key bytes
        consistent = True
        for i, kb in enumerate(key_fragment):
            key_idx = (pos + i) % 10
            if key[key_idx] is None:
                key[key_idx] = kb
            elif key[key_idx] != kb:
                consistent = False
                break
        
        if not consistent:
            continue            
        # Complete partial key
        if any(k is None for k in key):
            for fill_byte in [0x00, 0x20, 0x41, 0x61, 0x30]:
                test_key = [k if k is not None else fill_byte for k in key]
                
                decrypted = []
                for i, c in enumerate(encrypted):
                    decrypted.append(c ^ test_key[i % 10])
                
                try:
                    decoded = bytes(decrypted).decode('ascii', errors='replace')
                    printable_ratio = sum(1 for c in decoded if c.isprintable()) / len(decoded)
                    
                    if printable_ratio > 0.7:
                        pattern = r'NASA_HW11\{[0-9A-Za-z_\':/@]+\}'
                        if re.search(pattern, decoded):
                            flag = find_valid_flag_in_text(decoded)
                            if flag:
                                best_results.append({
                                    'position': pos,
                                    'key': bytes(test_key),
                                    'flag': flag,
                                    'full_text': decoded,
                                    'printable_ratio': printable_ratio
                                })
                except:
                    continue
        else:
            # All key bytes known
            test_key = key
            
            decrypted = []
            for i, c in enumerate(encrypted):
                decrypted.append(c ^ test_key[i % 10])
            
            try:
                decoded = bytes(decrypted).decode('ascii', errors='replace')
                printable_ratio = sum(1 for c in decoded if c.isprintable()) / len(decoded)
                
                if printable_ratio > 0.7:
                    pattern = r'NASA_HW11\{[0-9A-Za-z_\':/@]+\}'
                    if re.search(pattern, decoded):
                        flag = find_valid_flag_in_text(decoded)
                        if flag:
                            best_results.append({
                                'position': pos,
                                'key': bytes(test_key),
                                'flag': flag,
                                'full_text': decoded,
                                'printable_ratio': printable_ratio
                            })
            except:
                continue
    
    return best_results

def solve_part_a(conn):
    """Build trust to 100 using LCG attack"""
    print("\n=== Part (a): LCG Attack for FLAG1 ===")

    # LCG modulus from source code
    m = 0xa34d80e56c2cd0d35209cb13e5665fc58176fac6b1fee26af23388deebee59da1a884cbba6111ea819f7a2059f0accd8b1e7e23dbe4d90896b2cd482c0b934d97e3bbdbfd26b968e9bfeb2f8df037cab44557d2cf6eb57385a191c3db536c62f781e598405bdd818ae98dfd7df48c4da55d9d5b49d75aa46c91a27a186b9bf77
    
    # Collect 3 LCG states
    states = []
    for i in range(3):
        conn.recvuntil(b"Your choice: ")
        conn.sendline(b'1')
        conn.recvuntil(b"Guess a number: ")
        conn.sendline(b'999999')
        
        result = conn.recvline().decode()
        if "the number I picked is" in result:
            start = result.find("the number I picked is ") + len("the number I picked is ")
            end = result.find(",", start)
            actual_number = int(result[start:end])
            states.append(actual_number)
    
    # Crack LCG parameters
    a, c = crack_lcg(states[0], states[1], states[2], m)
    if a is None or c is None:
        return False
    
    # Build trust quickly
    trust = 0
    current_state = states[-1]
    
    while trust < 100:
        next_state = (a * current_state + c) % m
        target_guess = next_state % 500
        
        conn.recvuntil(b"Your choice: ")
        conn.sendline(b'1')
        conn.recvuntil(b"Guess a number: ")
        conn.sendline(str(target_guess).encode())
        
        result = conn.recvline().decode()
        
        if "Congratulations" in result:
            trust += 1
            current_state = next_state
        else:
            trust -= 1
            if "the number I picked is" in result:
                start = result.find("the number I picked is ") + len("the number I picked is ")
                end = result.find(",", start)
                actual = int(result[start:end])
                current_state = actual
    
    conn.recvuntil(b"Your choice: ")
    conn.sendline(b'2')
    flag1_response = conn.recvline().decode()
    print(f"FLAG1: {flag1_response.strip()}")

    return True

def solve_part_b(conn):
    """OTP Attack"""
    print("\n=== Part (b): OTP Attack for FLAG2 ===")

    conn.recvuntil(b"Your choice: ")
    conn.sendline(b'3')
    
    encrypted_hex = None
    
    try:
        while True:
            line = conn.recvline(timeout=3).decode()
            
            stripped = line.strip()
            if len(stripped) > 50 and all(c in '0123456789abcdefABCDEF' for c in stripped):
                encrypted_hex = stripped
                print(f"Found encrypted data: {encrypted_hex[:60]}...")
                break
    except:
        pass
    
    if not encrypted_hex:
        print("Could not find encrypted data")
        return False
        
    print(f"Encrypted data length: {len(encrypted_hex)} hex chars")
    
    results = try_decrypt_comprehensive(encrypted_hex)
    
    if results:
        print(f"Found {len(results)} valid decryption(s):")
        for i, result in enumerate(results):
            print(f"\nDecryption {i+1}:")
            print(f"  FLAG2: {result['flag']}")
            print(f"  Full text: {result['full_text'][:100]}...")
        
        best_result = max(results, key=lambda x: x['printable_ratio'])
        print(f"\nFLAG2: {best_result['flag']}")
        return True
    else:
        print("Failed to decrypt FLAG2")
        return False

def solve_part_c(conn):
    """Proof of Work Challenge"""
    print("\n=== Part (c): Proof of Work for FLAG3 ===")

    # Build comprehensive rainbow table before starting
    print("Building comprehensive rainbow table...")
    rainbow_table = {}
    for i in range(2**24):
        hash_val = hashlib.md5(str(i).encode()).hexdigest()[:8]
        rainbow_table[hash_val] = i
    
    print(f"Rainbow table built with {len(rainbow_table)} entries")
    
    conn.recvuntil(b"Your choice: ")
    conn.sendline(b'4')
    
    # Process 10 PoW challenges with instant lookup
    for pow_num in range(10):
        try:
            # Receive the challenge prompt
            line = conn.recvuntil(b': ').decode()
            print(f"PoW {pow_num + 1}: {line.strip()}")
            
            # Extract target hash from the challenge
            if 'md5(i)[0:8] == "' in line:
                start_idx = line.find('md5(i)[0:8] == "') + len('md5(i)[0:8] == "')
                end_idx = line.find('"', start_idx)
                target_hash = line[start_idx:end_idx]
                
                print(f"Target hash: {target_hash}")
                
                # Instant lookup from rainbow table
                solution = rainbow_table.get(target_hash)
                
                if solution is not None:
                    print(f"Found solution: {solution}")
                    conn.sendline(str(solution).encode())
                else:
                    print("Hash not found in rainbow table")
                    return False
            else:
                print("Could not parse PoW challenge")
                print(f"Line was: {line}")
                return False
                
        except Exception as e:
            print(f"Error on PoW {pow_num + 1}: {e}")
            return False
    
    # Check for FLAG3 in response
    try:
        while True:
            line = conn.recvline(timeout=5).decode()
            print(f"Response: {line.strip()}")
            if 'Thanks for helping out' in line and 'flag' in line:
                # Extract flag from this line
                flag_start = line.find('NASA_HW11{')
                if flag_start != -1:
                    flag_end = line.find('}', flag_start) + 1
                    flag3 = line[flag_start:flag_end]
                    print(f"FLAG3: {flag3}")
                    break
    except Exception as e:
        print(f"Error reading FLAG3 response: {e}")
        return False
    
    return True

def solve_all_parts():
    conn = remote('140.112.91.4', 1234)
    
    try:
        # PART (A): LCG Attack
        success_a = solve_part_a(conn)
        if not success_a:
            print("Failed to solve part (a)")
            return False
        
        # PART (B): OTP Decryption
        success_b = solve_part_b(conn)
        if not success_b:
            print("Failed to solve part (b)")
            return False
        
        # PART (C): Proof of Work Challenge - Rainbow Table Approach
        success_c = solve_part_c(conn)
        if not success_c:
            print("Failed to solve part (c)")
            return False
        
        return True

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    finally:
        conn.close()

if __name__ == '__main__':
    success = solve_all_parts()

    if success:
        print("success to solve all parts")
    else:
        print("failed to solve all parts")
