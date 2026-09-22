#!/usr/bin/env bash
set -eu

# Realme Neo7 (RMX5060) 6.1.157 Kernel Builder
# Reference: https://github.com/dmitthedazed/realme-neo7-ksun-susfs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/kernel_workspace}"
KERNEL_SRC="${WORK_DIR}/android_kernel_oneplus_mt6989"
OUT_DIR="${OUT_DIR:-${WORK_DIR}/build-out}"
CLANG_BIN="${CLANG_BIN:-clang}"

# Default parameters
CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-neo7-6.1.157}
KSU_BRANCH=${KSU_BRANCH:-n}
APPLY_SUSFS=${APPLY_SUSFS:-y}
APPLY_LZ4=${APPLY_LZ4:-y}
APPLY_SSG=${APPLY_SSG:-y}
APPLY_DROIDSPACES=${APPLY_DROIDSPACES:-n}
MANIFEST=${MANIFEST:-realme-neo7-RMX5060}

echo "===== Realme Neo7 (RMX5060) 6.1.157 Kernel Builder ====="
echo ">>> WORK_DIR:     ${WORK_DIR}"
echo ">>> KERNEL_SRC:   ${KERNEL_SRC}"
echo ">>> OUT_DIR:      ${OUT_DIR}"
echo ">>> CUSTOM_SUFFIX: ${CUSTOM_SUFFIX}"
echo "========================================="

# ===== 1. Clone base kernel =====
if [ ! -d "${KERNEL_SRC}" ]; then
    echo ">>> Cloning base kernel..."
    git clone https://github.com/OnePlusOSS/android_kernel_oneplus_mt6989.git "${KERNEL_SRC}"
fi
cd "${KERNEL_SRC}"
git fetch --depth=1 origin 822beed40827f1e9a103bc06ab4714a670080b72 2>/dev/null || true
git checkout 822beed40827f1e9a103bc06ab4714a670080b72 || git reset --hard 822beed40827f1e9a103bc06ab4714a670080b72
cd "${WORK_DIR}"

# ===== 2. Apply final-source.diff (KSU+SUSFS integrated patches) =====
echo ">>> Applying final-source.diff..."
if [ -f "${ROOT_DIR}/final-source.diff" ]; then
    cd "${KERNEL_SRC}"
    git apply "${ROOT_DIR}/final-source.diff" 2>/dev/null || patch -p1 < "${ROOT_DIR}/final-source.diff" || echo "WARNING: final-source.diff partial failure"
    cd "${WORK_DIR}"
fi

# ===== 3. Apply wildkernels patches =====
echo ">>> Applying wildkernels patches..."
if [ -d "${ROOT_DIR}/patches/wildkernels" ]; then
    cd "${KERNEL_SRC}"
    for patch_file in "${ROOT_DIR}/patches/wildkernels/"*.patch; do
        [ -f "${patch_file}" ] && patch -p1 -F 3 < "${patch_file}" || true
    done
    cd "${WORK_DIR}"
fi

# ===== 4. Setup toolchain =====
echo ">>> Setting up toolchain..."
export PATH="${HOME}/bin:${PATH}"
export CC="${CC:-${CLANG_BIN}}"
export LD="${LD:-ld.lld}"
export AR="${AR:-llvm-ar}"

# Install dependencies
sudo apt update
sudo apt install -y binutils cmake curl git libc6-dev libcap-dev libelf-dev \
    libiberty-dev libssl-dev libtool perl python3 unzip wget bison flex zip
sudo rm -f /etc/apt/sources.list.d/microsoft-edge.list
sudo apt update
sudo rm -rf /var/lib/man-db/auto-update

# Install LLVM 20
sudo apt install -y clang-20 llvm-20
cd /usr/bin && sudo ln -sf clang-20 clang && sudo ln -sf llvm-config-20 llvm-config
for tool in ar nm ranlib strip; do
    src=$(ls /usr/bin/${tool}-20 2>/dev/null || echo "/usr/bin/${tool}")
    sudo mkdir -p /usr/local/bin
    sudo ln -sf "${src}" "/usr/local/bin/${tool}"
