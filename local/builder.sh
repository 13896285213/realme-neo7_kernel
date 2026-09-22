#!/usr/bin/env bash
set -euo pipefail

# ===== Realme Neo7 (RMX5060) Kernel Builder =====
# Based on dmitthedazed/realme-neo7-ksun-susfs reference source
# See: https://github.com/dmitthedazed/realme-neo7-ksun-susfs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="${SCRIPT_DIR}"

# ===== Default parameters =====
MANIFEST=${MANIFEST:-realme-neo7-RMX5060}
WORK_DIR="${WORK_DIR:-${BASE_DIR}/kernel_workspace}"
CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-neo7-6.1.157}
KSU_BRANCH=${KSU_BRANCH:-n}       # n=KernelSU-Next, k=KSU(tiann), r=ReSukiSU, y=SukiSU
APPLY_SUSFS=${APPLY_SUSFS:-y}
APPLY_LZ4=${APPLY_LZ4:-y}
APPLY_BETTERNET=${APPLY_BETTERNET:-y}
APPLY_SSG=${APPLY_SSG:-y}
APPLY_DROIDSPACES=${APPLY_DROIDSPACES:-n}
APPLY_REKERNEL=${APPLY_REKERNEL:-n}

echo "===== Realme Neo7 (RMX5060) 6.1.157 Kernel Builder ====="
echo ">>> Parameters:"
echo "    MANIFEST:     ${MANIFEST}"
echo "    KSU_BRANCH:   ${KSU_BRANCH}"
echo "    SUSFS:        ${APPLY_SUSFS}"
echo "    LZ4:          ${APPLY_LZ4}"
echo "    SSG:          ${APPLY_SSG}"
echo "    Work dir:     ${WORK_DIR}"
echo "========================================="

mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# ===== 1. Clone base kernel =====
KERNEL_DIR="${WORK_DIR}/android_kernel_oneplus_mt6989"
if [ ! -d "${KERNEL_DIR}" ]; then
    echo ">>> Cloning base kernel..."
    git clone https://github.com/OnePlusOSS/android_kernel_oneplus_mt6989.git "${KERNEL_DIR}"
fi
cd "${KERNEL_DIR}"
git fetch --depth=1 origin 822beed40827f1e9a103bc06ab4714a670080b72 2>/dev/null || true
git checkout 822beed40827f1e9a103bc06ab4714a670080b72
cd "${WORK_DIR}"

# ===== 2. Apply final-source.diff (contains KSU+SUSFS integration patches) =====
echo ">>> Applying final-source.diff..."
if [ -f "${BASE_DIR}/final-source.diff" ]; then
    cd "${KERNEL_DIR}"
    git apply --index "${BASE_DIR}/final-source.diff" 2>/dev/null || patch -p1 < "${BASE_DIR}/final-source.diff" || echo "WARNING: final-source.diff failed, continuing..."
    cd "${WORK_DIR}"
fi

