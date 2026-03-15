cmake_minimum_required(VERSION 3.29)

project(HiTriangle LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Optional: build with Vulkan-Hpp C++20 module (requires VulkanHpp find module in ./CMake)
# 编译器版本太老力，不支持C++20模块，以后需要再看吧
option(ENABLE_CPP20_MODULE "Enable C++20 module support for Vulkan-Hpp" OFF)

find_package(Vulkan REQUIRED)
find_package(glfw3 REQUIRED)

if(TARGET glfw)
    set(GLFW_TARGET glfw)
elseif(TARGET glfw3::glfw)
    set(GLFW_TARGET glfw3::glfw)
else()
    message(FATAL_ERROR "GLFW target not found. Expected target name: glfw or glfw3::glfw")
endif()

if(ENABLE_CPP20_MODULE)
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/CMake")
    find_package(VulkanHpp REQUIRED)

    set(CMAKE_CXX_SCAN_FOR_MODULES ON)

    add_library(VulkanCppModule)
    add_library(Vulkan::cppm ALIAS VulkanCppModule)

    target_include_directories(VulkanCppModule
        PUBLIC
            "${Vulkan_INCLUDE_DIR}"
            "${VulkanHpp_INCLUDE_DIRS}"
    )
    target_link_libraries(VulkanCppModule PUBLIC Vulkan::Vulkan)
    set_target_properties(VulkanCppModule PROPERTIES CXX_STANDARD 20)

    target_sources(VulkanCppModule
        PUBLIC
            FILE_SET cxx_modules TYPE CXX_MODULES
            BASE_DIRS "${VulkanHpp_CPPM_DIR}"
            FILES "${VulkanHpp_CPPM_DIR}/vulkan/vulkan.cppm"
    )
endif()

add_executable(hi_triangle hi_triangle.cpp)
add_executable(instance_creation instance_creation.cpp)

if(ENABLE_CPP20_MODULE)
    target_link_libraries(hi_triangle PRIVATE Vulkan::cppm ${GLFW_TARGET})
    target_compile_definitions(hi_triangle PRIVATE USE_CPP20_MODULES=1)
    target_link_libraries(instance_creation PRIVATE Vulkan::cppm ${GLFW_TARGET})
    target_compile_definitions(instance_creation PRIVATE USE_CPP20_MODULES=1)
else()
    target_link_libraries(hi_triangle PRIVATE Vulkan::Vulkan ${GLFW_TARGET})
    target_link_libraries(instance_creation PRIVATE Vulkan::Vulkan ${GLFW_TARGET})
endif()
