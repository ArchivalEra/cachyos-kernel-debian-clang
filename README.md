# cachyos-kernel-debian-clang

Build the [CachyOS kernel](https://github.com/CachyOS/linux) on Debian-based
distributions with **clang + ThinLTO + O3**, package it as an `apt`-installable
`.deb`, and get the **BORE scheduler** on Debian.

This project exists because the ready-made third-party Debian CachyOS kernels
(such as various GitHub CI builds) generally use GCC with `GENERIC_CPU`. They
lack the BORE scheduler, `sched_ext`, clang LTO, and O3 optimizations, so they
are far from the upstream CachyOS desktop tuning. To keep the full feature set,
you have to build it yourself.

## Features

- **BORE scheduler** — Burst-Oriented Response Enhancer, from CachyOS
  `kernel-patches`
- **clang + ThinLTO + `-O3`** build (not a generic GCC build)
- **x86-64-v3 target** — released `.deb` packages are built with
  `CONFIG_GENERIC_CPU=y` and `CONFIG_X86_64_VERSION=3` (AVX2 + BMI2,
  Haswell/Zen1 or newer). CI overrides the committed native-CPU config so the
  runner's `-march=native` cannot leak unsupported instructions.
- `CONFIG_HZ=1000` / `PREEMPT_DYNAMIC` — low-latency desktop tuning
- ZSTD-compressed kernel modules
- Optional BBRv2 / BBRv3 congestion-control switching (see `docs/`)
- Complete headers package for DKMS (NVIDIA driver, etc.) and external module
  builds

## CI builds

Kernel packages are built on demand with GitHub Actions. The workflow has no
schedule and does not poll upstream automatically. To build a specific version,
run **Actions → Build CachyOS kernel debs → Run workflow**, then enter the
CachyOS release version, for example `7.3.4-1`.

The workflow fetches the matching CachyOS source and BORE patch, installs the
latest stable LLVM toolchain, builds the `.deb` packages, creates a
`<version>-cachyos` tag, and publishes them as a GitHub Release. If that tag
already exists, the workflow skips the duplicate build.

## Artifacts

Each Release provides the following `.deb` packages:

| Package | Description |
|---|---|
| `linux-image-<ver>-cachyos_*.deb` | Kernel image and modules |
| `linux-headers-<ver>-cachyos_*.deb` | Headers for DKMS/external module builds |
| `linux-image-<ver>-cachyos-dbg_*.deb` | Debug symbols (optional, large) |
| `linux-libc-dev_*.deb` | User-space headers |

All Releases include `SHA256SUMS`.

## Installation

```bash
sudo apt install ./linux-image-*-cachyos_*.deb ./linux-headers-*-cachyos_*.deb
sudo reboot
```

> NVIDIA users: after installing the kernel, DKMS automatically rebuilds the
> modules for the new kernel, or run `sudo dkms autoinstall` manually.

## License

- **Build scripts, docs, repository tooling**: AGPL-3.0-only (see
  `LICENSE-AGPL-3.0`)
- **The kernel itself and the resulting `.deb` artifacts**: GPL-2.0-only (Linux
  kernel license, see `LICENSE-GPL-2.0`)

Because the kernel is released under GPL-2.0, **the kernel artifacts in a
Release cannot be relicensed as AGPL**. The AGPL license in this repository
covers only the original scripts and documentation. The corresponding kernel
source is available from the upstream address listed in `SOURCE.txt`.
