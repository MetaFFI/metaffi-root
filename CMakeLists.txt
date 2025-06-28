# This is the root of the MetaFFI project
cmake_minimum_required(VERSION 3.10)

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
include(PackageManagement)
include(JVM)



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

# add projects
add_subdirectory(metaffi-core)
add_subdirectory(lang-plugin-python311)
add_subdirectory(lang-plugin-openjdk)
add_subdirectory(lang-plugin-go)
#add_subdirectory(lang-plugin-c)
#add_subdirectory(metaffi-installer)

add_custom_target(MetaFFI DEPENDS metaffi-core python311 openjdk go)
