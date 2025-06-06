#!/usr/bin/env python3

from pwn import *
from pwnlib.tubes.remote import remote
from binascii import unhexlify
import re
import hashlib

PATTERN = r'NASA_HW11\{[0-9A-Za-z_\':/@]+\}'

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
    matches = re.findall(PATTERN, text)
    return matches[0] if matches else None

def test_key_and_decrypt(encrypted, key):
    """Test key and decrypt, return flag if successful, None otherwise"""
    try:
        # Decrypt using the key
        decrypted = bytes(encrypted[i] ^ key[i % 10] for i in range(len(encrypted)))
        decoded = decrypted.decode("ascii", errors="replace")
        
        # Check decryption quality
        printable_ratio = sum(1 for c in decoded if c.isprintable()) / len(decoded)
        
        # Look for flag
        if printable_ratio == 1 and "NASA_HW11{" in decoded:
            flag_match = re.search(PATTERN, decoded)
            if flag_match:
                return flag_match.group(0), decoded, printable_ratio
        
        return None
    except:
        return None

def bruteforce_repeating_key_xor_flag(encrypted_hex):
    """Complete brute force approach for OTP attack"""
    
    encrypted = unhexlify(encrypted_hex)
    print(f"Encrypted data length: {len(encrypted)} bytes")
    
    # Known plaintext attack: try every possible starting position
    known_plaintext = b"NASA_HW11{"
    candidates = []

    for start_pos in range(len(encrypted) - len(known_plaintext) + 1):
        print(f"Trying position {start_pos}")
        
        # Derive key fragment from known plaintext
        partial_key = {}
        consistent = True
        
        for i in range(len(known_plaintext)):
            cipher_pos = start_pos + i
            key_pos = cipher_pos % 10  # 10-byte cycle
            
            # Calculate key byte at this position
            key_byte = encrypted[cipher_pos] ^ known_plaintext[i]
            
            # Check consistency with previously derived values
            if key_pos in partial_key:
                if partial_key[key_pos] != key_byte:
                    consistent = False
                    break
            else:
                partial_key[key_pos] = key_byte
        
        if not consistent:
            continue
        
        print(f"Position {start_pos} passed consistency check")
        print(f"Recovered key positions: {partial_key}")
        
        # Key fully recovered
        key = [partial_key[i] for i in range(10)]
        result = test_key_and_decrypt(encrypted, key)
        if result:
            flag, full_text, ratio = result
            candidates.append({
                'position': start_pos,
                'key': bytes(key),
                'flag': flag,
                'full_text': full_text,
                'printable_ratio': ratio
            })
    
    return candidates

def solve_part_a(conn: remote):
    """Build trust to 100 using LCG attack"""
    print("\n=== Part (a): LCG Attack for FLAG1 ===")

    # LCG modulus from source code
    m = 0xa34d80e56c2cd0d35209cb13e5665fc58176fac6b1fee26af23388deebee59da1a884cbba6111ea819f7a2059f0accd8b1e7e23dbe4d90896b2cd482c0b934d97e3bbdbfd26b968e9bfeb2f8df037cab44557d2cf6eb57385a191c3db536c62f781e598405bdd818ae98dfd7df48c4da55d9d5b49d75aa46c91a27a186b9bf77
    
    # Collect 3 LCG states
    states = []
    for _ in range(3):
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
    conn.sendline(b"2")
    flag1_response = conn.recvline().decode()
    print(f"Response: {flag1_response.strip()}")
    flag_start = flag1_response.find("NASA_HW11{")
    flag_end = flag1_response.find("}", flag_start) + 1
    flag1 = flag1_response[flag_start:flag_end]
    print(f"FLAG1: {flag1}")

    return True

def solve_part_b(conn: remote):
    """OTP Attack using systematic brute force approach"""
    print("\n=== Part (b): OTP Attack for FLAG2 ===")

    conn.recvuntil(b"Your choice: ")
    conn.sendline(b"3")
    
    encrypted_hex = None
    
    while True:
        line = conn.recvline(timeout=3).decode()
        
        stripped = line.strip()
        if len(stripped) > 50 and all(c in "0123456789abcdefABCDEF" for c in stripped):
            encrypted_hex = stripped
            print(f"Found encrypted data: {encrypted_hex}")
            break
    
    if not encrypted_hex:
        print("Could not find encrypted data")
        return False
        
    results = bruteforce_repeating_key_xor_flag(encrypted_hex)

    if results:
        best_result = max(results, key=lambda x: x["printable_ratio"])
        print(f"Response: {best_result['full_text']}")
        print(f"FLAG2: {best_result['flag']}")
        return True
    else:
        print("Failed to decrypt FLAG2")
        return False

