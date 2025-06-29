# PackageManagement.cmake

# add_vcpkg macro
macro(add_vcpkg_integration)
	# Only set toolchain file if not already set
	if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
		set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
	endif()
	find_program(VCPKG_EXECUTABLE vcpkg)
	if(NOT VCPKG_EXECUTABLE)
		message(FATAL_ERROR "vcpkg not found")
	endif()

	set(VCPKG_LIBRARY_LINKAGE dynamic)  # Force shared library installation

	set(Boost_USE_STATIC_LIBS OFF)
	set(Boost_USE_STATIC_RUNTIME OFF)
endmacro()

macro(find_or_install_package package)
    # ---------------- Triplet detection -----------------
    # 1. If the vcpkg tool-chain is active, this is always set.
    if(DEFINED VCPKG_TARGET_TRIPLET)
        set(_triplet "${VCPKG_TARGET_TRIPLET}")
    else()
        # 2. Otherwise derive a reasonable host default.
        if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
            set(_triplet "x64-windows")
        elseif(APPLE)
            # arm/Intel distinction for modern Macs
            if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
                set(_triplet "arm64-osx")
            else()
                set(_triplet "x64-osx")
            endif()
        else() # Linux, BSD, …
            set(_triplet "x64-linux")
        endif()
    endif()
    # ----------------------------------------------------

    # First normal lookup (user may have pre-installed the pkg already)
    find_package(${package} ${ARGN})

    if(NOT ${package}_FOUND)
        find_program(VCPKG_EXECUTABLE vcpkg REQUIRED)

        execute_process(
            COMMAND ${VCPKG_EXECUTABLE} install ${package}:${_triplet}
            RESULT_VARIABLE exit_code
        )
        if(exit_code)
            message(FATAL_ERROR "Failed to install ${package} for ${_triplet}")
        endif()

        # second try, now that vcpkg has installed it
        find_package(${package} ${ARGN} REQUIRED)
    endif()
endmacro()
