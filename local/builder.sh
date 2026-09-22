#!/bin/bash
set -e

# ===== 设置自定义参数 =====
echo "===== 真我Neo7(RMX5060) 6.1.157 内核本地编译脚本 ====="
echo ">>> 读取用户配置..."

MANIFEST=${MANIFEST:-realme-neo7-RMX5060}

CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-neo7-6.1.157}
APPLY_SUSFS=${APPLY_SUSFS:-y}
USE_PATCH_LINUX=${USE_PATCH_LINUX:-n}
KSU_BRANCH=${KSU_BRANCH:-r}
APPLY_LZ4=${APPLY_LZ4:-y}
APPLY_LZ4KD=${APPLY_LZ4KD:-n}
APPLY_BETTERNET=${APPLY_BETTERNET:-y}
APPLY_BBR=${APPLY_BBR:-n}
APPLY_DROIDSPACES=${APPLY_DROIDSPACES:-n}
APPLY_SSG=${APPLY_SSG:-y}
APPLY_REKERNEL=${APPLY_REKERNEL:-n}
APPLY_BBG=${APPLY_BBG:-y}

echo "适用机型: ${MANIFEST}"
echo "KSU版本: ${KSU_BRANCH}"
echo "后缀: ${CUSTOM_SUFFIX}"
echo "自定义编译时间戳（默认：$(date +%Y%m%d%H%M%S)）"
CUSTOM_TIMESTAMP=${CUSTOM_TIMESTAMP:-$(date +%Y%m%d%H%M%S)}
echo "编译时间戳: ${CUSTOM_TIMESTAMP}"
echo "========================================="

# ===== 定义工作目录 =====
BASE_DIR="$(pwd)"
WORK_DIR="${BASE_DIR}/kernel_workspace"
KERNEL_DIR="${WORK_DIR}/android_kernel_oneplus_mt6989"
OUT_DIR="${KERNEL_DIR}/out/arch/arm64/boot"

echo ">>> 使用目录: ${WORK_DIR}"

# ===== 清理旧构建 =====
echo ">>> 清理旧构建..."
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# ===== 克隆内核源码 =====
echo ">>> 克隆内核源码..."
git clone https://github.com/OnePlusOSS/android_kernel_oneplus_mt6989.git android_kernel_oneplus_mt6989
cd android_kernel_oneplus_mt6989
git checkout 822beed40827f1e9a103bc06ab4714a670080b72
cd "${WORK_DIR}"

# ===== 应用 dmitthedazed Neo7 兼容补丁 (wildkernels) =====
echo ">>> 应用 Neo7 兼容补丁..."
for patch_file in "${BASE_DIR}/patches/wildkernels/"*.patch; do
  [ -f "${patch_file}" ] && {
    cp "${patch_file}" "${KERNEL_DIR}/"
    cd "${KERNEL_DIR}"
    patch -p1 -F 3 < "$(basename "${patch_file}")" || true
    cd "${WORK_DIR}"
  }
done

# ===== 清除 abi 文件及去除 dirty 后缀 =====
echo ">>> 清除 ABI 文件及去除 dirty 后缀..."
rm -f "${KERNEL_DIR}"/out/abi_gki_protected_exports_* 2>/dev/null || true

if [ -f "${KERNEL_DIR}/scripts/setlocalversion" ]; then
  sed -i 's/ -dirty//g' "${KERNEL_DIR}/scripts/setlocalversion" || true
fi

# ===== 替换版本后缀 =====
echo ">>> 替换内核版本后缀..."
if [ -f "${KERNEL_DIR}/scripts/setlocalversion" ]; then
  sed -i "s|echo \"\$res\"|echo \"-${CUSTOM_SUFFIX}\"|" "${KERNEL_DIR}/scripts/setlocalversion" || true
fi

