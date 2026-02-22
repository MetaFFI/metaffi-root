# PackageManagement.cmake

function(get_effective_vcpkg_root OUT_VAR)
	set(_root "")
	if(DEFINED VCPKG_ROOT AND NOT "${VCPKG_ROOT}" STREQUAL "")
		set(_root "${VCPKG_ROOT}")
	elseif(DEFINED ENV{VCPKG_ROOT} AND NOT "$ENV{VCPKG_ROOT}" STREQUAL "")
		set(_root "$ENV{VCPKG_ROOT}")
	endif()
	set(${OUT_VAR} "${_root}" PARENT_SCOPE)
endfunction()

function(resolve_vcpkg_executable OUT_VAR)
	set(_vcpkg_from_env "")
	get_effective_vcpkg_root(_effective_vcpkg_root)
	if(NOT "${_effective_vcpkg_root}" STREQUAL "")
		set(_candidate_exe "${_effective_vcpkg_root}/vcpkg.exe")
		set(_candidate_noext "${_effective_vcpkg_root}/vcpkg")
		if(EXISTS "${_candidate_exe}")
			set(_vcpkg_from_env "${_candidate_exe}")
		elseif(EXISTS "${_candidate_noext}")
			set(_vcpkg_from_env "${_candidate_noext}")
		endif()
	endif()

	if(NOT _vcpkg_from_env)
		find_program(_vcpkg_from_env NAMES vcpkg vcpkg.exe)
	endif()

	if(NOT _vcpkg_from_env AND NOT "${_effective_vcpkg_root}" STREQUAL "")
		find_program(_vcpkg_from_env NAMES vcpkg vcpkg.exe HINTS "${_effective_vcpkg_root}")
	endif()

	set(${OUT_VAR} "${_vcpkg_from_env}" PARENT_SCOPE)
endfunction()

# add_vcpkg macro
macro(add_vcpkg_integration)
	# Only set toolchain file if not already set
	if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
		set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
	endif()
	resolve_vcpkg_executable(VCPKG_EXECUTABLE)
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
        set(_vcpkg_port "${package}")
        string(TOLOWER "${_vcpkg_port}" _vcpkg_port)

        resolve_vcpkg_executable(VCPKG_EXECUTABLE)
        get_effective_vcpkg_root(_effective_vcpkg_root)

        unset(_vcpkg_root_args)
        if(NOT "${_effective_vcpkg_root}" STREQUAL "")
            set(_vcpkg_root_args --vcpkg-root "${_effective_vcpkg_root}")
        endif()

        set(_install_cmd ${VCPKG_EXECUTABLE})
        list(APPEND _install_cmd ${_vcpkg_root_args} install ${_vcpkg_port}:${_triplet})
        execute_process(
            COMMAND ${_install_cmd}
            RESULT_VARIABLE exit_code
            OUTPUT_VARIABLE _vcpkg_install_stdout
            ERROR_VARIABLE _vcpkg_install_stderr
        )

        if(exit_code)
            set(_vcpkg_install_output "${_vcpkg_install_stdout}\n${_vcpkg_install_stderr}")
            string(FIND "${_vcpkg_install_output}" "does not have a classic mode instance" _classic_mode_missing_pos)
            if(_classic_mode_missing_pos GREATER -1)
                message(STATUS "vcpkg classic mode unavailable, retrying with manifest mode for ${_vcpkg_port}:${_triplet}")

                set(_manifest_root "${CMAKE_BINARY_DIR}/_metaffi_vcpkg_manifest_${package}_${_triplet}")
                file(MAKE_DIRECTORY "${_manifest_root}")

                set(_vcpkg_builtin_baseline "")
                if(NOT "${_effective_vcpkg_root}" STREQUAL "")
                    execute_process(
                        COMMAND git -C "${_effective_vcpkg_root}" rev-parse HEAD
                        RESULT_VARIABLE _vcpkg_baseline_exit_code
                        OUTPUT_VARIABLE _vcpkg_builtin_baseline
                        OUTPUT_STRIP_TRAILING_WHITESPACE
                    )
                endif()
                if("${_vcpkg_builtin_baseline}" STREQUAL "")
                    message(FATAL_ERROR "Failed to determine vcpkg builtin baseline from VCPKG_ROOT: ${_effective_vcpkg_root}")
                endif()

                file(WRITE "${_manifest_root}/vcpkg.json"
                    "{\n"
                    "  \"name\": \"metaffi-${package}\",\n"
                    "  \"version-string\": \"0.0.0\",\n"
                    "  \"builtin-baseline\": \"${_vcpkg_builtin_baseline}\",\n"
                    "  \"dependencies\": [\"${_vcpkg_port}\"]\n"
                    "}\n"
                )

                unset(_manifest_install_root_args)
                if(DEFINED VCPKG_INSTALLED_DIR AND NOT "${VCPKG_INSTALLED_DIR}" STREQUAL "")
                    set(_manifest_install_root_args --x-install-root "${VCPKG_INSTALLED_DIR}")
                elseif(NOT "${_effective_vcpkg_root}" STREQUAL "")
                    set(_manifest_install_root_args --x-install-root "${_effective_vcpkg_root}/installed")
                endif()

                set(_manifest_cmd ${VCPKG_EXECUTABLE})
                list(APPEND _manifest_cmd
                    ${_vcpkg_root_args}
                    install
                    --triplet ${_triplet}
                    --x-manifest-root "${_manifest_root}"
                    ${_manifest_install_root_args}
                )
                execute_process(
                    COMMAND ${_manifest_cmd}
                    RESULT_VARIABLE exit_code
                    OUTPUT_VARIABLE _manifest_install_stdout
                    ERROR_VARIABLE _manifest_install_stderr
                )
            endif()
        endif()

        if(exit_code)
            message(FATAL_ERROR
                "Failed to install ${package} for ${_triplet}\n"
                "vcpkg stdout:\n${_vcpkg_install_stdout}\n"
                "vcpkg stderr:\n${_vcpkg_install_stderr}\n"
                "manifest stdout:\n${_manifest_install_stdout}\n"
                "manifest stderr:\n${_manifest_install_stderr}"
            )
        endif()

        # second try, now that vcpkg has installed it
        find_package(${package} ${ARGN} REQUIRED)
    endif()
