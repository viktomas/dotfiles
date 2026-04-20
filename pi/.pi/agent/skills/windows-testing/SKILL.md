---
name: windows-testing
description: SSH into the Windows 11 ARM64 test VM for PowerShell-based checks (e.g. gitlab-lsp Windows regression tests). Manual-invoke only.
disable-model-invocation: true
---

# Windows VM testing

Personal skill for driving the Windows 11 ARM64 test VM (UTM/Parallels) from
macOS over SSH. The VM runs OpenSSH Server with PowerShell as the default
remote shell. It's typically used for gitlab-lsp Windows regression checks
(e.g. the MCP SDK upgrade `windowsHide` test in
`~/workspace/test/test-mcp/windows/`).

## Connect

```bash
ssh <vm-user>@<vm-ip>          # interactive PowerShell
ssh -t <vm-user>@<vm-ip>       # allocate TTY (required for TUIs like duo)
ssh <vm-user>@<vm-ip> 'powershell-command'   # one-shot command
```

Check reachability with `ssh` or `Test-NetConnection -Port 22` — **not
`ping`**: Windows Firewall blocks ICMP by default even when TCP/22 is open.

If the VM's IP/hostname or user isn't known, ask the user — it varies per
machine and isn't stored in this skill.

## Typical flow

1. SSH in, `cd` to the checkout (e.g.
   `C:\Users\<user>\workspace\test-mcp`).
2. Run the automated PowerShell script (e.g. `.\windows\mcp-test.ps1`).
3. For interactive TUI checks, reconnect with `ssh -t` and run duo's
   non-interactive one-shot mode (PowerShell stdin into a TUI is
   unreliable — prefer `duo run -g "..."` over interactive sessions).

## Copying build artifacts

Native Windows builds often fail on unrelated toolchain issues. The
standard workaround is to build on macOS and `scp` the artifacts in:

```bash
scp <files> <vm-user>@<vm-ip>:C:/Users/<vm-user>/AppData/Local/Temp/...
```

Forward slashes work in `scp` destinations even on Windows.

## Quirks

- Default remote shell is PowerShell (set via `HKLM:\SOFTWARE\OpenSSH\DefaultShell`).
- `.ps1` files need a UTF-8 BOM or they're read as ANSI by PowerShell 5.1.
- `.gitattributes` in test repos forces CRLF for `*.ps1` — run
  `git add --renormalize .` if a script suddenly fails to parse.
- ICMP is blocked by the Windows Firewall; use TCP-based reachability checks.

## Setting up SSH on a fresh VM

See **references/windows-ssh-setup.md** for the one-time OpenSSH Server +
key-auth + default-shell configuration on the Windows VM, plus the
matching macOS `~/.ssh/config` entry.
