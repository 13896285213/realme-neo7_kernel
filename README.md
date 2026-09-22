# Neo7 Kernel Builder

真我 Neo 7 (RMX5060) 的 Android 内核编译工具链。

## 芯片信息

- SoC: MediaTek Dimensity 9300+ (mt6989)
- Kernel Base: `OnePlusOSS/android_kernel_oneplus_mt6989@822beed` (6.1.157)
- Android Version: Android 15 (GKI 2.0)

## 功能特性

- **KernelSU** — ReSukiSU / SukiSU / KernelSU Next / KernelSU / 空壳
- **SUSFS** — 隐藏根、路径隔离、挂载隐藏
- **LZ4/ZSTD** — 压缩算法升级（zram/文件系统）
- **F2FS 网络增强** — ip_set、netfilter、BBR 拥塞控制
- **SSG IO Scheduler** — 三星移动调度器
- **Re-Kernel** — 安全回滚保护
- **Droidspaces** — 容器运行时支持

## 本地编译

```bash
# 在 Ubuntu 22.04 上运行
bash local/builder.sh
```

按提示选择 KSU 分支、功能开关等参数。

## GitHub Actions 编译

触发 `workflow_dispatch` 事件，可选择 KSU 分支和功能开关。

## 源码说明

本仓库基于 [dmitthedazed/realme-neo7-ksun-susfs](https://github.com/dmitthedazed/realme-neo7-ksun-susfs) 的源码结构重建。

- `RMX5060_6.1.157_KSUN-SUSFS.config` — 原始完整内核配置
- `final-source.diff` — 包含 KSU + SUSFS 基础补丁
- `patches/wildkernels/` — WildKernels 兼容性补丁（8个）
