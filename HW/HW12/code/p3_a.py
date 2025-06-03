import hashlib

target_hash = '40c3d69c8a012e181bd63d215d61a1df44e8fe7c182da6d24f26b0fae5348010'
found = False

with open('xato-net-10-million-passwords-1000000.txt', 'r', encoding='utf-8', errors='ignore') as f:
    for line_num, password in enumerate(f, 1):
        password = password.strip()
        if hashlib.sha256(password.encode('utf-8')).hexdigest() == target_hash:
            print(f'Password found: {password}')
            print(f'Found at line: {line_num}')
            found = True
            break
        if line_num % 100000 == 0:
            print(f'Checked {line_num} passwords')

if not found:
    print('Password not found in dictionary')
