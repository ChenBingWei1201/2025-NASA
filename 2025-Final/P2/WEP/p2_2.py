from Crypto.Cipher import ARC4
from binascii import unhexlify
import itertools
import string
import multiprocessing as mp

# known parameters
IV = b"\x8e\x44\xb2"
PREFIX = "nasa2025"
TARGET_KEYSTREAM = unhexlify("aab9dc42a8845b076e94e6140f13e324d5b2c75beea4921be87a9cc923da4236f3080dd810489240daee2978d40304")
CHARS = string.ascii_lowercase + string.digits

# single key verification function
def check_key(suffix):
    key = (PREFIX + ''.join(suffix)).encode()
    rc4 = ARC4.new(IV + key)
    stream = rc4.encrypt(b"\x00" * len(TARGET_KEYSTREAM))
    if stream == TARGET_KEYSTREAM:
        return key.decode()  # return correct key
    return None

# main
def crack():
    pool = mp.Pool(mp.cpu_count())  # use all CPU cores
    print(f"{mp.cpu_count()} processes")

    for result in pool.imap_unordered(check_key, itertools.product(CHARS, repeat=5), chunksize=1000):
        if result:
            print("KEY:", result)
            pool.terminate()
            return

if __name__ == "__main__":
    crack()
