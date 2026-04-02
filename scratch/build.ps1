Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 本脚本用于在 Windows PowerShell 下完成一键构建：
# 1) 清理旧着色器产物
# 2) 重新配置 Debug/Release
# 3) 编译 Debug/Release
#
# 关键目标：
# - 固定走 vcpkg toolchain，依赖来源一致
# - 任意命令失败立刻中断
# - 默认使用 Visual Studio 生成器（与 x64-windows triplet 配套稳定）

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @()
    )

    # 执行外部命令
    & $Command @Arguments
    # 对外部程序，PowerShell 不会总是因为非 0 返回码自动抛错，
    # 所以这里显式检查 $LASTEXITCODE 来实现“失败即停”。
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed (exit code $LASTEXITCODE): $Command $($Arguments -join ' ')"
    }
}

# 当前脚本所在目录，作为 CMake -S 源目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# build-debug / build-release 目录前缀
$BuildDirBase = Join-Path $ScriptDir 'build'
# Slang 产物路径，构建前会删除
$ShaderSpv = Join-Path $ScriptDir 'shaders/slang.spv'

$ToolchainCandidates = @()
if ($env:VCPKG_ROOT) {
    # 优先尊重用户设置的 VCPKG_ROOT
    $ToolchainCandidates += (Join-Path $env:VCPKG_ROOT 'scripts/buildsystems/vcpkg.cmake')
}
$ToolchainCandidates += @(
    # 兼容当前固定安装位置
    'D:/vcpkg/scripts/buildsystems/vcpkg.cmake',
    # 兼容某些 shell 路径映射风格
    '/d/vcpkg/scripts/buildsystems/vcpkg.cmake'
)

$VcpkgToolchain = $null
foreach ($candidate in $ToolchainCandidates) {
    # 找到第一个存在的 toolchain 即可
    if ($candidate -and (Test-Path $candidate)) {
        $VcpkgToolchain = $candidate
        break
    }
}

if (-not $VcpkgToolchain) {
    throw 'vcpkg toolchain file not found. Set VCPKG_ROOT or install vcpkg to D:/vcpkg.'
}

$VcpkgTriplet = if ($env:VCPKG_TARGET_TRIPLET) { $env:VCPKG_TARGET_TRIPLET } else { 'x64-windows' }

$GeneratorArgs = @()
# 默认不强制 Ninja，这样会走 VS 生成器，更适合 Windows + x64-windows triplet
# 如需 Ninja，可手动设置 USE_NINJA=1
if ($env:USE_NINJA -eq '1') {
    if (Get-Command ninja -ErrorAction SilentlyContinue) {
        $GeneratorArgs = @('-G', 'Ninja')
    } else {
        throw 'USE_NINJA=1 is set but ninja is not available in PATH.'
    }
}

Write-Host 'Cleaning shader artifact...'
# 删除旧 SPIR-V，避免旧文件误导调试
Invoke-Checked -Command cmake -Arguments @('-E', 'rm', '-f', $ShaderSpv)

$DebugBuildDir = "$BuildDirBase-debug"
$ReleaseBuildDir = "$BuildDirBase-release"

$CommonArgs = @(
    # 强制 CMake 通过 vcpkg toolchain 解析 find_package
    "-DCMAKE_TOOLCHAIN_FILE=$VcpkgToolchain",
    # 强制使用指定 triplet 的依赖集合
    "-DVCPKG_TARGET_TRIPLET=$VcpkgTriplet"
)

Write-Host 'Configuring project-debug...'
# --fresh 会清掉旧缓存，避免历史生成器/缓存参数冲突
$DebugConfigureArgs = @('--fresh', '-B', $DebugBuildDir, '-S', $ScriptDir, '-DCMAKE_BUILD_TYPE=Debug') + $GeneratorArgs + $CommonArgs
Invoke-Checked -Command cmake -Arguments $DebugConfigureArgs
Write-Host 'Building project-debug...'
Invoke-Checked -Command cmake -Arguments @('--build', $DebugBuildDir, '--config', 'Debug')
Write-Host 'Build-debug finished.'

Write-Host 'Configuring project-release...'
# Release 独立目录，避免与 Debug 产物混杂
$ReleaseConfigureArgs = @('--fresh', '-B', $ReleaseBuildDir, '-S', $ScriptDir, '-DCMAKE_BUILD_TYPE=Release') + $GeneratorArgs + $CommonArgs
Invoke-Checked -Command cmake -Arguments $ReleaseConfigureArgs
Write-Host 'Building project-release...'
Invoke-Checked -Command cmake -Arguments @('--build', $ReleaseBuildDir, '--config', 'Release')
Write-Host 'Build-release finished.'
