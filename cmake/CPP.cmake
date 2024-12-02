
macro(set_rpath_to_c_cpp_targets_globally)
	if(APPLE)
		set(CMAKE_MACOSX_RPATH 1) # tell MacOS RPATH is in use
		set(CMAKE_INSTALL_RPATH "@loader_path")
	elseif(UNIX)
		list(APPEND CMAKE_INSTALL_RPATH "$ORIGIN")
	endif()
endmacro()
# -----------------------------------------------------------------------------------------------
macro(collect_c_cpp_files path prefix)

	set(${prefix}_include_dir ${CMAKE_CURRENT_LIST_DIR})

	file(GLOB_RECURSE ${prefix}_include
			"${path}/*.h"
			"${path}/*.hpp"
	)

	file(GLOB_RECURSE all_src
			"${path}/*.c"
			"${path}/*.cpp"
	)

	# Filter out test files
	set(${prefix}_src "")
	foreach(file ${all_src})
		if(NOT file MATCHES "_test\\.c$" AND NOT file MATCHES "_test\\.cpp$")
			list(APPEND ${prefix}_src ${file})
		endif()
	endforeach()

endmacro()

# -----------------------------------------------------------------------------------------------

# c_cpp_exe macro builds an executable target from a:
# list of source
# list of include directories
# list of libraries
# copies the executable to PATH with CMAKE_INSTALL_PREFIX as the root
# sets the target name to the variable TARGET_NAME
macro(c_cpp_exe TARGET_NAME SOURCE INCLUDE LIBRARIES COPYPATH)
	add_executable(${TARGET_NAME} ${SOURCE})
	target_include_directories(${TARGET_NAME} PRIVATE ${INCLUDE})

	foreach(LIB ${LIBRARIES})
		target_link_libraries(${TARGET_NAME} PRIVATE ${LIB})
	endforeach()

	# copy using POST-BUILD the target to CMAKE_INSTALL_PREFIX/PATH
	add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${TARGET_NAME}> $ENV{METAFFI_HOME}/${COPYPATH}
	)

	# copy its dependencies to the same directory. Use TARGET_RUNTIME_DLLS expression to get the list of dependencies
	add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E copy_if_different
			$<TARGET_RUNTIME_DLLS:${TARGET_NAME}>
			$ENV{METAFFI_HOME}/${COPYPATH}
			COMMAND_EXPAND_LISTS
	)
endmacro()

# same as c_cpp_exe but for a shared library
macro(c_cpp_shared_lib TARGET_NAME SOURCE INCLUDE LIBRARIES COPYPATH)
	add_library(${TARGET_NAME} SHARED ${SOURCE})
	if(WIN32)
		set_target_properties(${TARGET_NAME} PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
	endif()

	target_include_directories(${TARGET_NAME} PRIVATE ${INCLUDE})

	foreach(LIB ${LIBRARIES})
		target_link_libraries(${TARGET_NAME} PRIVATE ${LIB})
	endforeach()

	# copy using POST-BUILD the target to METAFFI_HOME/PATH
	# and print a message of the copy
	add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E make_directory $ENV{METAFFI_HOME}/${COPYPATH}
		COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${TARGET_NAME}> $ENV{METAFFI_HOME}/${COPYPATH}
		COMMAND ${CMAKE_COMMAND} -E echo "Copied $<TARGET_FILE:${TARGET_NAME}> to $ENV{METAFFI_HOME}/${COPYPATH}"
		COMMAND_EXPAND_LISTS
	)

	# copy its dependencies to the same directory. Use TARGET_RUNTIME_DLLS expression to get the list of dependencies
	add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_RUNTIME_DLLS:${TARGET_NAME}> $ENV{METAFFI_HOME}/${COPYPATH} COMMAND_EXPAND_LISTS
		COMMAND ${CMAKE_COMMAND} -E echo "Copied dependencies of $<TARGET_FILE:${TARGET_NAME}> to $ENV{METAFFI_HOME}/${COPYPATH}"
		COMMAND_EXPAND_LISTS
	)
endmacro()

