# 🧑‍💻 Domain Join Guide: Linux & Windows

This guide explains how to join clients to the domain `ad.${localDomain}` and apply certificates and policies via Samba AD + GPO.

---

## 🖥️ Windows Domain Join

### 1. Requirements

* Windows Pro or Enterprise
* DNS server must resolve `dc1.ad.${localDomain}`
* Samba AD domain controller is reachable at `192.168.${toString vars.vlans.management.id}.6`

### 2. Steps

1. Open **System > Rename this PC (advanced)**
2. Click **Change…**, then select **Domain**, and enter: `ad.${localDomain}`
3. Provide credentials of a domain user with join permissions
4. Reboot when prompted

### 3. Certificate Installation (via GPO)

* Certificates from `yellow` are mounted to `\dc1\certs`
* A GPO mounts this share at login and imports `fullchain.pem`
* You can verify this under **certmgr.msc > Trusted Root Certification Authorities**

---

## 🐧 Linux Domain Join

### 1. Requirements

* `realmd`, `sssd`, and `adcli` installed
* DNS can resolve `dc1.ad.${localDomain}`
* NTP is in sync with the domain controller

### 2. Join Command

```sh
sudo realm join --user=administrator ad.${localDomain}
```

You’ll be prompted for the domain admin password.

### 3. Enable Login for Domain Users

```sh
sudo bash -c 'echo "session required pam_mkhomedir.so skel=/etc/skel umask=0077" >> /etc/pam.d/common-session'
```

### 4. Certificate Access

Certificates will be mounted via `cifs-utils` from `\\dc1\certs`.

```sh
sudo mkdir -p /mnt/certs
sudo mount -t cifs //dc1/certs /mnt/certs -o user=DOMAIN\\username,vers=3.0
```

You can then install them using your distro’s trust store mechanism (e.g., `update-ca-certificates`, `trust anchor`).

---

## ✅ Test & Verify

* Login as domain user: `DOMAIN\username`
* Access Samba share: `\\dc1\certs`
* Confirm certificates are trusted
* Validate Kerberos tickets with `klist`

Need help with specific Linux distros or automation? Let me know!

