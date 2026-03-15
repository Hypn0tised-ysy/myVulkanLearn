#!/usr/bin/env bash
set -e

BUILD_DIR="build"

# 如果 build 目录存在，则删除

if [ -d "$BUILD_DIR" ]; then
echo "Removing existing build directory..."
rm -rf "$BUILD_DIR"
fi

# 重新配置

echo "Configuring project..."
cmake -B "$BUILD_DIR" -S . -G Ninja

# 编译

echo "Building project..."
cmake --build "$BUILD_DIR"

# 进入 build 目录

cd "$BUILD_DIR"

echo "Build finished. Now in $(pwd)"
