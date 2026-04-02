cmake_minimum_required(VERSION 3.29)

project(HiTriangle LANGUAGES CXX)

# 项目统一 C++ 标准配置。
# - C++20：为了与现代 Vulkan 示例/工具链保持一致。
# - REQUIRED ON：防止编译器降级到更老标准。
# - EXTENSIONS OFF：尽量避免编译器私有扩展，提升可移植性。
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Optional: build with Vulkan-Hpp C++20 module
option(ENABLE_CPP20_MODULE "Enable C++20 module support for Vulkan-Hpp" OFF)

# 依赖发现策略说明：
# 这里显式使用 CONFIG 模式（例如 glfw3 CONFIG REQUIRED），
# 目的是优先使用 vcpkg 安装出的包配置文件，避免误命中不一致的系统 FindXXX 模块。
# Vulkan 则保持标准 find_package(Vulkan REQUIRED) 用法，
# 可由系统 SDK 或 vcpkg 提供。
find_package (glfw3 CONFIG REQUIRED)
find_package (glm CONFIG REQUIRED)
find_package (Vulkan REQUIRED)      # Use installed Vulkan SDK version
find_package (tinyobjloader CONFIG REQUIRED)

# vcpkg 的 stb 包通常通过 FindStb.cmake 暴露变量而非统一 imported target。
# 因此后续会兼容多种变量名/目标名，避免不同平台或包版本下构建失败。
find_package(Stb REQUIRED)

# 查找 Slang 编译器
find_program(SLANGC_EXECUTABLE
    NAMES slangc slangc.exe
    HINTS
        "$ENV{VULKAN_SDK}/Bin"
        "$ENV{VULKAN_SDK}/Bin32"
    "$ENV{VCPKG_ROOT}/installed/x64-windows/tools/shader-slang"
    "D:/vcpkg/installed/x64-windows/tools/shader-slang"
    "/d/vcpkg/installed/x64-windows/tools/shader-slang"
)

if(NOT SLANGC_EXECUTABLE)
    # 不把 slangc 设为硬依赖：
    # - 有 slangc：编译着色器
    # - 无 slangc：跳过着色器编译目标，但 C++ 主体仍可构建
    message(WARNING "slangc not found. Shader compilation target will be skipped.")
endif()

# glfw 在不同包中可能导出不同目标名：
# - glfw
# - glfw3::glfw
# 这里统一映射到 GLFW_TARGET，后续链接只写一次。
if(TARGET glfw)
    set(GLFW_TARGET glfw)
elseif(TARGET glfw3::glfw)
    set(GLFW_TARGET glfw3::glfw)
else()
    message(FATAL_ERROR "GLFW target not found. Expected target name: glfw or glfw3::glfw")
endif()

# 公共配置目标
# 使用 INTERFACE 库 project_options 聚合：
# - include directories
# - compile definitions
# - link libraries
# 所有可执行程序只需链接一次该目标即可复用公共设置。
add_library(project_options INTERFACE)

# stb
# stb 的导出形式不统一，这里按优先级兜底：
# 1) 优先 imported target
# 2) 各种可能的 include 变量名
if(TARGET stb::stb)
    target_link_libraries(project_options
        INTERFACE
            stb::stb
    )
elseif(DEFINED stb_INCLUDE_DIRS)
    target_include_directories(project_options
        INTERFACE
            ${stb_INCLUDE_DIRS}
    )
elseif(DEFINED STB_INCLUDE_DIRS)
    target_include_directories(project_options
        INTERFACE
            ${STB_INCLUDE_DIRS}
    )
elseif(DEFINED Stb_INCLUDE_DIR)
    target_include_directories(project_options
        INTERFACE
            ${Stb_INCLUDE_DIR}
    )
elseif(DEFINED Stb_INCLUDE_DIRS)
    target_include_directories(project_options
        INTERFACE
            ${Stb_INCLUDE_DIRS}
    )
else()
    message(FATAL_ERROR "stb found but no include dirs or imported target were provided")
endif()

# tinyobjloader
# tinyobjloader 同样兼容多种导出方式，
# 避免因为包管理器差异导致不可构建。
if(TARGET tinyobjloader::tinyobjloader)
    target_link_libraries(project_options
        INTERFACE
            tinyobjloader::tinyobjloader
    )
elseif(TARGET tinyobjloader)
    target_link_libraries(project_options
        INTERFACE
            tinyobjloader
    )
