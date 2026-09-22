# Corresponding source

The binary was built from the following immutable upstream revisions plus the
local patch set in `patches/` and the final config in this repository.

## Base kernel

- Repository: https://github.com/OnePlusOSS/android_kernel_oneplus_mt6989
- Commit: `822beed40827f1e9a103bc06ab4714a670080b72`

## KernelSU Next

- Repository: https://github.com/KernelSU-Next/KernelSU-Next
- Tag: `v3.3.0`
- Commit: `3b18216f71df189ab3d1b1ce0bdb21be1268e771`

## SUSFS

- Repository: https://gitlab.com/simonpunk/susfs4ksu
- Version: `v2.2.0`
- Commit: `0ff932799d898366d57b3b5984d85cdbcfcfad0a`

## WildKernels reference

- Repository: https://github.com/WildKernels/OnePlus_KernelSU_SUSFS
- Tag: `v2.2.0-r4`
- Commit: `d44240312aeb978463b66c3a3155c6d99a7c7a3c`

## Build lock

`versions.lock` records the tested device, ROM, KMI, and pinned component
versions. The exact compiler lock was not present in the supplied lock file;
the resulting release is therefore source-reproducible in principle but not
claimed bit-for-bit reproducible from this package alone.

`final-source.diff` is the tracked source diff from the base kernel checkout;
the eight compatibility patches are also included separately in `patches/`.
