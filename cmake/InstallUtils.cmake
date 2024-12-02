
macro(install_boost BOOST_LIBS)
	foreach(LIB ${ARGV})
		# Find the required Boost component
		find_package(Boost REQUIRED COMPONENTS ${LIB})

		# Check if the library is header-only
		get_target_property(BOOST_LIB_LOCATION Boost::${LIB} LOCATION)
		if(BOOST_LIB_LOCATION)
			# Install the specific Boost library
			if(WIN32)
				# On Windows, the Boost libraries are installed in the bin directory
				install(FILES ${BOOST_LIB_LOCATION} DESTINATION bin)
			else()
				# On Unix-like systems, the Boost libraries are installed in the lib directory
				install(FILES ${BOOST_LIB_LOCATION} DESTINATION lib)
			endif()

			# Print the message during the installation phase
			install(CODE "message(STATUS \"Installing Boost ${LIB}: ${BOOST_LIB_LOCATION}\")")
		else()
			# Print a message indicating that the library is header-only
			message(STATUS "Boost ${LIB} is a header-only library and doesn't need to be installed.")
		endif()
	endforeach()
endmacro()

macro(install_python3)
	# Get the location of the Python3 library
	get_target_property(PYTHON3_LIB_LOCATION Python3::Python IMPORTED_LOCATION_RELEASE)

	if(PYTHON3_LIB_LOCATION)
		# Install the Python3 library
		install(FILES ${PYTHON3_LIB_LOCATION} DESTINATION lib)

		# Print the message during the installation phase
		install(CODE "message(STATUS \"Installing Python3: ${PYTHON3_LIB_LOCATION}\")")
	else()
		# Print a message indicating that the library is not found
		message(STATUS "Python3 library not found.")
	endif()
endmacro()

macro(install_target TARGET DESTINATION)

	set(options INSTALL_DEPENDENCIES)

	cmake_parse_arguments("install_target"
			"${options}" # options - bool value
			"PATTERN" # single val
			"" # multi-vals
			${ARGN})

	# If INSTALL_DEPENDENCIES was not provided, set it to FALSE
	if(NOT DEFINED install_target_INSTALL_DEPENDENCIES)
		set(install_target_INSTALL_DEPENDENCIES FALSE)
	endif()

	if(NOT install_target_PATTERN)
		set(PATTERN "python|boost|expat|jvm")
	else()
		set(PATTERN ${install_target_PATTERN})
	endif()

	install(TARGETS ${TARGET}
			DESTINATION ${DESTINATION}
			RUNTIME_DEPENDENCY_SET DEPENDS_SET)


	if(${INSTALL_DEPENDENCIES})
		list(APPEND SEARCH_DIRS $ENV{METAFFI_HOME})
		list(APPEND SEARCH_DIRS ${Boost_INCLUDE_DIR}/../lib)
		if(WIN32) # Add Path environment variable
			cmake_path(CONVERT "$ENV{Path}" TO_CMAKE_PATH_LIST CMAKE_WIN_PATH)
			list(APPEND SEARCH_DIRS ${CMAKE_WIN_PATH})
		endif()

		install(RUNTIME_DEPENDENCY_SET DEPENDS_SET
				PRE_INCLUDE_REGEXES ${PATTERN}
				PRE_EXCLUDE_REGEXES
				[[api-ms-win-.*]] [[ext-ms-.*]] [[kernel32\.dll]]
				[[bcrypt.dll]] [[mfplat.dll]] [[msvcrt.dll]] [[ole32.dll]] [[secur32.dll]] [[user32.dll]] [[vcruntime140.dll]]
				[[ws2_32.dll]] [[wpaxholder.dll]]
				[[libgcc_s_seh-1\.dll]] [[libstdc\+\+\-6.dll]]
				POST_EXCLUDE_REGEXES
				[[.*/system32/.*\.dll]]
				DIRECTORIES ${SEARCH_DIRS})
	endif()

endmacro()