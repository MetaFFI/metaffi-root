# Set the shared library prefix to an empty string
set(CMAKE_SHARED_LIBRARY_PREFIX "")

# -----------------------------------------------------------------------------------------------

macro(collect_c_cpp_files_recursively paths prefix)

	set(${prefix}_include_dir ${CMAKE_CURRENT_LIST_DIR})

	file(GLOB_RECURSE ${prefix}_include CONFIGURE_DEPENDS
			"${path}/*.h"
			"${path}/*.hpp"
	)

	file(GLOB_RECURSE all_src CONFIGURE_DEPENDS
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

macro(collect_c_cpp_files paths prefix)

	set(${prefix}_include_dir ${CMAKE_CURRENT_LIST_DIR})

	set(${prefix}_include "")
	set(all_src "")

	foreach(path ${paths})
		file(GLOB ${prefix}_include_tmp CONFIGURE_DEPENDS
				"${path}/*.h"
				"${path}/*.hpp"
		)
		list(APPEND ${prefix}_include ${${prefix}_include_tmp})

		file(GLOB all_src_tmp CONFIGURE_DEPENDS
				"${path}/*.c"
				"${path}/*.cpp"
		)
		list(APPEND all_src ${all_src_tmp})
	endforeach()

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
# Optional: SKIP_DEPS - if set to TRUE, skips copying dependencies
# Optional: INCLUDE_IN_ALL - if set to TRUE, includes target in ALL
macro(c_cpp_exe TARGET_NAME SOURCE INCLUDE LIBRARIES COPYPATH)
	cmake_parse_arguments(ARG "SKIP_DEPS;INCLUDE_IN_ALL" "" "" ${ARGN})

	if(IS_ABSOLUTE "${COPYPATH}")
		set(CPP_COPY_DEST "${COPYPATH}")
	else()
		set(CPP_COPY_DEST "$ENV{METAFFI_HOME}/${COPYPATH}")
	endif()
	
	add_executable(${TARGET_NAME} ${SOURCE})
	if(ARG_INCLUDE_IN_ALL)
		set_target_properties(${TARGET_NAME} PROPERTIES EXCLUDE_FROM_ALL FALSE)
	else()
		set_target_properties(${TARGET_NAME} PROPERTIES EXCLUDE_FROM_ALL TRUE)
	endif()
	if(UNIX)
		# Set RPATH properties for executables on Unix
		set_target_properties(${TARGET_NAME} PROPERTIES
			BUILD_WITH_INSTALL_RPATH TRUE
			INSTALL_RPATH_USE_LINK_PATH FALSE
			INSTALL_RPATH "$ORIGIN")
	endif()

	target_include_directories(${TARGET_NAME} PRIVATE ${INCLUDE})

	foreach(LIB ${LIBRARIES})
		target_link_libraries(${TARGET_NAME} PRIVATE ${LIB})
	endforeach()

        # Copy the executable to the target directory
        add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
                        COMMAND ${CMAKE_COMMAND} -E echo "Going to copy $<TARGET_FILE:${TARGET_NAME}> to ${CPP_COPY_DEST}:"
                        COMMAND ${CMAKE_COMMAND} -E make_directory ${CPP_COPY_DEST}
                        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${TARGET_NAME}> ${CPP_COPY_DEST}
                        COMMAND ${CMAKE_COMMAND} -E echo "Copied $<TARGET_FILE:${TARGET_NAME}> to ${CPP_COPY_DEST}"
        )

	if(NOT ARG_SKIP_DEPS)
		# Conditional logic based on OS
		if(WIN32)
			# Windows: Use TARGET_RUNTIME_DLLS
			add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
					COMMAND ${CMAKE_COMMAND} -E echo "Going to Copy dependencies of $<TARGET_FILE:${TARGET_NAME}> to ${CPP_COPY_DEST}. Deps: $<TARGET_RUNTIME_DLLS:${TARGET_NAME}>"
					COMMAND ${CMAKE_COMMAND} -E copy_if_different
					$<TARGET_RUNTIME_DLLS:${TARGET_NAME}>
					${CPP_COPY_DEST}
					COMMAND ${CMAKE_COMMAND} -E echo "Copied dependencies of $<TARGET_FILE:${TARGET_NAME}> to ${CPP_COPY_DEST}"
					COMMAND_EXPAND_LISTS
			)
		elseif(UNIX AND NOT APPLE)
			# Linux: Use ldd to find and copy shared libraries
			add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
					COMMAND ${CMAKE_COMMAND} -E echo "Finding dependencies of $<TARGET_FILE:${TARGET_NAME}>:"
					COMMAND ldd $<TARGET_FILE:${TARGET_NAME}> | tee ldd_output.txt
					COMMAND ${CMAKE_COMMAND} -E echo "ldd output:"
					COMMAND ${CMAKE_COMMAND} -E cat ldd_output.txt
					COMMAND ${CMAKE_COMMAND} -E echo "Detected dependencies:"
					COMMAND grep -oP '/[^ ]+' ldd_output.txt | xargs -I {} echo {}
					COMMAND ${CMAKE_COMMAND} -E echo "Copying dependencies:"
					COMMAND grep -oP '/[^ ]+' ldd_output.txt | xargs -I {} ${CMAKE_COMMAND} -E copy_if_different {} ${CPP_COPY_DEST}
					COMMAND ${CMAKE_COMMAND} -E echo "Copied dependencies of $<TARGET_FILE:${TARGET_NAME}> to ${CPP_COPY_DEST}"
			)
		else()
			# Unsupported OS: Fail the configuration
			message(FATAL_ERROR "Unsupported OS: This macro only supports Windows and Linux.")
		endif()
	endif()
