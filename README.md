# Born2beroot

A reproducible, auditable setup of a minimal **Debian (latest stable)** server that implements strict security hardening, LVM with encryption, SSH on a non‑default port, a host firewall, AppArmor, and a `monitoring.sh` script that periodically prints system health to all logged‑in terminals.

> ⚠️ This README intentionally uses placeholders instead of real secrets. **Do not commit passwords, passphrases, or IPs to your repository.** Replace anything shown in `<ANGLE_BRACKETS>` with your own values during setup.

---

## Table of Contents

- [Project Goals](#-project-goals)
- [Virtual Machine & OS](#step-1-virtual-machine--os)
- [Disk Layout (LVM)](#step-2-disk-layout-lvm)
- [Package Manager](#step-3-package-manager)
- [Users & Groups](#step-4-users--groups)
- [Initial Setup & Sudo Hardening](#step-5-initial-setup--sudo-hardening)
- [Password Policy](#step-6-password-policy)
- [SSH](#step-7-ssh)
- [Firewall (UFW)](#step-8-firewall-ufw)
- [AppArmor](#step-9-apparmor)
- [Monitoring Script](#step-10-monitoring-script)
- [Verification & Evaluation Checklist](#final-verification--evaluation-checklist)
- [Signature (checksum) of the VM image](#signature-checksum-of-the-vm-image)
- [Author](#author)

---

## 📌 Project Goals

- Install the **latest stable Debian** (server profile, no GUI/X.org).
- Hostname must **end with `42`** and may be modified during evaluation.
- Create an extra user (your 42 login) besides `root`; this user must belong to **`user42`** and **`sudo`** groups.
- Use **at least two LVM logical volumes** on **encrypted storage** (e.g., `/` and `swap`; `/home` recommended).
- Install and configure security components:
  - **sudo** with strict rules (limited attempts, custom error message, I/O logging, TTY required, restricted secure path).
  - **Strong password policy** via `login.defs` and `libpam-pwquality`.
  - **SSH** listening on **port `4242`** with **root login disabled**.
  - **UFW** firewall allowing **only** port `4242/tcp`.
  - **AppArmor** enabled at boot.
- Provide a `monitoring.sh` that displays system metrics on all terminals every 10 minutes at startup.

### Bonus (optional)

- Place additional mount points (`/var`, `/srv`, `/tmp`, `/var/log`) on LVM.
- Deploy a functional **WordPress** with **lighttpd**, **MariaDB**, and **PHP**.
- Add another hardened service (e.g., **nginx**, **Apache2**) and open only the required ports in UFW.
- When enabling extra services, keep port exposure minimal and document every change.

> The list above mirrors the official subject brief. See your intra subject for the authoritative wording.

---

## Step 1: Virtual Machine & OS

- **Hypervisor:** VirtualBox (or similar)
- **ISO:** Debian **latest stable** netinst
- **Chipset/Boot:** **BIOS/Legacy** (no UEFI)
- **Base Memory:** 4 GB (choose an amount you find reasonable for your purposes)
- **vCPUs:** 4 (choose an amount you find reasonable for your purposes)
- **Disk:** 20 GB (dynamically allocated is fine)
- **Locale/Keyboard:** Choose what you prefer (example below uses English/US locale + PT‑BR keyboard)
- **Timezone:** `<Your/Timezone>`
- **Software selection:** Only **“SSH server”** and **“standard system utilities”** (no desktop)

Example installer choices you can mirror:

- Language: `English`  
- Location: `Brazil (South America)`  
- Locale: `United States`  
- Keyboard: `Portuguese`  
- Hostname: `your_login42`  
- Domain: _(leave empty)_  
- Root password: `your_strong_password`  
- User: `your_login`  
- User password: `your_strong_password`
- Timezone: `São Paulo`


---

## Step 2: Disk Layout (LVM)

During install choose **Guided – use entire disk and set up encrypted LVM**.

- Enable encryption with a strong passphrase (**do not commit it**).
- Choose **Separate home partition**. This option creates:
  - `LV root` mounted at `/` (ext4)
  - `LV swap` (size per RAM)
  - `LV home` mounted at `/home`
- Amount: Leave it at maximum value.
- Confirm **LVM on top of encrypted physical volume**.
- Write changes to disk.

You can verify the final layout with:

```bash
lsblk
lsblk -f
```

---

## Step 3: Package Manager
- Mirror country: `Brazil`  
- Mirror: `debian-archive.trafficmanager.net`  
- HTTP Proxy: _(leave blank)_  
- Install only:  
  - **SSH Server**  
  - **System Utilities**  
- Bootloader: Install to primary drive.  

---

## Step 4: Users & Groups

Create a new group named user42 and add your user to this and sudo groups.

```bash
sudo groupadd user42
adduser <your_login> sudo
adduser <your_login> user42
```


---

## Step 5: Initial Setup & Sudo Hardening

Change to root user and install required packages:

```bash
su
apt update && apt upgrade -y
apt install -y sudo ufw apparmor apparmor-utils ssh vim libpam-pwquality
```

You should configure sudo using strict rules:
- Restrict paths when using sudo.
- Authentication with sudo with max 3 attempts.
- Show custom message if error due to wrong password using sudo.
- Log every input and output using sudo. Save to /var/log/sudo/.
- Enable TTY mode.

Edit sudoers safely via `visudo` and add these defaults:

```
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
Defaults        passwd_tries=3
Defaults        insults
Defaults        log_input, log_output
Defaults        iolog_dir="/var/log/sudo/"
Defaults        logfile="/var/log/sudo/sudo.log"
Defaults        requiretty
```

---

## Step 6: Password Policy

Implement a strong password policy, following the requirements:
- Expire every 30 days.
- Minimum 2 days before changing.
- Warning 7 days before expires.
- At least 10 characters long. Min 1 uppercase, 1 lowercase, and 1 number. No more than 3 consecutives equal.
- Must not include name of the user.

> - Policy applies to all users **including root**.
> - Only NON-ROOT passwords must differ by **at least 7 characters** from the previous one.

To implement that, edit `/etc/login.defs`:

```
PASS_MAX_DAYS   30
PASS_MIN_DAYS   2
PASS_WARN_AGE   7
```

Configure `libpam-pwquality` in `/etc/pam.d/common-password` (append to the `pam_pwquality.so` line, or add new lines if missing):

```
password requisite pam_pwquality.so retry=3 minlen=10 maxrepeat=3 ucredit=-1 lcredit=-1 dcredit=-1 difok=7 reject_username
password requisite pam_pwquality.so user=root retry=3 minlen=10 maxrepeat=3 ucredit=-1 lcredit=-1 dcredit=-1 reject_username enforce_for_root
```

---

## Step 7: SSH

Enable and harden the daemon:

```bash
systemctl enable --now ssh
```

Edit `/etc/ssh/sshd_config` (only the relevant lines shown):

```
Port 4242
PermitRootLogin no
```

Reload:

```bash
systemctl restart ssh
```

#### If you use **NAT**, you’ll need a port‑forward. It's best to use **Bridged Adapter**, so the VM gets its own LAN IP:
- On your VirtualBox, click on your VM name.
- Click on Settings > Network
- Change from NAT to Bridge Adapter. Save changes.
- Inside your VM terminal, get the VM IP with `ip a` (it's the shown inet)

Connect from host:

```bash
ssh -p 4242 <your_login>@<vm_ip>
```

---

## Step 8: Firewall (UFW)

Configure OS with UFW firewall with only port 4242 open:

```bash
systemctl enable --now ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 4242/tcp
ufw enable
ufw status verbose
```

During evaluation, you may be asked to show adding/removing rules, e.g.:

```bash
ufw allow 8080/tcp
ufw delete allow 8080/tcp
```

---

## Step 9: AppArmor

Set up AppArmor to run at startup:

```bash
systemctl enable --now apparmor
aa-status
```

Ensure profiles are loaded and in **enforce** mode where appropriate.

---

## Step 10: Monitoring Script

Create script in bash called monitoring.sh. At server startup, display info on all terminals, and also every 10min. Banner is optional. Must contain the following info:
- System arch and kernel version.
- Num of physical processors.
- Num of virtual processors.
- Current available RAM and percent of use.
- Current available storage and percent of use.
- Current percent of use of processors.
- Date and time of last reboot.
- LVM active or not.
- Num of active connections.
- Num of active users.
- IPv4 and MAC addresses.
- Num of commands executed with sudo.

Create a script called `/usr/local/bin/monitoring.sh` (check the repo files for implementation details).

Make it executable and schedule it to run at boot **and** every 10 minutes:

```bash
chmod +x /usr/local/bin/monitoring.sh

# Run every 10 minutes for all users (uses wall):
crontab -e
# add:
*/10 * * * * /usr/local/bin/monitoring.sh

# Run once at login for all interactive shells:
echo 'sudo /usr/local/bin/monitoring.sh' >> /etc/profile
```

> The script must **not show errors**; redirect any noisy commands’ stderr if needed.

---

## Final: Verification & Evaluation Checklist

- **OS / Hostname**
  - `lsb_release -a` (or `/etc/debian_version`)
  - `hostnamectl` → ends with `42`
- **List Users**
  - `cat /etc/passwd | cut -d: -f1`
- **Partitions / LVM / Encryption**
  - `lsblk`, `lsblk -f`
- **SSH**
  - `ss -tlnp | grep 4242`
- **UFW**
  - `ufw status` shows only 4242/tcp allowed
- **AppArmor**
  - `aa-status` shows profiles **enforced**
- **Check Password Policy**
  - `chage -l <user>`

Common commands:

```bash
# Create user
adduser <name>
# Delete user
deluser <name>
# Change password
passwd <name>

# Check groups for user
groups <user> 
# Add user to group 
adduser <user> <group> 
usermod -aG <group> <user>

# Change hostname
nano /etc/hostname

# Check services
sudo systemctl start|stop|enable|disable|status <service>

# SSH sanity
cat /etc/ssh/sshd_config
```

---

## Signature (checksum) of the VM image

To prove integrity of your submitted disk image:

```bash
sha1sum </path/to/YourVM.vdi> > signature.txt
```

Commit `signature.txt` to the repository.

---

## Author

- Implementation and documentation by **Babi Drummond** – Student at École 42.
- Based on the Born2beroot subject requirements and personal runbook.
