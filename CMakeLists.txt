# This is the root of the MetaFFI project
cmake_minimum_required(VERSION 3.10)

cmake_policy(SET CMP0167 NEW)

# Make sure METAFFI_HOME and METAFFI_SOURCE_ROOT environment variables are set
if(NOT DEFINED ENV{METAFFI_HOME} OR "$ENV{METAFFI_HOME}" STREQUAL "")
  message(FATAL_ERROR
    "METAFFI_HOME environment variable is not set. It should store the directory of MetaFFI Installation directory (or output)."
  )
endif()

if(NOT DEFINED ENV{METAFFI_SOURCE_ROOT} OR "$ENV{METAFFI_SOURCE_ROOT}" STREQUAL "")
  message(FATAL_ERROR
    "METAFFI_SOURCE_ROOT environment variable is not set. It should store the directory of MetaFFI source root directory"
  )
endif()


# set the ./cmake path (as absolute path) to a variable
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include(Environment)

# load the msvc environment
load_msvc_env(x64)

include(PackageManagement)

# add vcpkg integration - MUST be before project() call
add_vcpkg_integration()

set(CMAKE_VERBOSE_MAKEFILE ON)


# Set the project name
project(MetaFFI VERSION 0.3.1)

# include the .cmake files in the ./cmake directory
include(GlobalSettings)
include(Go)
include(InstallUtils)
include(Python3)
include(Utils)
include(MetaFFIGitRepository)
include(CPP)
include(Logging)
find_or_install_package(spdlog)
include(PackageManagement)
include(JVM)
include(CopyMatchingFiles)



# add the global policies, global settings, and debug settings
add_global_policies()
c_cpp_global_settings()
c_cpp_debug_settings()
os_and_platform()

# add CTest
enable_testing()

# set output directory
set(METAFFI_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

# set the output directory where binaries are copied to
set(ENV{METAFFI_HOME} "${CMAKE_CURRENT_SOURCE_DIR}/output/${OS_NAME}/x64/${CMAKE_BUILD_TYPE}/")

# verify the projects exists 
verify_project_exists("${METAFFI_ROOT_DIR}/metaffi-core" "https://github.com/MetaFFI/metaffi-core.git")
verify_project_exists("${METAFFI_ROOT_DIR}/sdk" "https://github.com/MetaFFI/plugin-sdk.git")

verify_project_exists("${METAFFI_ROOT_DIR}/lang-plugin-python3" "https://github.com/MetaFFI/lang-plugin-python3.git")
verify_project_exists("${METAFFI_ROOT_DIR}/lang-plugin-go" "https://github.com/MetaFFI/lang-plugin-go.git")
verify_project_exists("${METAFFI_ROOT_DIR}/lang-plugin-jvm" "https://github.com/MetaFFI/lang-plugin-jvm.git")

verify_project_exists("${METAFFI_ROOT_DIR}/tests" "https://github.com/MetaFFI/Tests.git")


# add projects
add_subdirectory(sdk)
add_subdirectory(metaffi-core)
add_subdirectory(lang-plugin-python3)
add_subdirectory(lang-plugin-jvm)
add_subdirectory(lang-plugin-go)
add_subdirectory(tests)
#add_subdirectory(lang-plugin-c)
#add_subdirectory(metaffi-installer)

add_custom_target(MetaFFI DEPENDS metaffi_sdk metaffi-core python3 jvm go)
  
