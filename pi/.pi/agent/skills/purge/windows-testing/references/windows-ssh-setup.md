# Windows VM SSH setup (one-time)

Steps to make a fresh Windows 11 ARM64 VM reachable by `ssh` from macOS
with PowerShell as the default remote shell and key-based auth.

## 1. Install and enable OpenSSH Server (on the VM, as Administrator)

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Firewall rule is usually added automatically; verify:
Get-NetFirewallRule -Name *ssh*
# If missing:
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' `
    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

Confirm it's listening:

```powershell
Get-Service sshd
Test-NetConnection -ComputerName localhost -Port 22
```

## 2. Set PowerShell as the default remote shell

Without this, incoming SSH sessions land in `cmd.exe`.

```powershell
New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -PropertyType String -Force
```

(Optional) Use PowerShell 7 instead — replace the value with the full path
to `pwsh.exe`.

## 3. Key-based authentication

On **macOS**, pick or create a key:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_win -C "windows-vm"
```

Copy the public key to the VM. For **non-admin users**, append to
`C:\Users\<user>\.ssh\authorized_keys`:

```powershell
# On the VM (as the target user):
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.ssh" | Out-Null
# Paste the contents of id_ed25519_win.pub into:
notepad "$env:USERPROFILE\.ssh\authorized_keys"

# Fix ACLs — OpenSSH refuses the file otherwise:
icacls "$env:USERPROFILE\.ssh\authorized_keys" /inheritance:r
icacls "$env:USERPROFILE\.ssh\authorized_keys" /grant:r "${env:USERNAME}:F"
```

For **administrator** accounts, OpenSSH reads
`C:\ProgramData\ssh\administrators_authorized_keys` instead. Easier to
run tests as a non-admin user so the per-user file applies.

Then disable password auth (optional but recommended) by editing
`C:\ProgramData\ssh\sshd_config`:

```
PasswordAuthentication no
PubkeyAuthentication yes
```

and restart:

```powershell
Restart-Service sshd
```

## 4. Get the VM's IP

```powershell
ipconfig | Select-String IPv4
```

For UTM/Parallels shared networking, the VM typically gets a DHCP address
on a `192.168.*` or `10.*` subnet reachable from the host.

## 5. macOS `~/.ssh/config`

```
Host win-vm
    HostName 192.168.64.5          # replace with VM IP
    User t                         # the Windows username
    IdentityFile ~/.ssh/id_ed25519_win
    IdentitiesOnly yes
    ServerAliveInterval 30
    RequestTTY auto
```

Then:

```bash
ssh win-vm                 # interactive PowerShell
ssh -t win-vm              # force TTY for TUIs
ssh win-vm 'Get-ChildItem' # one-shot command
```

## Troubleshooting

- **`ping` fails but `ssh` works**: normal — Windows Firewall blocks ICMP.
  Always verify with `Test-NetConnection -Port 22` or plain `ssh`.
- **`Permission denied (publickey)`**: almost always ACLs on
  `authorized_keys`. Re-run the `icacls` commands above. Check
  `C:\ProgramData\ssh\logs\sshd.log` on the VM.
- **Landed in `cmd.exe`**: `DefaultShell` registry value missing or
  pointing at a bad path — repeat step 2 and `Restart-Service sshd`.
- **Interactive TUI garbled**: use `ssh -t`. Some apps also need
  `$env:TERM = "xterm-256color"` set on the VM side.
- **VM IP changes across reboots**: either set a DHCP reservation in the
  hypervisor or switch to a host-only adapter with a static IP.