# ===== 获取 KSU 源码并设置版本 =====
if [[ "$KSU_BRANCH" == [yYrR] ]]; then
  echo ">>> 拉取 ReSukiSU 并设置版本（由于SukiSU长期未维护无法正常编译，且ReSukiSU兼容sukisu管理器，故SukiSU源码仓库已重定向为resukisu）..."
  mkdir -p "${KERNEL_DIR}/drivers/kernelsu"
  curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash -s main
  echo 'CONFIG_KSU_FULL_NAME_FORMAT="%TAG_NAME%-%COMMIT_SHA%@neo7-6.1.157"' >> "${KERNEL_DIR}/arch/arm64/configs/gki_defconfig"
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  echo ">>> 拉取 KernelSU Next 并设置版本..."
  mkdir -p "${KERNEL_DIR}/drivers/kernelsu"
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/refs/heads/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
  cd "${KERNEL_DIR}/KernelSU-Next"
  rm -rf .git
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/pershoot/KernelSU-Next/commits?sha=dev&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/KSU_VERSION_FALLBACK := 1/KSU_VERSION_FALLBACK := ${KSU_VERSION}/g" kernel/Kbuild
  KSU_GIT_TAG=$(curl -sL "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags" | grep -o '"name": *"[^"]*"' | head -n 1 | sed 's/"name": "//;s/"//')
  sed -i "s/KSU_VERSION_TAG_FALLBACK := v0.0.1/KSU_VERSION_TAG_FALLBACK := ${KSU_GIT_TAG}/g" kernel/Kbuild
  #为KernelSU Next创建WildKSU兼容支持
  cd "${KERNEL_DIR}/drivers/kernelsu"
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/apk_sign.patch
  patch -p2 -N -F 3 < apk_sign.patch || true
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  echo ">>> 拉取 KernelSU (tiann/KernelSU) 并设置版本..."
  mkdir -p "${KERNEL_DIR}/drivers/kernelsu"
  curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
  KSU_GIT_TAG=$(curl -sL "https://api.github.com/repos/tiann/KernelSU/tags" | grep -o '"name": *"[^"]*"' | head -n 1 | sed 's/"name": "//;s/"//')
  sed -i "s/KSU_VERSION_TAG_FALLBACK := v0.0.1/KSU_VERSION_TAG_FALLBACK := ${KSU_GIT_TAG}/g" "${KERNEL_DIR}/drivers/kernelsu/KernelSU/kernel/Kbuild"
else
  echo ">>> 使用 LKM 模式构建（不包含内置 KSU）..."
  echo 'CONFIG_KSU=n' >> "${KERNEL_DIR}/arch/arm64/configs/gki_defconfig"
fi
cd "${WORK_DIR}"

# ===== 应用 SUSFS 补丁 =====
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo ">>> 拉取 SUSFS (susfs4oki - OPPO/OnePlus/Realme 适配版)..."
  rm -rf susfs4ksu
  git clone --depth=1 https://github.com/cctv18/susfs4oki.git susfs4ksu
  cp susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch "${KERNEL_DIR}/"
  cd "${KERNEL_DIR}"
  patch -p1 < 50_add_susfs_in_gki-android14-6.1.patch || true
  cd "${WORK_DIR}"

  # 应用 susfs 额外补丁（来自 cctv18 的 oppo_oplus_realme_sm8650 仓库）
  echo ">>> 拉取 susfs 额外补丁..."
  rm -rf oppo_oplus_realme_sm8650
  git clone --depth=1 https://github.com/cctv18/oppo_oplus_realme_sm8650.git oppo_oplus_realme_sm8650
  cd "${KERNEL_DIR}"
  patch -p1 < "${WORK_DIR}/oppo_oplus_realme_sm8650/other_patch/69_hide_stuff.patch" || true
  patch -p1 < "${WORK_DIR}/oppo_oplus_realme_sm8650/other_patch/70_add_proc_suskernel.patch" || true
  cd "${WORK_DIR}"
fi

# ===== 应用其他补丁 =====
# CVE-2025 fix（来自 cctv18 的 oppo_oplus_realme_sm8650 仓库）
echo ">>> 拉取 CVE-2025 补丁..."
if [ ! -d "${WORK_DIR}/cve_fix_patch" ]; then
  rm -rf cve_fix_patch
  git clone --depth=1 https://github.com/cctv18/cve_fix_patch.git cve_fix_patch