endmacro()

# find_or_install_maven_package macro
# Downloads a Maven artifact to a destination directory if missing.
# Usage: find_or_install_maven_package(OUT_VAR GROUP_ID ARTIFACT_ID VERSION DEST_DIR)
function(find_or_install_maven_package OUT_VAR GROUP_ID ARTIFACT_ID VERSION DEST_DIR)
	if("${OUT_VAR}" STREQUAL "" OR "${GROUP_ID}" STREQUAL "" OR "${ARTIFACT_ID}" STREQUAL "" OR "${VERSION}" STREQUAL "" OR "${DEST_DIR}" STREQUAL "")
		message(FATAL_ERROR "find_or_install_maven_package requires OUT_VAR, GROUP_ID, ARTIFACT_ID, VERSION, DEST_DIR")
	endif()

	string(TOUPPER "${VERSION}" _version_upper)
	set(_is_floating FALSE)
	if(_version_upper STREQUAL "LATEST" OR _version_upper STREQUAL "RELEASE")
		set(_is_floating TRUE)
	endif()

	if(_is_floating)
		set(_jar_name "${ARTIFACT_ID}.jar")
	else()
		set(_jar_name "${ARTIFACT_ID}-${VERSION}.jar")
	endif()
	set(_jar_path "${DEST_DIR}/${_jar_name}")
	set(${OUT_VAR} "${_jar_path}" PARENT_SCOPE)

	if(EXISTS "${_jar_path}")
		return()
	endif()

	if(DEFINED MAVEN_EXECUTABLE)
		unset(MAVEN_EXECUTABLE CACHE)
	endif()
	if(WIN32)
		find_program(MAVEN_EXECUTABLE NAMES mvn.cmd mvn.bat mvn)
	else()
		find_program(MAVEN_EXECUTABLE mvn)
	endif()
	if(NOT MAVEN_EXECUTABLE)
		message(FATAL_ERROR "Maven (mvn) not found. Please install Maven or add it to PATH.")
	endif()

	file(MAKE_DIRECTORY "${DEST_DIR}")

	if(_is_floating)
		file(GLOB _old_jars
			"${DEST_DIR}/${ARTIFACT_ID}.jar"
			"${DEST_DIR}/${ARTIFACT_ID}-*.jar"
		)
		foreach(_old_jar IN LISTS _old_jars)
			file(REMOVE "${_old_jar}")
		endforeach()
	endif()

	set(_strip_version_arg "")
	if(_is_floating)
		set(_strip_version_arg "-DstripVersion=true")
	endif()

	set(_maven_command ${MAVEN_EXECUTABLE})
	if(WIN32 AND MAVEN_EXECUTABLE MATCHES "\\.(cmd|bat)$")
		set(_maven_command cmd /c "${MAVEN_EXECUTABLE}")
	endif()

	execute_process(
		COMMAND ${_maven_command}
			-q
			-Dartifact=${GROUP_ID}:${ARTIFACT_ID}:${VERSION}
			-DoutputDirectory=${DEST_DIR}
			-Dtransitive=false
			${_strip_version_arg}
			dependency:copy
		RESULT_VARIABLE exit_code
	)
	if(exit_code)
		message(FATAL_ERROR "Failed to download Maven artifact ${GROUP_ID}:${ARTIFACT_ID}:${VERSION}")
	endif()

	if(NOT EXISTS "${_jar_path}")
		file(GLOB _matches "${DEST_DIR}/${ARTIFACT_ID}-*.jar")
		list(LENGTH _matches _match_len)
		if(_match_len EQUAL 1)
			list(GET _matches 0 _match)
			set(${OUT_VAR} "${_match}" PARENT_SCOPE)
			return()
		endif()
		message(FATAL_ERROR "Maven artifact downloaded but jar not found: ${_jar_path}")
	endif()
