#!/usr/bin/env python3
"""Send keystrokes into QEMU VM via monitor socket to automate AInux setup."""
import socket, sys, time

SOCK = sys.argv[1]
KMAP = {' ':'spc','/':'slash','.':'dot','-':'minus',':':'shift-semicolon','=':'equal','_':'shift-minus',',':'comma',';':'semicolon',"'":'apostrophe','"':'shift-apostrophe','!':'shift-1','@':'shift-2','#':'shift-3','$':'shift-4','%':'shift-5','&':'shift-7','*':'shift-8','(':'shift-9',')':'shift-0','+':'shift-equal','?':'shift-slash','\\':'backslash','|':'shift-backslash','[':'bracket_left',']':'bracket_right','{':'shift-bracket_left','}':'shift-bracket_right','~':'shift-grave_accent','`':'grave_accent','<':'shift-comma','>':'shift-dot'}

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCK); s.settimeout(2)
try: s.recv(4096)
except: pass

def sk(k):
    try:
        s.sendall(f"sendkey {k}\n".encode()); time.sleep(0.05)
        try: s.recv(1024)
        except socket.timeout: pass
    except BrokenPipeError:
        print("  ❌ Lost QEMU connection"); sys.exit(1)

def ty(text):
    for c in text:
        if c in KMAP: sk(KMAP[c])
        elif c.isupper(): sk(f"shift-{c.lower()}")
        elif c.isalnum(): sk(c)
        else: sk("spc")

def ln(text, wait=1):
    ty(text); sk("ret"); time.sleep(wait)

def log(m): print(f"  🐋 {m}")

log("[1/9] Logging in as root...")
ln("root", 3)

log("[2/9] Setting up networking...")
ln("setup-interfaces -a", 5)
ln("ifup eth0", 5)
ln("setup-apkrepos -1", 5)

log("[3/9] Partitioning disk...")
ln("apk add e2fsprogs sfdisk", 10)
# Simple single-partition layout
ln('echo ",,L,*" | sfdisk /dev/vda', 5)
ln("mkfs.ext4 -F /dev/vda1", 8)
ln("mount /dev/vda1 /mnt", 2)

log("[4/9] Installing Alpine to disk (60s)...")
ln("setup-disk -m sys /mnt", 90)

log("[5/9] Mounting chroot and installing packages...")
# Separate commands — no && to avoid sendkey issues
ln("mount --bind /proc /mnt/proc", 1)
ln("mount --bind /sys /mnt/sys", 1)
ln("mount --bind /dev /mnt/dev", 1)
ln('chroot /mnt sed -i "s/#.*community/community/" /etc/apk/repositories', 2)
ln("chroot /mnt apk update", 15)

log("[6/9] Installing Node.js, Chromium, Cage (this takes ~2min)...")
ln("chroot /mnt apk add nodejs npm git chromium cage font-dejavu dbus bash sudo openssh", 120)

log("[7/9] Cloning OpenWhale...")
ln("chroot /mnt mkdir -p /opt/ainux", 1)
ln("chroot /mnt git clone https://github.com/viralcode/openwhale.git /opt/ainux/openwhale", 60)
ln("chroot /mnt sh -c 'cd /opt/ainux/openwhale; npm install --legacy-peer-deps' ", 120)

log("[8/9] Creating user + services...")
ln("chroot /mnt adduser -D -s /bin/bash ainux", 1)
ln("echo 'ainux:ainux' | chroot /mnt chpasswd", 1)
ln("chroot /mnt addgroup ainux wheel", 1)
ln("chroot /mnt addgroup ainux video", 1)
ln("chroot /mnt addgroup ainux input", 1)
ln("echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /mnt/etc/sudoers", 1)
ln("echo 'PORT=7777' > /mnt/opt/ainux/openwhale/.env", 1)
ln("echo 'AINUX_MODE=true' >> /mnt/opt/ainux/openwhale/.env", 1)
ln("chroot /mnt chown -R ainux:ainux /opt/ainux /home/ainux", 2)

# OpenWhale service — write line by line
ln("cat > /mnt/etc/init.d/openwhale << 'E'", 0.3)
ln("#!/sbin/openrc-run", 0.3)
ln('name="OpenWhale"', 0.3)
ln('command="/usr/bin/node"', 0.3)
ln('command_args="/opt/ainux/openwhale/openwhale.mjs"', 0.3)
ln('command_user="ainux"', 0.3)
ln("command_background=true", 0.3)
ln('pidfile="/run/openwhale.pid"', 0.3)
ln('directory="/opt/ainux/openwhale"', 0.3)
ln("depend() { need net; }", 0.3)
ln("E", 1)
ln("chmod +x /mnt/etc/init.d/openwhale", 1)

# GUI service
ln("cat > /mnt/etc/init.d/ainux-gui << 'E'", 0.3)
ln("#!/sbin/openrc-run", 0.3)
ln('name="AInux GUI"', 0.3)
ln('command="/usr/bin/cage"', 0.3)
ln('command_args="-- chromium --no-sandbox --disable-gpu --no-first-run --kiosk --app=http://localhost:7777/dashboard"', 0.3)
ln('command_user="ainux"', 0.3)
ln("command_background=true", 0.3)
ln('pidfile="/run/ainux-gui.pid"', 0.3)
ln("depend() { need openwhale; }", 0.3)
ln("start_pre() { mkdir -p /tmp/xdg; chown ainux /tmp/xdg; chmod 700 /tmp/xdg; sleep 8; }", 0.3)
ln("E", 1)
ln("chmod +x /mnt/etc/init.d/ainux-gui", 1)

ln("chroot /mnt rc-update add dbus default", 1)
ln("chroot /mnt rc-update add openwhale default", 1)
ln("chroot /mnt rc-update add ainux-gui default", 1)
ln("chroot /mnt rc-update add openssh default", 1)
ln("echo ainux > /mnt/etc/hostname", 1)

log("[9/9] Rebooting into AInux!")
ln("sync", 2)
ln("reboot", 5)

s.close()
log("")
log("Done! AInux is rebooting.")
log("OpenWhale: http://localhost:7777")
log("SSH: ssh ainux@localhost -p 2222 (pass: ainux)")
