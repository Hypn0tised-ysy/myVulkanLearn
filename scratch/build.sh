#!/usr/bin/env bash
set -euo pipefail

# 这个脚本用于在 Windows/MSYS2 或类 Unix shell 中一键完成：
# 1) 清理旧的着色器产物
# 2) 用 CMake 重新配置 Debug/Release
# 3) 分别编译 Debug/Release
#
# 设计目标：
# - 尽量不依赖手工环境配置
# - 优先使用 vcpkg toolchain，确保 find_package 走同一套依赖来源
# - 在任意一步失败时立即退出，避免“前一步失败但后一步继续执行”

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# build-debug / build-release 目录的公共前缀
BUILD_DIR_BASE="${SCRIPT_DIR}/build"
# Slang 产物路径：每次构建前先删掉，避免旧产物干扰
SHADER_SPV="${SCRIPT_DIR}/shaders/slang.spv"

TOOLCHAIN_CANDIDATES=(
	# 优先使用用户显式设置的 VCPKG_ROOT
	"${VCPKG_ROOT:-}/scripts/buildsystems/vcpkg.cmake"
	# 兼容你当前固定安装位置
	"D:/vcpkg/scripts/buildsystems/vcpkg.cmake"
	# 兼容某些 shell 把 D: 映射成 /d 的情况
	"/d/vcpkg/scripts/buildsystems/vcpkg.cmake"
)

VCPKG_TOOLCHAIN=""
# 从候选列表中找到第一个真实存在的 toolchain 文件
for candidate in "${TOOLCHAIN_CANDIDATES[@]}"; do
	if [[ -n "$candidate" && -f "$candidate" ]]; then
		VCPKG_TOOLCHAIN="$candidate"
		break
	fi
done

if [[ -z "$VCPKG_TOOLCHAIN" ]]; then
	echo "Error: vcpkg toolchain file not found. Set VCPKG_ROOT or install vcpkg to D:/vcpkg." >&2
	exit 1
fi

# 支持外部覆盖 triplet；默认 x64-windows
# 这样可以扩展到 x64-windows-static 等变体而无需改脚本
VCPKG_TRIPLET="${VCPKG_TARGET_TRIPLET:-x64-windows}"
CMAKE_COMMON_ARGS=(
	# 强制 CMake 使用 vcpkg toolchain 解析依赖
	"-DCMAKE_TOOLCHAIN_FILE=${VCPKG_TOOLCHAIN}"
	# 强制使用指定 triplet 的库集合
	"-DVCPKG_TARGET_TRIPLET=${VCPKG_TRIPLET}"
)

GENERATOR_ARGS=()
# 如果系统安装了 ninja，就优先使用 Ninja 生成器（通常更快）
# 注意：首次配置用的生成器会写入缓存，后续同目录不能混用其他生成器
if command -v ninja >/dev/null 2>&1; then
	GENERATOR_ARGS=(-G Ninja)
fi

echo "Cleaning shader artifact..."
# 删除旧的 SPIR-V 产物，确保后续编译使用当前源码重新生成
cmake -E rm -f "$SHADER_SPV"

# 重新配置
# 编译

echo "Configuring project-debug..."
# 配置 Debug：生成项目文件并解析依赖
cmake -B "${BUILD_DIR_BASE}-debug" -DCMAKE_BUILD_TYPE=Debug -S "$SCRIPT_DIR" "${GENERATOR_ARGS[@]}" "${CMAKE_COMMON_ARGS[@]}"
echo "Building project-debug..."
# 实际编译 Debug 目标
cmake --build "${BUILD_DIR_BASE}-debug" --config Debug
echo "Build-debug finished."


echo "Configuring project-release..."
# 配置 Release：与 Debug 分离目录，避免相互污染
cmake -B "${BUILD_DIR_BASE}-release" -DCMAKE_BUILD_TYPE=Release -S "$SCRIPT_DIR" "${GENERATOR_ARGS[@]}" "${CMAKE_COMMON_ARGS[@]}"
echo "Building project-release..."
# 实际编译 Release 目标
cmake --build "${BUILD_DIR_BASE}-release" --config Release
echo "Build-release finished."