endfunction()

# find_or_install_pip_package macro
# Ensures a Python package is installed via pip.
# Usage: find_or_install_pip_package(PACKAGE_NAME)
function(find_or_install_pip_package PACKAGE_NAME)
	if("${PACKAGE_NAME}" STREQUAL "")
		message(FATAL_ERROR "find_or_install_pip_package requires PACKAGE_NAME")
	endif()

	set(_pip_python_executable "")
	if(DEFINED Python3_EXECUTABLE AND NOT "${Python3_EXECUTABLE}" STREQUAL "" AND EXISTS "${Python3_EXECUTABLE}")
		set(_pip_python_executable "${Python3_EXECUTABLE}")
	elseif(DEFINED PYTHON_EXECUTABLE AND NOT "${PYTHON_EXECUTABLE}" STREQUAL "" AND EXISTS "${PYTHON_EXECUTABLE}")
		set(_pip_python_executable "${PYTHON_EXECUTABLE}")
	else()
		find_program(_pip_python_executable NAMES python3 python)
	endif()

	if(NOT _pip_python_executable)
		message(FATAL_ERROR "Python executable not found for pip installation")
	endif()

	execute_process(
		COMMAND ${_pip_python_executable} -m pip --version
		RESULT_VARIABLE pip_version_exit
		OUTPUT_QUIET
		ERROR_QUIET
	)
	if(pip_version_exit)
		execute_process(
			COMMAND ${_pip_python_executable} -m ensurepip --upgrade
			RESULT_VARIABLE ensurepip_exit
			OUTPUT_VARIABLE ensurepip_stdout
			ERROR_VARIABLE ensurepip_stderr
		)
		if(ensurepip_exit)
			message(FATAL_ERROR
				"Failed to bootstrap pip for ${_pip_python_executable}\n"
				"ensurepip stdout:\n${ensurepip_stdout}\n"
				"ensurepip stderr:\n${ensurepip_stderr}"
			)
		endif()
	endif()

	execute_process(
		COMMAND ${_pip_python_executable} -m pip show ${PACKAGE_NAME}
		RESULT_VARIABLE pip_show_exit
		OUTPUT_QUIET
		ERROR_QUIET
	)

	if(pip_show_exit)
		execute_process(
			COMMAND ${_pip_python_executable} -m pip install ${PACKAGE_NAME} --upgrade
			RESULT_VARIABLE pip_install_exit
			OUTPUT_VARIABLE pip_install_stdout
			ERROR_VARIABLE pip_install_stderr
		)

		if(pip_install_exit AND UNIX AND NOT APPLE)
			execute_process(
				COMMAND ${_pip_python_executable} -m pip install ${PACKAGE_NAME} --upgrade --break-system-packages
				RESULT_VARIABLE pip_install_exit
				OUTPUT_VARIABLE pip_install_stdout
				ERROR_VARIABLE pip_install_stderr
			)
		endif()

		if(pip_install_exit)
			message(FATAL_ERROR
				"Failed to install pip package: ${PACKAGE_NAME}\n"
				"python executable: ${_pip_python_executable}\n"
				"pip stdout:\n${pip_install_stdout}\n"
				"pip stderr:\n${pip_install_stderr}"
			)
		endif()
	endif()
endfunction()

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
				COMMAND ${CMAKE_COMMAND} -E echo "Copying vcpkg runtime dependencies for ${TARGET_NAME} to $ENV{METAFFI_HOME}/${COPYPATH} - $<CONFIG> configuration..."
				COMMAND ${CMAKE_COMMAND} -E make_directory "$ENV{METAFFI_HOME}/${COPYPATH}"
				COMMAND ${CMAKE_COMMAND}
					-DSRC_DIR="$<IF:$<CONFIG:Debug>,${VCPKG_RUNTIME_DIR_DEBUG},${VCPKG_RUNTIME_DIR_RELEASE}>"
					-DDST_DIR="$ENV{METAFFI_HOME}/${COPYPATH}"
					-DPATTERN="${LIB_PATTERN}"
					-P "${CMAKE_SOURCE_DIR}/cmake/CopyMatchingFiles.cmake"
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
