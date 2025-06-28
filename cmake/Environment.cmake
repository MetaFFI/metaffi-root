# msvc_env.cmake ------------------------------------------------------
#
# Usage:
#   include(msvc_env.cmake)
#   load_msvc_env(x64)      # x86 / arm64 / etc.
#
# Call this *before* the first project() or enable_language().

macro(load_msvc_env ARCH)
    # Do nothing on non-Windows hosts
    if(WIN32)

		set(_vswhere_default
		"$ENV{ProgramFiles\(x86\)}/Microsoft Visual Studio/Installer/vswhere.exe")

		# If not found, also check x64
		if(NOT EXISTS "${_vswhere_default}")
			set(_vswhere_default
				"$ENV{ProgramFiles}/Microsoft Visual Studio/Installer/vswhere.exe")
		endif()

		# Locate the newest Visual Studio that has the VC toolset
		execute_process(
			COMMAND "${_vswhere_default}"
					-latest
					-products *
					-requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64
					-property installationPath
			OUTPUT_VARIABLE VS_ROOT
			OUTPUT_STRIP_TRAILING_WHITESPACE)

		if(NOT VS_ROOT)
			message(FATAL_ERROR "load_msvc_env(): No suitable Visual Studio installation found")
		endif()

		file(TO_NATIVE_PATH "${VS_ROOT}/Common7/Tools/VsDevCmd.bat" VSDEVCMD)

		# Create a temporary batch file to avoid quoting issues
		set(_temp_bat "${CMAKE_CURRENT_BINARY_DIR}/temp_env.bat")
		file(WRITE "${_temp_bat}" "call \"${VSDEVCMD}\" -arch=${ARCH}\nset\n")

		# Run the temporary batch file
		execute_process(
			COMMAND cmd /c "${_temp_bat}"
			OUTPUT_VARIABLE _env_raw
			ERROR_VARIABLE _env_error
		)

		if(NOT _env_raw)
			message(FATAL_ERROR "Failed to execute ${VSDEVCMD}. Error: ${_env_error}")
		endif()

		# Import each VAR=VALUE line into CMake process env
		string(REPLACE "\r\n" "\n" _env_raw "${_env_raw}")
		
		# Variables to explicitly skip (they interfere with MSVC detection)
		set(_skip_vars LLVM_DIR)
		
		# Split by newlines to get individual lines - use a more robust approach
		string(REGEX MATCHALL "[^=]+=.*" _env_lines "${_env_raw}")
		
		foreach(_line IN LISTS _env_lines)
			string(FIND "${_line}" "=" _eq)
			if(_eq GREATER 0)
				string(SUBSTRING "${_line}" 0 ${_eq} _name)
				math(EXPR _val_begin "${_eq}+1")
				string(SUBSTRING "${_line}" ${_val_begin} -1 _value)
				
				# Check if we should skip this variable
				list(FIND _skip_vars "${_name}" _skip_found)
				if(_skip_found GREATER_EQUAL 0)
					message(STATUS "Explicitly skipping ENV: ${_name}")
				else()
					# Process all variables except PATH
					if("${_name}" STREQUAL "Path")
						# Concatenate PATH instead of replacing
						set(ENV{PATH} "${_value};$ENV{PATH}")
						message(STATUS "Appended to PATH: ${_value}")
					else()
						# Set all other variables normally
						set(ENV{${_name}} "${_value}")
						message(STATUS "Set ENV: ${_name}=${_value}")
					endif()
				endif()
			endif()
		endforeach()
	endif()
endmacro()