def solve_part_c(conn: remote):
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
    conn.sendline(b"4")
    
    # Process 10 PoW challenges with instant lookup
    for pow_num in range(10):
        try:
            # Receive the challenge prompt
            line = conn.recvuntil(b": ").decode()
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
            if "Thanks for helping out" in line and "flag" in line:
                # Extract flag from this line
                flag_start = line.find("NASA_HW11{")
                if flag_start != -1:
                    flag_end = line.find("}", flag_start) + 1
                    flag3 = line[flag_start:flag_end]
                    print(f"FLAG3: {flag3}")
                    break
    except Exception as e:
        print(f"Error reading FLAG3 response: {e}")
        return False
    
    return True

def solve_part_d(conn: remote):
    """Club Membership Verification"""
    print("\n=== Part (d): Club Membership MAC Reuse Attack for FLAG4 ===")
    
    # The MAC only depends on SHA256(nonce||shared_key), not the username so we can get fatcat's MAC and reuse it with our own username
    print("Step 1: Get nonce")
    conn.recvuntil(b"Your choice: ")
    conn.sendline(b"5")  # Ask fatcat to verify your club membership
    
    # Read the verification setup
    line1 = conn.recvline().decode()
    line2 = conn.recvline().decode()  # get nonce
    
    print(f"Verification message: {line1.strip()}")
    print(f"Nonce line: {line2.strip()}")
    
    # Extract the nonce
    if "nonce: " not in line2:
        print("Failed to get nonce from verification")
        return False
    
    nonce = line2.split("nonce: ")[1].strip()
    print(f"Extracted nonce: {nonce}")
    
    # Step 2: Get the correct MAC by asking fatcat to prove with this nonce
    # We need to open a second connection since we're in the middle of verification
    print("Step 2: Open second connection to get MAC from fatcat")
    
    conn2 = remote("140.112.91.4", 1234)
    
    # Ask fatcat to prove with our nonce
    conn2.recvuntil(b"Your choice: ")
    conn2.sendline(b"6")  # Ask fatcat to prove his club membership
    
    conn2.recvuntil(b"Please give me a nonce: ")
    conn2.sendline(nonce.encode())  # Use the same nonce from verification
    
    proof_line = conn2.recvline().decode()
    print(f"Fatcat's proof: {proof_line.strip()}")
    
    conn2.close()
    
    # Extract MAC from proof
    if "Proof: " not in proof_line:
        print("Failed to get proof from fatcat")
        return False
    
    proof_data = proof_line.split("Proof: ")[1].strip()
    try:
        _, correct_mac = proof_data.split("||")
        print(f"Extracted MAC: {correct_mac}")
    except:
        print("Failed to parse proof")
        return False
    
    # Step 3: Use the correct MAC with our own name for verification
    print("Step 3: Submit forged response")
    
    my_name = "hacker" # can be any name except fatcat
    forged_response = f"{my_name}||{correct_mac}"
    
    print(f"Sending: {forged_response}")
    conn.sendline(forged_response.encode())
    
    # Check for FLAG4
    try:
        response = conn.recvline(timeout=5).decode()
        print(f"Response: {response.strip()}")
        
        if "MapleStory" in response and "flag" in response:
            # Extract FLAG4
            if "NASA_HW11{" in response:
                flag_start = response.find("NASA_HW11{")
                flag_end = response.find("}", flag_start) + 1
                flag4 = response[flag_start:flag_end]
                print(f"FLAG4: {flag4}")
                return True
            else:
                print("Success message but no flag found")
                return True
        else:
            print("Verification failed")
            return False
            
    except Exception as e:
        print(f"Error reading response: {e}")
        return False

def solve_all_parts():
    conn: remote = remote("140.112.91.4", 1234)
    
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
        
        # PART (D): Club Membership MAC Attack
        success_d = solve_part_d(conn)
        if not success_d:
            print("Failed to solve part (d)")
            return False

        return True

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    finally:
        conn.close()

if __name__ == "__main__":
    success = solve_all_parts()

    if success:
        print("success to solve all parts")
    else:
        print("failed to solve all parts")
