# BBRv1 / BBRv3 switching HOWTO (CachyOS 7.2.3 gaming kernel)

## Why they can't coexist

`tcp_bbr` (BBRv1) and `tcp_bbr3` (BBRv3) are built from the same source with
identical `__bpf_kfunc` names (e.g. `bbr_cwnd_event_tx_start`, `bbr_set_state`).
The kernel allows only one module owning a given kfunc name, so loading the
second one fails:

```text
# dmesg
kfunc bbr_cwnd_event_tx_start (id: 150106) is already present in module tcp_bbr.
# modprobe tcp_bbr3
modprobe: ERROR: could not insert 'tcp_bbr3': Invalid argument
```

(That is also why both must be built as modules `=m`: built-in, their
duplicate BTF entries crash `resolve_btfids` during the kernel build.)

Worse, a loaded CC module cannot even be *unloaded* while sockets reference
it (`modprobe -r` -> `FATAL: Module tcp_bbr3 is in use`). On a live desktop
there are always sockets, so **runtime switching is only possible when the
rival module is idle or absent**.

## Method 1 (recommended): switch at boot — always works

```bash
sudo bash /mnt/hdd/buildstuff/cachyos-for-debian/scripts/net-cc-switch.sh bbr3 --boot  # default
sudo bash /mnt/hdd/buildstuff/cachyos-for-debian/scripts/net-cc-switch.sh bbr --boot
sudo reboot
```

`--boot` rewrites `/etc/modules-load.d/modules-load-cachyos.conf` (which of
the two modules loads) and `/etc/sysctl.d/99-net-gaming.conf` (default
algorithm + `fq` qdisc). At boot there are no sockets yet, so the chosen
module loads cleanly every time.

## Method 2: live switch — only when idle

```bash
sudo bash /mnt/hdd/buildstuff/cachyos-for-debian/scripts/net-cc-switch.sh bbr3
sudo bash /mnt/hdd/buildstuff/cachyos-for-debian/scripts/net-cc-switch.sh bbr
sudo bash /mnt/hdd/buildstuff/cachyos-for-debian/scripts/net-cc-switch.sh cubic  # unloads both
```

Works only if the rival module's `lsmod` refcount is 0 (or it isn't loaded).
Otherwise the guard refuses and tells you to use `--boot`.

## Safety net: the modprobe warning hook

Every raw `modprobe tcp_bbr|tcp_bbr3` — by hand, by script, or by
`systemd-modules-load` — passes through `/usr/local/sbin/cachy-cc-guard`
(registered in `/etc/modprobe.d/cachy-bbr.conf`). It prints a mutual-exclusion
warning and then applies exactly the rules above: activate if already loaded,
swap if the rival is idle, refuse with instructions if the rival is in use.

## Verify

```bash
sysctl net.ipv4.tcp_available_congestion_control  # shows only the loaded one + reno/cubic
sysctl net.ipv4.tcp_congestion_control            # the active algorithm
lsmod | grep tcp_bbr                              # exactly one of tcp_bbr / tcp_bbr3 (3rd column = users)
```