fi
cd "${KERNEL_DIR}"
patch -p1 < "${WORK_DIR}/cve_fix_patch/cve2025.patch" || true
cd "${WORK_DIR}"

# 应用 config.patch（来自 cctv18 的 oppo_oplus_realme_sm8650 仓库）
echo ">>> 拉取 config.patch..."
rm -rf other_patch
git clone --depth=1 https://github.com/cctv18/oppo_oplus_realme_sm8650.git other_patch
cd "${KERNEL_DIR}"
patch -p1 < "${WORK_DIR}/other_patch/config.patch" || true
cd "${WORK_DIR}"

# 应用 droidspaces 补丁
if [[ "$APPLY_DROIDSPACES" != [nN] ]]; then
  echo ">>> 拉取 droidspaces 补丁..."
  rm -rf droidspaces_patch
  git clone --depth=1 https://github.com/cctv18/droidspaces-patch.git droidspaces_patch
  cd "${KERNEL_DIR}"
  patch -p1 < "${WORK_DIR}/droidspaces_patch/${APPLY_DROIDSPACES}.patch" || true
  cd "${WORK_DIR}"
fi

# ===== 应用 BBR 拥塞控制算法 =====
if [[ "$APPLY_BBR" == "y" ]]; then
  echo ">>> 添加 BBR 拥塞控制算法..."
  cd "${KERNEL_DIR}"
  grep -q "CONFIG_TCP_BBR=y" arch/arm64/configs/gki_defconfig || echo "CONFIG_TCP_BBR=y" >> arch/arm64/configs/gki_defconfig
  cd "${WORK_DIR}"
elif [[ "$APPLY_BBR" == "n" ]]; then
  echo ">>> 禁用 BBR 拥塞控制算法..."
  cd "${KERNEL_DIR}"
  sed -i 's/CONFIG_TCP_BBR=y/CONFIG_TCP_BBR=n/' arch/arm64/configs/gki_defconfig 2>/dev/null || true
  cd "${WORK_DIR}"
fi

# ===== 应用 LZ4 & zstd 补丁 =====
if [[ "$APPLY_LZ4" == [yY] ]]; then
  echo ">>> 拉取 LZ4 补丁..."
  if [ ! -d "${WORK_DIR}/lz4-repo" ]; then
    rm -rf lz4-repo
    git clone --depth=1 https://github.com/cctv18/lz4-kernel-patch.git lz4-repo
  fi
  cd "${KERNEL_DIR}"
  patch -p1 < "${WORK_DIR}/lz4-repo/lz4_1.10.0_gki.patch" || true
  patch -p1 < "${WORK_DIR}/lz4-repo/zstd_1.5.7_gki.patch" || true
  cd "${WORK_DIR}"
fi

# ===== 应用 LZ4-KD 补丁 =====
if [[ "$APPLY_LZ4KD" == [yY] ]]; then
  echo ">>> 拉取 Lz4-KD 补丁..."
  rm -rf SukiSU_patch
  git clone --depth=1 https://github.com/hyowang9743/SukiSU-patch.git SukiSU_patch
  cd "${KERNEL_DIR}"
  cp "${WORK_DIR}/SukiSU_patch/other/zram/lz4k/include/linux/lz4.h" "include/linux/lz4.h"
  cp "${WORK_DIR}/SukiSU_patch/other/zram/lz4k/lib/decompress_lz4kd.c" "lib/decompress_lz4kd.c"
  cp "${WORK_DIR}/SukiSU_patch/other/zram/lz4k/lib/decompress_lz4.c" "lib/decompress_lz4.c"
  cp -r "${WORK_DIR}/SukiSU_patch/other/zram/lz4k/include/linux/*" "./include/linux/"
  cp -r "${WORK_DIR}/SukiSU_patch/other/zram/lz4k/lib/*" "./lib"
  cp -r "${WORK_DIR}/SukiSU_patch/other/zram/lz4k/crypto/*" "./crypto"
  cp "${WORK_DIR}/SukiSU_patch/other/zram/zram_patch/6.1/lz4kd.patch" "./"
  patch -p1 < lz4kd.patch || true
  cd "${WORK_DIR}"
fi

