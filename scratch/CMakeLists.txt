cmake_minimum_required(VERSION 3.29)

project(HiTriangle LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Optional: build with Vulkan-Hpp C++20 module
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

# 公共配置目标
add_library(project_options INTERFACE)

target_compile_definitions(project_options
    INTERFACE
        VULKAN_HPP_NO_STRUCT_CONSTRUCTORS=1
)

target_link_libraries(project_options
    INTERFACE
        ${GLFW_TARGET}
)

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
    target_link_libraries(project_options
        INTERFACE
            Vulkan::Vulkan
    )
endif()

set(APP_SOURCES
    hi_triangle
    instance_creation
    validation_layers
    select_physical_device
    logical_device
    window_surface_integration
    swap_chain
)

foreach(app IN LISTS APP_SOURCES)
    add_executable(${app} ${app}.cpp)
    target_link_libraries(${app} PRIVATE project_options)
endforeach()