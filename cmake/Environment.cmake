# msvc_env.cmake ------------------------------------------------------
#
# Usage:
#   include(msvc_env.cmake)
#   load_msvc_env(x64)      # x86 / arm64 / etc.
#
# Call this *before* the first project() or enable_language().

function(split_by_newline_charwise_sentinel input_var output_var)
    set(input "${${input_var}}")
    set(out "")
    set(line "")
    string(LENGTH "${input}" input_len)
    set(i 0)
    while(i LESS input_len)
        string(SUBSTRING "${input}" ${i} 1 c)
        if(c STREQUAL "\r")
            # skip
        elseif(c STREQUAL "\n")
            set(out "${out}${line}<:NL:>")
            set(line "")
        else()
            set(line "${line}${c}")
        endif()
        math(EXPR i "${i}+1")
    endwhile()
    if(NOT line STREQUAL "")
        set(out "${out}${line}<:NL:>")
    endif()
    set(${output_var} "${out}" PARENT_SCOPE)
endfunction()

macro(split_env_pairs IN_VAR OUT_VAR)
  # 1) Read the input buffer
  set(__buf "${${IN_VAR}}")

  # 2) Normalize line endings defensively (harmless if already done)
  string(REPLACE "\r\n" "\n" __buf "${__buf}")
  string(REPLACE "\r"    "\n" __buf "${__buf}")

  # 3) Turn into a list of lines
  # NOTE: This is safe because ';' should already be protected by your sentinel.
  string(REPLACE "\n" ";" __lines "${__buf}")

  # 4) Filter: keep only KEY=VALUE; skip banners and CMD pseudo-vars (=C:=...)
  set(__out "")
  foreach(__ln IN LISTS __lines)
    # trim whitespace
    string(STRIP "${__ln}" __ln)
    if(__ln STREQUAL "")
      continue()
    endif()

    # Only accept lines that look like real env assignments:
    # KEY may contain letters, digits, underscore, and parentheses (matches your original)
    if(__ln MATCHES "^[A-Za-z0-9_()]+=")
      list(APPEND __out "${__ln}")
    endif()
  endforeach()

  # 5) Return result to caller
  set(${OUT_VAR} "${__out}")
endmacro()



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
		#message(STATUS "raw env:\n${_env_raw}\n\n")

		# Normalize newlines
		string(REPLACE "\r\n" "\n" _env_raw "${_env_raw}")
		string(REPLACE "\r" "\n" _env_raw "${_env_raw}")

		# replace ; with <:SEMICOLON:>
		string(REPLACE ";" "<:SEMICOLON:>" _env_raw "${_env_raw}")
		# replace \ with <:BACKSLASH:>
		string(REPLACE "\\" "<:BACKSLASH:>" _env_raw "${_env_raw}")

		# Find all lines of the form KEY=VALUE
		split_env_pairs(_env_raw _env_pairs)

#		foreach(_pair IN LISTS _env_pairs)
#			string(STRIP "${_pair}" _pair)
#			message(STATUS "raw PAIR: '${_pair}'")
#		endforeach()

		foreach(_pair IN LISTS _env_pairs)
			# remove the leading and trailing newlines
			string(STRIP "${_pair}" _pair)

			# replace <:SEMICOLON:> with ;
			string(REPLACE "<:SEMICOLON:>" ";" _pair "${_pair}")
			# replace <:BACKSLASH:> with \
			string(REPLACE "<:BACKSLASH:>" "\\" _pair "${_pair}")

			# Match key and value using groups
			string(REGEX MATCH "^([A-Za-z_0-9\\(\\)]+)=([^\n]*)$" _dummy "${_pair}")
			set(_key "${CMAKE_MATCH_1}")
			set(_val "${CMAKE_MATCH_2}")

			# message(STATUS "Processing: PAIR: ${_pair} ||| _key: ${_key} ||| _val: ${_val}")

			if(_key STREQUAL "")
				message(FATAL_ERROR "Regex failed to extract environment variable key from: '${_pair}'")
			endif()
			string(TOUPPER "${_key}" _key_upper)
			if(_key_upper STREQUAL "PATH")
				set(ENV{PATH} "${_val};$ENV{PATH}")
			else()
				set(ENV{${_key}} "${_val}")
			endif()
		endforeach()

		
		# make sure cl.exe and rc.exe are found
		find_program(CL_EXE NAMES cl.exe)
		find_program(RC_EXE NAMES rc.exe)
		if(NOT CL_EXE)
			message(FATAL_ERROR "cl.exe not found")
		endif()
		if(NOT RC_EXE)
			message(FATAL_ERROR "rc.exe not found")
		endif()

		#message(STATUS "--------------------------------")
		#message(STATUS "PATH: $ENV{PATH}")

		# in INCLUDE and LIB - replace any double \\ with single \
		string(REPLACE "\\\\" "\\" _INCLUDE "${_INCLUDE}")
		string(REPLACE "\\\\" "\\" _LIB "${_LIB}")

		#message(STATUS "INCLUDE: $ENV{INCLUDE}")
		#message(STATUS "LIB: $ENV{LIB}")
		#message(STATUS "LIBPATH: $ENV{LIBPATH}")
		#message(STATUS "WindowsSdkDir: $ENV{WindowsSdkDir}")
		#message(STATUS "VCINSTALLDIR: $ENV{VCINSTALLDIR}")

		# Convert environment variables to explicit compiler and linker flags
		# This ensures the build phase has access to all necessary paths
		
		# Convert INCLUDE to compiler include paths
		if(DEFINED ENV{INCLUDE})
			# Split the INCLUDE path and add each as a separate -I flag
			string(REPLACE ";" ";" _include_paths "$ENV{INCLUDE}")
			foreach(_include_path ${_include_paths})
				add_compile_options("-I${_include_path}")
			endforeach()
		endif()
		
		# Convert LIB to linker library paths
		if(DEFINED ENV{LIB})
			# Split the LIB path and add each as a separate -LIBPATH flag
			string(REPLACE ";" ";" _lib_paths "$ENV{LIB}")
			foreach(_lib_path ${_lib_paths})
				add_link_options("-LIBPATH:${_lib_path}")
			endforeach()
		endif()
		
		# Convert LIBPATH to additional linker library paths
		if(DEFINED ENV{LIBPATH})
			# Split the LIBPATH and add each as a separate -LIBPATH flag
			string(REPLACE ";" ";" _libpath_paths "$ENV{LIBPATH}")
			foreach(_libpath_path ${_libpath_paths})
				add_link_options("-LIBPATH:${_libpath_path}")
			endforeach()
		endif()

	endif()
endmacro()