endmacro()


# same as c_cpp_exe but for a shared library
macro(c_cpp_shared_lib TARGET_NAME SOURCE INCLUDE LIBRARIES COPYPATH)
	cmake_parse_arguments(ARG "SKIP_DEPS;INCLUDE_IN_ALL" "" "" ${ARGN})

	if(IS_ABSOLUTE "${COPYPATH}")
		set(CPP_COPY_DEST "${COPYPATH}")
	else()
		set(CPP_COPY_DEST "$ENV{METAFFI_HOME}/${COPYPATH}")
	endif()
	
	add_library(${TARGET_NAME} SHARED ${SOURCE})
	if(ARG_INCLUDE_IN_ALL)
		set_target_properties(${TARGET_NAME} PROPERTIES EXCLUDE_FROM_ALL FALSE)
	else()
		set_target_properties(${TARGET_NAME} PROPERTIES EXCLUDE_FROM_ALL TRUE)
	endif()
	if(WIN32)
		set_target_properties(${TARGET_NAME} PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
	elseif(UNIX)
		# Set RPATH properties for shared libraries on Unix
		set_target_properties(${TARGET_NAME} PROPERTIES
			BUILD_WITH_INSTALL_RPATH TRUE
			INSTALL_RPATH_USE_LINK_PATH FALSE
			INSTALL_RPATH "$ORIGIN")
	endif()

	target_include_directories(${TARGET_NAME} PRIVATE ${INCLUDE})

	foreach(LIB ${LIBRARIES})
		target_link_libraries(${TARGET_NAME} PRIVATE ${LIB})
	endforeach()

	# copy using POST-BUILD the target to METAFFI_HOME/PATH
	# and print a message of the copy
	add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E echo "Going to copy $<TARGET_FILE:${TARGET_NAME}> to ${CPP_COPY_DEST}"
		COMMAND ${CMAKE_COMMAND} -E make_directory ${CPP_COPY_DEST}
		COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${TARGET_NAME}> ${CPP_COPY_DEST}
		COMMAND ${CMAKE_COMMAND} -E echo "Copied $<TARGET_FILE:${TARGET_NAME}> to ${CPP_COPY_DEST}"
		COMMAND_EXPAND_LISTS
	)

	if(NOT ARG_SKIP_DEPS)
		# Check if there are any runtime DLLs to copy
		# copy its dependencies to the same directory. Use TARGET_RUNTIME_DLLS expression to get the list of dependencies
		if(WIN32)
		get_target_property(RUNTIME_DLLS ${TARGET_NAME} INTERFACE_RUNTIME_DLLS)
			if(RUNTIME_DLLS)
				add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
						COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_RUNTIME_DLLS:${TARGET_NAME}> ${CPP_COPY_DEST}
						COMMAND ${CMAKE_COMMAND} -E echo "Copied dependencies of $<TARGET_FILE:${TARGET_NAME}> to ${CPP_COPY_DEST}"
						COMMAND_EXPAND_LISTS
				)
			endif()
		elseif(UNIX AND NOT APPLE)
			# Linux: Use ldd to find and copy shared libraries
			add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
					COMMAND ${CMAKE_COMMAND} -E echo "Finding dependencies of $<TARGET_FILE:${TARGET_NAME}>:"
					COMMAND ldd $<TARGET_FILE:${TARGET_NAME}> | tee ldd_output.txt
					COMMAND ${CMAKE_COMMAND} -E echo "ldd output:"
					COMMAND ${CMAKE_COMMAND} -E cat ldd_output.txt
					COMMAND ${CMAKE_COMMAND} -E echo "Detected dependencies:"
					COMMAND grep -oP '/[^ ]+' ldd_output.txt | xargs -I {} echo {}
					COMMAND ${CMAKE_COMMAND} -E echo "Copying dependencies:"
					COMMAND grep -oP '/[^ ]+' ldd_output.txt | xargs -I {} ${CMAKE_COMMAND} -E copy_if_different {} ${CPP_COPY_DEST}
					COMMAND ${CMAKE_COMMAND} -E echo "Copied dependencies of $<TARGET_FILE:${TARGET_NAME}> to ${CPP_COPY_DEST}"
			)
		else()
			# Unsupported OS: Fail the configuration
			message(FATAL_ERROR "Unsupported OS: This macro only supports Windows and Linux.")
		endif()
	endif()
endmacro()

