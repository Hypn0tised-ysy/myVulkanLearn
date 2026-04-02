#!/usr/bin/env bash
set -e

BUILD_DIR="build"

# 如果 build 目录存在，则删除
if [ -d "$BUILD_DIR-debug" ]; then
echo "Removing existing build-debug directory..."
rm -rf "$BUILD_DIR-debug"
fi

if [ -d "$BUILD_DIR-release" ]; then
echo "Removing existing build-release directory..."
rm -rf "$BUILD_DIR-release"
fi