# ===== 网络优化配置 =====
if [[ "$APPLY_BETTERNET" == [yY] ]]; then
  echo ">>> 应用网络优化配置..."
  cd "${KERNEL_DIR}"
  cp "${WORK_DIR}/RMX5060_6.1.157_KSUN-SUSFS.config" ".config"
  cd "${WORK_DIR}"
fi

# ===== 应用 SSG IO 调度器 =====
if [[ "$APPLY_SSG" == [yY] ]]; then
  echo ">>> 应用 SSG IO 调度器补丁..."
  rm -rf dss-repo
  git clone --depth=1 https://github.com/DistruX-OS/vendor_xiaomi_dsm.git dss-repo
  cd "${KERNEL_DIR}"
  patch -p1 < "${WORK_DIR}/dss-repo/android_kernel_oneplus_mt6989/0002-add-SSG-IO-Scheduler-support.patch" || true
  cd "${WORK_DIR}"
fi

# ===== 编译前准备 =====
echo ">>> 编译前准备..."
export PATH="${HOME}/bin:${PATH}"
export CC="${CC:-clang}"
export LD="${LD:-ld.lld}"
export AR="${AR:-llvm-ar}"

# 安装 ccache
if ! command -v ccache &>/dev/null; then
  echo ">>> 安装 ccache..."
  sudo apt update && sudo apt install -y ccache || true
fi

# 清理之前的编译产物
if [ -d "${KERNEL_DIR}/out" ]; then
  echo ">>> 清理旧编译产物..."
  rm -rf "${KERNEL_DIR}/out"
fi

# 清理 ABI 文件
echo ">>> 清除 ABI 文件..."
rm -f "${KERNEL_DIR}"/out/abi_gki_protected_exports_* 2>/dev/null || true

# 设置编译参数
export KCFLAGS="${KCFLAGS:-" -Wno-unused-function -Wno-unused-variable -Wno-unparameterized-variable"}"
export EXTRA_CFLAGS="${EXTRA_CFLAGS:-"-Wno-unused-function -Wno-unused-variable -Wno-unparameterized-variable -Wno cast-function-type -Wno int-conversion}"
export W=objdump
export WERROR=0
export KMP_USE_UPSTREAM_KERNEL_CONFIG=true
export SUBMIT_INFO="Built by GitHub Actions"

# 备份当前 .config
cp "${KERNEL_DIR}/.config" "${KERNEL_DIR}/.config.bak" 2>/dev/null || true

# ===== 配置内核 =====
echo ">>> 开始配置内核..."
cd "${KERNEL_DIR}"

# 使用 gki_defconfig 作为基础
make O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- gki_defconfig

# 合并自定义配置
if [[ "$APPLY_BETTERNET" == [yY] ]] && [ -f "${WORK_DIR}/RMX5060_6.1.157_KSUN-SUSFS.config" ]; then
  echo ">>> 应用自定义配置 (RMX5060_6.1.157_KSUN-SUSFS.config)..."
  cat "${WORK_DIR}/RMX5060_6.1.157_KSUN-SUSFS.config" >> "${KERNEL_DIR}/.config"
fi

# 确保 KSU 相关配置正确
if [[ "$KSU_BRANCH" == [yYrR] ]]; then
  echo ">>> 启用 KSU 配置..."
  sed -i '/CONFIG_KSU/d' "${KERNEL_DIR}/.config"
  echo 'CONFIG_KSU=y' >> "${KERNEL_DIR}/.config"
  echo 'CONFIG_KSU_SUSFS=y' >> "${KERNEL_DIR}/.config"
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  echo ">>> 启用 KSU (tiann) 配置..."
  sed -i '/CONFIG_KSU/d' "${KERNEL_DIR}/.config"
  echo 'CONFIG_KSU=y' >> "${KERNEL_DIR}/.config"
elif [[ "$KSU_BRANCH" == "l" || "$KSU_BRANCH" == "L" ]]; then
  echo ">>> 启用 LKM 模式配置..."
  sed -i '/CONFIG_KSU/d' "${KERNEL_DIR}/.config"
  echo 'CONFIG_KSU=y' >> "${KERNEL_DIR}/.config"
  echo 'CONFIG_KSU_SUSFS=n' >> "${KERNEL_DIR}/.config"