elseif(DEFINED tinyobjloader_INCLUDE_DIRS)
    target_include_directories(project_options
        INTERFACE
            ${tinyobjloader_INCLUDE_DIRS}
    )
    if(DEFINED tinyobjloader_LIBRARIES)
        target_link_libraries(project_options
            INTERFACE
                ${tinyobjloader_LIBRARIES}
        )
    endif()
elseif(DEFINED TINYOBJLOADER_INCLUDE_DIRS)
    target_include_directories(project_options
        INTERFACE
            ${TINYOBJLOADER_INCLUDE_DIRS}
    )
    if(DEFINED TINYOBJLOADER_LIBRARIES)
        target_link_libraries(project_options
            INTERFACE
                ${TINYOBJLOADER_LIBRARIES}
        )
    endif()
else()
    message(FATAL_ERROR "tinyobjloader found but no imported target or include dirs were provided")
endif()

# glm
# glm 一般是 header-only；不同版本可能导出
# - glm::glm-header-only
# - glm::glm
# 这里统一兼容。
if(TARGET glm::glm-header-only)
    target_link_libraries(project_options
        INTERFACE
            glm::glm-header-only
    )
elseif(TARGET glm::glm)
    target_link_libraries(project_options
        INTERFACE
            glm::glm
    )
else()
    message(FATAL_ERROR "glm found but no imported target was provided")
endif()

target_compile_definitions(project_options
    INTERFACE
    # 关闭 Vulkan-Hpp 的 struct 构造器，减少隐式构造带来的歧义，
    # 并与教程中的显式赋值风格保持一致。
        VULKAN_HPP_NO_STRUCT_CONSTRUCTORS=1
)

# Release 优化参数按编译器分开：
# - MSVC: /O2
# - GCC/Clang: -O3
if(MSVC)
    target_compile_options(project_options
        INTERFACE
            $<$<CONFIG:Release>:/O2>
    )
else()
    target_compile_options(project_options
        INTERFACE
            $<$<CONFIG:Release>:-O3>
    )
endif()


target_link_libraries(project_options
    INTERFACE
        # 全部示例都依赖窗口系统与输入处理（GLFW）
        ${GLFW_TARGET}
)

if(ENABLE_CPP20_MODULE)
    # 仅在启用 C++20 module 时，才把自定义 CMake 模块目录加入搜索路径。
    # 避免影响常规构建时内置 Find 模块的解析行为。
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/CMake")
    find_package(VulkanHpp REQUIRED)

    # 让 CMake 扫描模块依赖图
    set(CMAKE_CXX_SCAN_FOR_MODULES ON)

    # VulkanCppModule 封装 Vulkan-Hpp 的 cppm 文件，
    # 再通过别名 Vulkan::cppm 暴露给下游。
    add_library(VulkanCppModule)
    add_library(Vulkan::cppm ALIAS VulkanCppModule)

    target_include_directories(VulkanCppModule
        PUBLIC
            "${Vulkan_INCLUDE_DIR}"
            "${VulkanHpp_INCLUDE_DIRS}"
    )

    target_link_libraries(VulkanCppModule
        PUBLIC
            Vulkan::Vulkan
    )

    set_target_properties(VulkanCppModule PROPERTIES
        CXX_STANDARD 20
    )

    target_sources(VulkanCppModule
        PUBLIC
            FILE_SET cxx_modules TYPE CXX_MODULES
            BASE_DIRS "${VulkanHpp_CPPM_DIR}"
            # Vulkan-Hpp 官方提供的模块入口
            FILES "${VulkanHpp_CPPM_DIR}/vulkan/vulkan.cppm"
    )

    target_link_libraries(project_options
        INTERFACE
            Vulkan::cppm
    )

    target_compile_definitions(project_options
        INTERFACE
            USE_CPP20_MODULES=1
    )
else()
    # 默认路径：直接链接 Vulkan::Vulkan，不走 C++20 模块。
    target_link_libraries(project_options
        INTERFACE
            Vulkan::Vulkan
    )
endif()

