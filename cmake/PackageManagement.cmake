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

# copy_vcpkg_runtime_dependencies macro
# Copies vcpkg runtime dependencies to $METAFFI_HOME.
# Handles platform-specific shared libraries:
#   - Windows: .dll files from bin directory
#   - Linux: .so files from lib directory
#   - macOS: .dylib files from lib directory
#
# This macro must be called AFTER c_cpp_exe/c_cpp_shared_lib so it runs after the
# executable is copied to $METAFFI_HOME.
#
# Usage: copy_vcpkg_runtime_dependencies(target_name copy_path)
# Example: copy_vcpkg_runtime_dependencies(my_test_executable ".")
macro(copy_vcpkg_runtime_dependencies TARGET_NAME COPYPATH)
	if(DEFINED VCPKG_INSTALLED_DIR AND DEFINED VCPKG_TARGET_TRIPLET)
		# Determine the output directory based on OS and build type
		# This matches the logic in the root CMakeLists.txt
		if(WIN32)
			set(OS_NAME "windows")
		elseif(APPLE)
			set(OS_NAME "macos")
		elseif(UNIX)
			set(OS_NAME "linux")
		endif()

		set(_METAFFI_OUTPUT_DIR "${CMAKE_SOURCE_DIR}/output/${OS_NAME}/x64/$<CONFIG>")

		if(WIN32)
			# Windows: DLLs are in bin directories
			set(VCPKG_RUNTIME_DIR_DEBUG "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/bin")
			set(VCPKG_RUNTIME_DIR_RELEASE "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/bin")

			# Copy entire bin directory to ensure all DLLs are available
			# This runs AFTER c_cpp_exe copies the executable
			add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
				COMMAND ${CMAKE_COMMAND} -E echo "Copying vcpkg runtime dependencies for ${TARGET_NAME} to ${_METAFFI_OUTPUT_DIR}/${COPYPATH} ($<CONFIG> configuration)..."
				COMMAND ${CMAKE_COMMAND} -E make_directory "${_METAFFI_OUTPUT_DIR}/${COPYPATH}"
				COMMAND ${CMAKE_COMMAND} -E copy_directory
					"$<IF:$<CONFIG:Debug>,${VCPKG_RUNTIME_DIR_DEBUG},${VCPKG_RUNTIME_DIR_RELEASE}>"
					"${_METAFFI_OUTPUT_DIR}/${COPYPATH}"
				COMMENT "Copying vcpkg runtime dependencies for ${TARGET_NAME}"
			)
		elseif(UNIX)
			# Linux/macOS: Shared libraries are in lib directories
			set(VCPKG_RUNTIME_DIR_DEBUG "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/lib")
			set(VCPKG_RUNTIME_DIR_RELEASE "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/lib")

			if(APPLE)
				set(LIB_PATTERN "*.dylib")
			else()
				set(LIB_PATTERN "*.so*")
			endif()

			# Copy only shared libraries (not static .a files) to $METAFFI_HOME
			add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
				COMMAND ${CMAKE_COMMAND} -E echo "Copying vcpkg runtime dependencies for ${TARGET_NAME} to $ENV{METAFFI_HOME}/${COPYPATH} ($<CONFIG> configuration)..."
				COMMAND ${CMAKE_COMMAND} -E make_directory "$ENV{METAFFI_HOME}/${COPYPATH}"
				COMMAND ${CMAKE_COMMAND} -E copy_if_different
					"$<IF:$<CONFIG:Debug>,${VCPKG_RUNTIME_DIR_DEBUG},${VCPKG_RUNTIME_DIR_RELEASE}>/${LIB_PATTERN}"
					"$ENV{METAFFI_HOME}/${COPYPATH}/"
				COMMENT "Copying vcpkg runtime dependencies for ${TARGET_NAME} to $ENV{METAFFI_HOME}"
			)

			# On Linux/macOS, update rpath so executable can find copied libraries
			if(APPLE)
				set_target_properties(${TARGET_NAME} PROPERTIES
					BUILD_RPATH "@loader_path"
					INSTALL_RPATH "@loader_path"
				)
			else()
				set_target_properties(${TARGET_NAME} PROPERTIES
					BUILD_RPATH "$ORIGIN"
					INSTALL_RPATH "$ORIGIN"
				)
			endif()
		endif()
	endif()
endmacro()