# ===== 3. Clone KSU source (KernelSU-Next by default) =====
KSU_SRC_DIR="${KERNEL_DIR}/drivers/kernelsu"
if [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
    echo ">>> Using KernelSU-Next v3.3.0..."
    if [ ! -d "${KSU_SRC_DIR}/.git" ]; then
        mkdir -p "${KERNEL_DIR}/drivers"
        git clone --depth=1 --branch v3.3.0 --single-branch \
            https://github.com/KernelSU-Next/KernelSU-Next.git "${KSU_SRC_DIR}" 2>/dev/null || \
        git clone --depth=1 https://github.com/KernelSU-Next/KernelSU-Next.git "${KSU_SRC_DIR}"
        cd "${KSU_SRC_DIR}"
        git checkout 3b18216f71df189ab3d1b1ce0bdb21be1268e771 2>/dev/null || true
        cd "${WORK_DIR}"
    fi
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
    echo ">>> Using KernelSU (tiann)..."
    if [ ! -d "${KSU_SRC_DIR}/.git" ]; then
        mkdir -p "${KERNEL_DIR}/drivers"
        git clone --depth=1 https://github.com/tiann/KernelSU.git "${KSU_SRC_DIR}"
    fi
elif [[ "$KSU_BRANCH" == "r" || "$KSU_BRANCH" == "R" ]]; then
    echo ">>> Using ReSukiSU..."
    if [ ! -d "${KSU_SRC_DIR}/.git" ]; then
        mkdir -p "${KERNEL_DIR}/drivers"
        git clone --depth=1 https://github.com/TeamWinReborn/ReSukiSU.git "${KSU_SRC_DIR}"
    fi
elif [[ "$KSU_BRANCH" == "y" || "$KSU_BRANCH" == "Y" ]]; then
    echo ">>> Using SukiSU Ultra..."
    if [ ! -d "${KSU_SRC_DIR}/.git" ]; then
        mkdir -p "${KERNEL_DIR}/drivers"
        git clone --depth=1 https://github.com/SukiSU-Next/SukiSU-Ultra.git "${KSU_SRC_DIR}"
    fi
else
    echo ">>> KSU branch not recognized: ${KSU_BRANCH}, using KernelSU-Next as default"
    if [ ! -d "${KSU_SRC_DIR}/.git" ]; then
        mkdir -p "${KERNEL_DIR}/drivers"
        git clone --depth=1 --branch v3.3.0 --single-branch \
            https://github.com/KernelSU-Next/KernelSU-Next.git "${KSU_SRC_DIR}" 2>/dev/null || \
        git clone --depth=1 https://github.com/KernelSU-Next/KernelSU-Next.git "${KSU_SRC_DIR}"
    fi
fi

# ===== 4. Apply wildkernels compatibility patches =====
echo ">>> Applying wildkernels patches..."
cd "${KERNEL_DIR}"
for patch_file in "${BASE_DIR}/patches/wildkernels/"*.patch; do
    [ -f "${patch_file}" ] && patch -p1 -F 3 < "${patch_file}" || true
done
cd "${WORK_DIR}"

# ===== 5. Apply SUSFS patches (simonpunk/susfs4ksu v2.2.0) =====
if [[ "$APPLY_SUSFS" == [yY] ]]; then
    echo ">>> Applying SUSFS (susfs4ksu v2.2.0)..."
    SUSFS_DIR="${WORK_DIR}/susfs4ksu"
    if [ ! -d "${SUSFS_DIR}" ]; then
        git clone --depth=1 https://github.com/simonpunk/susfs4ksu.git "${SUSFS_DIR}"
        cd "${SUSFS_DIR}"
        git checkout 0ff932799d898366d57b3b5984d85cdbcfcfad0a 2>/dev/null || true
        cd "${WORK_DIR}"
    fi
    # Copy SUSFS kernel patches
    cp "${SUSFS_DIR}/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch" "${KERNEL_DIR}/"
    cd "${KERNEL_DIR}"
    patch -p1 < 50_add_susfs_in_gki-android14-6.1.patch || echo "WARNING: SUSFS patch may have already been applied"
    cd "${WORK_DIR}"
fi

# ===== 6. Copy config and prepare build =====
echo ">>> Preparing build config..."
cp "${BASE_DIR}/RMX5060_6.1.157_KSUN-SUSFS.config" "${KERNEL_DIR}/.config"

# Set custom suffix in version
if [ -f "${KERNEL_DIR}/scripts/setlocalversion" ]; then
    sed -i "s|echo \"\$res\"|echo \"-${CUSTOM_SUFFIX}\"|" "${KERNEL_DIR}/scripts/setlocalversion" || true
fi

# ===== 7. Setup toolchain =====
echo ">>> Setting up cross-compiler..."
export PATH="${HOME}/bin:${PATH}"
export CC="${CC:-clang}"
export LD="${LD:-ld.lld}"
export AR="${AR:-llvm-ar}"

# Install tools if needed
if ! command -v ccache &>/dev/null; then
    sudo apt update && sudo apt install -y ccache || true
fi
if ! command -v clang-20 &>/dev/null; then
    sudo apt update && sudo apt install -y clang-20 llvm-20 || true
    cd /usr/bin && sudo ln -sf clang-20 clang && sudo ln -sf llvm-config-20 llvm-config
    for tool in ar nm ranlib strip; do
        src=$(ls /usr/bin/${tool}-20 2>/dev/null || echo "/usr/bin/${tool}")
        sudo ln -sf "${src}" "/usr/local/bin/${tool}"
    done
    cd "${WORK_DIR}"
fi

if ! command -v aarch64-linux-gnu-gcc &>/dev/null; then
    sudo apt update && sudo apt install -y gcc-aarch64-linux-gnu || true
fi

# ===== 8. Build kernel =====
echo ">>> Building kernel..."
export KCFLAGS="${KCFLAGS:--Wno-unused-function -Wno-unused-variable -Wno-unparameterized-variable}"
export EXTRA_CFLAGS="${EXTRA_CFLAGS:--Wno-unused-function -Wno-unused-variable -Wno-unparameterized-variable -Wno-cast-function-type -Wno-int-conversion}"
export WERROR=0
export SUBMIT_INFO="Built by GitHub Actions"

CORES=$(nproc)
cd "${KERNEL_DIR}"

# Build
make -j"${CORES}" O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    LLVM=1 LLVM_IAS=1 \
    KCFLAGS="${KCFLAGS}" \
    EXTRA_CFLAGS="${EXTRA_CFLAGS}" \
    WERROR=${WERROR} 2>&1 | tee "${WORK_DIR}/build.log" || {
    echo ">>> Build FAILED! Check ${WORK_DIR}/build.log for details"
    exit 1
}

# ===== 9. Check output =====
OUT_DIR="${KERNEL_DIR}/out/arch/arm64/boot"
if [ ! -f "${OUT_DIR}/Image.gz-dtb" ]; then
    echo ">>> ERROR: Image.gz-dtb not found!"
    echo ">>> Available files:"
    ls -la "${OUT_DIR}/" 2>/dev/null || ls -la "${KERNEL_DIR}/arch/arm64/boot/" 2>/dev/null
    exit 1
fi
echo ">>> Build SUCCESS! Image.gz-dtb: $(ls -lh "${OUT_DIR}/Image.gz-dtb" | awk '{print $5}')"

# ===== 10. Package AnyKernel3 =====
echo ">>> Packaging AnyKernel3..."
RESULT_DIR="${WORK_DIR}/${CUSTOM_SUFFIX}"
mkdir -p "${RESULT_DIR}"

cp "${OUT_DIR}/Image.gz-dtb" "${RESULT_DIR}/"

# Copy dtbs
[ -d "${OUT_DIR}/dtbs" ] && cp -r "${OUT_DIR}/dtbs/"* "${RESULT_DIR}/" 2>/dev/null || true
[ -d "${OUT_DIR}/vendor" ] && cp -r "${OUT_DIR}/vendor/"* "${RESULT_DIR}/" 2>/dev/null || true

# Download and pack AnyKernel3
if [ ! -d "${WORK_DIR}/AnyKernel3" ]; then
    git clone https://github.com/cctv18/AnyKernel3.git "${WORK_DIR}/AnyKernel3"
fi
cd "${WORK_DIR}/AnyKernel3"
sed -i "s/KERNEL_SUFFIX=.*/KERNEL_SUFFIX=-${CUSTOM_SUFFIX}/g" unpacker.sh
sed -i "s/DEFAULT_DEVICE=.*/DEFAULT_DEVICE=${MANIFEST}/g" unpacker.sh
rm -f AnyKernel3.zip
./unpacker.sh

# ===== 11. Create final zip =====
echo ">>> Creating final zip..."
cd "${RESULT_DIR}"
zip -r "${WORK_DIR}/${CUSTOM_SUFFIX}.zip" . -x "*.DS_Store" "*Thumbs.db" 2>/dev/null || true

echo "========================================="
echo ">>> DONE! Artifact: ${WORK_DIR}/${CUSTOM_SUFFIX}.zip"
echo "========================================="
ls -lh "${WORK_DIR}/${CUSTOM_SUFFIX}.zip" 2>/dev/null || echo ">>> Zip creation skipped"