fi

# 确保 SUSFS 配置
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo ">>> 确保 SUSFS 配置正确..."
  sed -i '/CONFIG_KSU_SUSFS/d' "${KERNEL_DIR}/.config"
  echo 'CONFIG_KSU_SUSFS=y' >> "${KERNEL_DIR}/.config"
fi

# 生成最终配置
echo ">>> 生成最终配置..."
make O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig || make O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- silentoldconfig

# ===== 开始编译 =====
echo ">>> 开始编译内核..."
CORES=$(nproc)
echo ">>> 使用 ${CORES} 个核心进行编译"

cd "${KERNEL_DIR}"
make -j"${CORES}" O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  KBUILD_COMPILE_CHECK=no \
  KCFLAGS="${KCFLAGS}" \
  EXTRA_CFLAGS="${EXTRA_CFLAGS}" \
  WERROR=${WERROR} 2>&1 | tee "${WORK_DIR}/build.log" || {
    echo ">>> 编译失败，查看日志: ${WORK_DIR}/build.log"
    exit 1
}

# ===== 检查编译产物 =====
echo ">>> 检查编译产物..."
if [ ! -f "${OUT_DIR}/Image.gz-dtb" ]; then
  echo ">>> 错误: Image.gz-dtb 未找到!"
  echo ">>> 可用的镜像文件:"
  ls -la "${OUT_DIR}/" 2>/dev/null || ls -la "${KERNEL_DIR}/arch/arm64/boot/" 2>/dev/null
  exit 1
fi

echo ">>> 编译成功! 产物: ${OUT_DIR}/Image.gz-dtb"
ls -lh "${OUT_DIR}/Image.gz-dtb"

# ===== 打包 AnyKernel3 =====
echo ">>> 开始打包 AnyKernel3..."
mkdir -p "${CUSTOM_SUFFIX}"
cd "${OUT_DIR}"
cp Image.gz-dtb "${WORK_DIR}/${CUSTOM_SUFFIX}/"
cd "${WORK_DIR}"

# 复制 dtbs
if [ -d "${KERNEL_DIR}/out/arch/arm64/boot/dtbs" ]; then
  cp -r "${KERNEL_DIR}/out/arch/arm64/boot/dtbs/"* "${WORK_DIR}/${CUSTOM_SUFFIX}/" 2>/dev/null || true
fi

# 复制 vendor 文件
if [ -d "${KERNEL_DIR}/out/arch/arm64/boot/vendor" ]; then
  cp -r "${KERNEL_DIR}/out/arch/arm64/boot/vendor/"* "${WORK_DIR}/${CUSTOM_SUFFIX}/" 2>/dev/null || true
fi

# 下载并使用 AnyKernel3
if [ ! -d "AnyKernel3" ]; then
  echo ">>> 下载 AnyKernel3..."
  git clone https://github.com/cctv18/AnyKernel3.git
fi
cd AnyKernel3
sed -i 's/KERNEL_SUFFIX=.*/KERNEL_SUFFIX=-'"${CUSTOM_SUFFIX}"'/g' unpacker.sh
sed -i 's/DEFAULT_DEVICE=.*/DEFAULT_DEVICE='"${MANIFEST}"'/g' unpacker.sh
rm -f AnyKernel3.zip
echo ">>> 打包 AnyKernel3..."
./unpacker.sh

echo ">>> AnyKernel3 打包完成!"

# ===== 上传制品 =====
echo ">>> 生成制品..."
zip -r "${WORK_DIR}/${CUSTOM_SUFFIX}.zip" "${CUSTOM_SUFFIX}/" -x "*.DS_Store" "*Thumbs.db"

echo "========================================="
echo ">>> 编译完成! 制品位于: ${WORK_DIR}/${CUSTOM_SUFFIX}.zip"
echo "========================================="

# 打印制品信息
if [ -f "${WORK_DIR}/${CUSTOM_SUFFIX}.zip" ]; then
  echo ">>> 制品大小:"
  ls -lh "${WORK_DIR}/${CUSTOM_SUFFIX}.zip"
fi
