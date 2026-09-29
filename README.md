# cachyos-kernel-debian-clang

在 Debian 系发行版上，用 **clang + ThinLTO + O3** 从 [CachyOS 内核源码](https://github.com/CachyOS/linux)
自编译 **BORE 调度器** 内核，并打包成 `apt` 可安装的 `.deb`。

本项目诞生的原因：现成的第三方 Debian 版 CachyOS 内核（如各类 GitHub CI 构建）普遍使用
GCC + `GENERIC_CPU`，**既没有 BORE 调度器，也没有 sched_ext、clang LTO 和 O3 优化**，
与 CachyOS 上游的桌面调优相差甚远。要保留完整特性，只能自己编。

## 特性

- **BORE 调度器**（Burst-Oriented Response Enhancer）—— 来自 CachyOS `kernel-patches`
- **clang + ThinLTO + `-O3`** 编译（非 GCC 通用构建）
- `CONFIG_X86_NATIVE_CPU=y` → **CPU 要求：x86-64-v3（AVX2 + BMI2，Haswell/Zen1 及更新）**
  （构建机为 Zen2，二进制使用 AVX2/BMI2 指令；如需通用内核请改用 `GENERIC_V3` 或 `GENERIC_CPU`）
- `CONFIG_HZ=1000` / `PREEMPT_DYNAMIC` —— 桌面低延迟
- ZSTD 压缩内核模块
- BBRv2 / BBRv3 拥塞控制可选切换（见 `docs/`）
- 完整 headers 包，可用于 DKMS（NVIDIA 驱动等）与外部模块编译

## 产物

每个 Release 提供以下 `.deb`：

| 包 | 说明 |
|---|---|
| `linux-image-<ver>-cachyos_*.deb` | 内核镜像 + 模块 |
| `linux-headers-<ver>-cachyos_*.deb` | 头文件（DKMS/外模块构建） |
| `linux-image-<ver>-cachyos-dbg_*.deb` | 调试符号（可选，体积大） |
| `linux-libc-dev_*.deb` | 用户空间头文件 |

所有 Release 均附带 `SHA256SUMS`。

## 安装

```bash
sudo apt install ./linux-image-*-cachyos_*.deb ./linux-headers-*-cachyos_*.deb
sudo reboot
```

> NVIDIA 用户：安装内核后，DKMS 会自动为新内核重建模块；或手动
> `sudo dkms autoinstall`。

## 许可

- **构建脚本、文档、仓库工具**：AGPL-3.0-only（见 `LICENSE-AGPL-3.0`）
- **内核本身及 `.deb` 产物**：GPL-2.0-only（Linux 内核许可证，见 `LICENSE-GPL-2.0`）

由于内核以 GPL-2.0 发布，**Release 中的内核产物不可重新许可为 AGPL**；
本仓库的 AGPL 许可仅覆盖原创脚本与文档。内核对应源码可从此仓库 `SOURCE.txt`
所列上游地址获取。