done
cd "${WORK_DIR}"

# Install aarch64 cross-compiler
sudo apt install -y gcc-aarch64-linux-gnu

# Install ccache
sudo apt install -y ccache || true

# ===== 5. Copy config =====
echo ">>> Copying config..."
if [ -f "${ROOT_DIR}/RMX5060_6.1.157_KSUN-SUSFS.config" ]; then
    cp "${ROOT_DIR}/RMX5060_6.1.157_KSUN-SUSFS.config" "${KERNEL_SRC}/.config"
fi

# ===== 6. Clean old build =====
rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

# ===== 7. Build kernel =====
echo ">>> Building kernel..."
export KCFLAGS="${KCFLAGS:--Wno-unused-function -Wno-unused-variable -Wno-unparameterized-variable}"
export EXTRA_CFLAGS="${EXTRA_CFLAGS:--Wno-unused-function -Wno-unused-variable -Wno-unparameterized-variable -Wno-cast-function-type -Wno-int-conversion}"
export WERROR=0

CORES=$(nproc)
echo ">>> Using ${CORES} cores"

make -C "${KERNEL_SRC}" O="${OUT_DIR}" ARCH=arm64 LLVM="${CLANG_BIN}" olddefconfig
make -C "${KERNEL_SRC}" O="${OUT_DIR}" ARCH=arm64 LLVM="${CLANG_BIN}" -j"${CORES}" \
    KCFLAGS="${KCFLAGS}" \
    EXTRA_CFLAGS="${EXTRA_CFLAGS}" \
    WERROR=${WERROR} 2>&1 | tee "${WORK_DIR}/build.log"

echo ">>> Checking build output..."
if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" ]; then
    echo ">>> ERROR: Image.gz-dtb not found!"
    echo ">>> Available files:"
    ls -la "${OUT_DIR}/arch/arm64/boot/" 2>/dev/null || echo ">>> No boot directory"
    exit 1
fi
echo ">>> Build SUCCESS!"
ls -lh "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb"

# ===== 8. Package AnyKernel3 =====
echo ">>> Packaging AnyKernel3..."
RESULT_DIR="${WORK_DIR}/${CUSTOM_SUFFIX}"
mkdir -p "${RESULT_DIR}"

cp "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" "${RESULT_DIR}/"
[ -d "${OUT_DIR}/arch/arm64/boot/dtbs" ] && cp "${OUT_DIR}/arch/arm64/boot/dtbs/"* "${RESULT_DIR}/" 2>/dev/null || true
[ -d "${OUT_DIR}/arch/arm64/boot/vendor" ] && cp "${OUT_DIR}/arch/arm64/boot/vendor/"* "${RESULT_DIR}/" 2>/dev/null || true

if [ ! -d "${WORK_DIR}/AnyKernel3" ]; then
    git clone https://github.com/cctv18/AnyKernel3.git "${WORK_DIR}/AnyKernel3"
fi
cd "${WORK_DIR}/AnyKernel3"
sed -i "s/KERNEL_SUFFIX=.*/KERNEL_SUFFIX=-${CUSTOM_SUFFIX}/g" unpacker.sh
sed -i "s/DEFAULT_DEVICE=.*/DEFAULT_DEVICE=${MANIFEST}/g" unpacker.sh
rm -f AnyKernel3.zip
./unpacker.sh

echo ">>> Creating zip..."
cd "${RESULT_DIR}"
zip -r "${WORK_DIR}/${CUSTOM_SUFFIX}.zip" . -x "*.DS_Store" "*Thumbs.db" 2>/dev/null || true

echo "========================================="
echo ">>> DONE! Artifact: ${WORK_DIR}/${CUSTOM_SUFFIX}.zip"
ls -lh "${WORK_DIR}/${CUSTOM_SUFFIX}.zip" 2>/dev/null || true
echo "========================================="
