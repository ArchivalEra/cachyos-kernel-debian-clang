#!/bin/bash
# net-cc-switch.sh [bbr|bbr3|cubic] [--boot]
# Switch TCP congestion control between mutually-exclusive BBRv1/BBRv3/Cubic.
#   no flag   : live switch (works only if the rival module is idle or absent)
#   --boot    : set the boot default instead (always works, needs a reboot)
set -u
ALG="${1:-bbr3}"
BOOT="${2:-}"
MODLOAD=/etc/modules-load.d/modules-load-cachyos.conf
SYSCTL=/etc/sysctl.d/99-net-gaming.conf

set_boot() {
	# $1 = bbr|bbr3 : which module loads at boot; cubic = load neither
	{
		echo "# CachyOS gaming kernel: BBR module for next boot (bbr and bbr3 are mutually exclusive)."
		[ "$1" = "bbr" ] && echo "tcp_bbr" || echo "# tcp_bbr (use --boot bbr to enable)"
		[ "$1" = "bbr3" ] && echo "tcp_bbr3" || echo "# tcp_bbr3 (use --boot bbr3 to enable)"
	} | sudo tee "$MODLOAD" >/dev/null
	sudo sed -i -E "s/^(net\.ipv4\.tcp_congestion_control *= *).*/\1$1/" "$SYSCTL"
	echo "boot default set to $1 in $MODLOAD and $SYSCTL - reboot to apply."
}

if [ "$BOOT" = "--boot" ]; then
	case "$ALG" in bbr|bbr3|cubic) set_boot "$ALG" ;; *) echo "usage: $0 bbr|bbr3|cubic [--boot]"; exit 1 ;; esac
	exit 0
fi

# live path: delegate loading to the modprobe guard hook (it enforces exclusivity),
# then set qdisc/fastopen here.
case "$ALG" in
  bbr)  sudo modprobe tcp_bbr || exit 1 ;;
  bbr3) sudo modprobe tcp_bbr3 || exit 1 ;;
  cubic)
    sudo modprobe -r tcp_bbr3 2>/dev/null || true
    sudo modprobe -r tcp_bbr 2>/dev/null || true ;;
  *) echo "usage: $0 bbr|bbr3|cubic [--boot]"; exit 1 ;;
esac
sudo sysctl -w net.core.default_qdisc=fq
if [ "$ALG" != "cubic" ]; then sudo sysctl -w "net.ipv4.tcp_congestion_control=${ALG}"; fi
sudo sysctl -w net.ipv4.tcp_fastopen=3
sysctl net.ipv4.tcp_available_congestion_control net.ipv4.tcp_congestion_control net.core.default_qdisc
