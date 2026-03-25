#!/usr/bin/env bash
set -e

BUILD_DIR="build"
SHADER_SPV="shaders/slang.spv"

echo "Cleaning shader artifact..."
rm -f "$SHADER_SPV"

# 重新配置
# 编译

echo "Configuring project-debug..."
cmake -B "$BUILD_DIR-debug" -DCMAKE_BUILD_TYPE=Debug -S . -G Ninja
echo "Building project-debug..."
cmake --build "$BUILD_DIR-debug" --config Debug
echo "Build-debug finished."


echo "Configuring project-release..."
cmake -B "$BUILD_DIR-release" -DCMAKE_BUILD_TYPE=Release -S . -G Ninja
echo "Building project-release..."
cmake --build "$BUILD_DIR-release" --config Release
echo "Build-release finished."