# 编译着色器 compile shaders
function (add_slang_shader_target TARGET)
    if(NOT SLANGC_EXECUTABLE)
        # 当缺少 slangc 时，创建一个空目标保持依赖图完整。
        # 这样 add_dependencies(app compile_shaders) 仍然成立，
        # 不会因为目标不存在而报错。
        add_custom_target(${TARGET}
                COMMENT "slangc not found. Skipping Slang shader compilation."
        )
        return()
    endif()

  # SOURCES 参数用于传入 .slang 文件路径
  cmake_parse_arguments ("SHADER" "" "" "SOURCES" ${ARGN})
  set (SHADERS_DIR ${CMAKE_CURRENT_LIST_DIR}/shaders)
  set (SHADER_OUTPUT ${SHADERS_DIR}/slang.spv)
  # 这里固定编译两个入口点，输出合并到同一个 SPIR-V 文件
  set (ENTRY_POINTS -entry vertMain -entry fragMain)

  # 真实着色器编译命令：
  # -target spirv / -profile spirv_1_4：指定输出与版本
  # -emit-spirv-directly：直接输出 SPIR-V
  # -fvk-use-entrypoint-name：保留入口点名称便于后续匹配
  add_custom_command (
      OUTPUT  ${SHADER_OUTPUT}
      COMMAND ${CMAKE_COMMAND} -E make_directory ${SHADERS_DIR}
      COMMAND ${SLANGC_EXECUTABLE} ${SHADER_SOURCES} -target spirv -profile spirv_1_4 -emit-spirv-directly -fvk-use-entrypoint-name ${ENTRY_POINTS} -o ${SHADER_OUTPUT}
          WORKING_DIRECTORY ${SHADERS_DIR}
      DEPENDS ${SHADER_SOURCES}
          COMMENT "Compiling Slang Shaders"
          VERBATIM
  )
  add_custom_target (${TARGET} DEPENDS ${SHADER_OUTPUT})
endfunction()

set(APP_SOURCES

# triangle_src
    hi_triangle
    instance_creation
    validation_layers
    select_physical_device
    logical_device
    window_surface_integration
    swap_chain
    image_view
    shader_modules
    fixed_function
    graphics_pipeline_complete
    command_buffer
    hello_triangle
# 
    vulkan_learn


)

# 默认源码在 triangle_src 下；个别文件可以落在根目录作为兜底。
set(APP_SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/triangle_src)

# 编译 Slang 着色器
add_slang_shader_target(compile_shaders
    SOURCES ${CMAKE_CURRENT_LIST_DIR}/shaders/shader.slang
)

# 按列表批量创建可执行目标，避免重复模板代码。
foreach(app IN LISTS APP_SOURCES)
    set(APP_SOURCE_FILE "${APP_SOURCE_DIR}/${app}.cpp")
    if(NOT EXISTS "${APP_SOURCE_FILE}")
        # 兼容少量直接放在 scratch 根目录的示例文件
        set(APP_SOURCE_FILE "${CMAKE_CURRENT_LIST_DIR}/${app}.cpp")
    endif()

    if(NOT EXISTS "${APP_SOURCE_FILE}")
        message(FATAL_ERROR "Source file not found for target '${app}'. Checked: ${APP_SOURCE_DIR}/${app}.cpp and ${CMAKE_CURRENT_LIST_DIR}/${app}.cpp")
    endif()

    add_executable(${app} ${APP_SOURCE_FILE})
    # 统一继承公共依赖、定义、编译选项
    target_link_libraries(${app} PRIVATE project_options)
    # 添加着色器编译的依赖
    # 让可执行目标在构建前先触发着色器目标（即便该目标可能是空目标）
    add_dependencies(${app} compile_shaders)

    # 运行时资源复制：
    # 把 models/textures 拷贝到可执行文件目录旁，
    # 确保从 build-*/(Debug|Release) 直接启动也能找到相对路径资源。
    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/models")
        add_custom_command(TARGET ${app} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${CMAKE_CURRENT_LIST_DIR}/models"
                "$<TARGET_FILE_DIR:${app}>/models"
            VERBATIM
        )
    endif()

    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/textures")
        add_custom_command(TARGET ${app} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${CMAKE_CURRENT_LIST_DIR}/textures"
                "$<TARGET_FILE_DIR:${app}>/textures"
            VERBATIM
        )
    endif()

    # 仅在存在 slangc 时复制生成出的 SPIR-V，避免无编译器时复制失败。
    if(SLANGC_EXECUTABLE)
        add_custom_command(TARGET ${app} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:${app}>/shaders"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_LIST_DIR}/shaders/slang.spv"
                "$<TARGET_FILE_DIR:${app}>/shaders/slang.spv"
            VERBATIM
        )
    endif()
endforeach()