
macro(print_cmake_vars_list)
	message(STATUS "CMAKE_CURRENT_SOURCE_DIR: ${CMAKE_CURRENT_SOURCE_DIR}")
	message(STATUS "CMAKE_MODULE_PATH: ${CMAKE_MODULE_PATH}")
	message(STATUS "CMAKE_BINARY_DIR: ${CMAKE_BINARY_DIR}")
	message(STATUS "CMAKE_SOURCE_DIR: ${CMAKE_SOURCE_DIR}")
	message(STATUS "CMAKE_CURRENT_BINARY_DIR: ${CMAKE_CURRENT_BINARY_DIR}")
	message(STATUS "CMAKE_CURRENT_LIST_DIR: ${CMAKE_CURRENT_LIST_DIR}")
	message(STATUS "CMAKE_CURRENT_LIST_FILE: ${CMAKE_CURRENT_LIST_FILE}")
	message(STATUS "CMAKE_CURRENT_LIST_LINE: ${CMAKE_CURRENT_LIST_LINE}")
	message(STATUS "CMAKE_PROJECT_NAME: ${CMAKE_PROJECT_NAME}")
	message(STATUS "CMAKE_BUILD_DIR: ${CMAKE_BUILD_DIR}")
	message(STATUS "CMAKE_PROJECT_VERSION: ${CMAKE_PROJECT_VERSION}")
endmacro()
#-----------------------------------------------------------------------------------------------
# remove files from list that are inside a given path
macro(remove_files_inside_path FILES PATH)

	set(NEW_FILES "")

	foreach(file ${FILES})

		# switch the files separator to /
		string(REPLACE "\\" "/" file "${file}")

		if(NOT "${file}" MATCHES ".*/${PATH}/.*")
			# Add the file to the new list
			list(APPEND NEW_FILES "${file}")
		endif()
	endforeach()

	set(${FILES} ${NEW_FILES} PARENT_SCOPE)

endmacro()

#-----------------------------------------------------------------------------------------------
# make sure the given app executable exists and found
function(get_app_path APP_NAME APP_PATH)
	find_program(${APP_PATH} "${APP_NAME}")
	if(NOT ${APP_PATH})
		message(FATAL_ERROR "${APP_NAME} application is not found")
	endif()
endfunction()
#-----------------------------------------------------------------------------------------------
macro(assert_metaffi_env)
	if(NOT DEFINED ENV{METAFFI_HOME})
		message(FATAL_ERROR "METAFFI_HOME environment variable is not set")
	endif()
endmacro()
#-----------------------------------------------------------------------------------------------
macro(link_to_pthread_for_non_windows TARGET)
	if(NOT WIN32)
		target_link_libraries(${TARGET} PRIVATE pthread)
	endif()
endmacro()
#-----------------------------------------------------------------------------------------------
# Receives a directory and a list of files (delimited by whitespace)
# and returns the list of files prepended with the directory
function(prepend_dir_to_files RESULT DIR FILES)
	separate_arguments(FILES)

	foreach(f IN ITEMS ${FILES})
		list(APPEND RESULT_tmp "${DIR}/${f}")
	endforeach()

	set(${RESULT} ${RESULT_tmp} PARENT_SCOPE)
endfunction()
#-----------------------------------------------------------------------------------------------
function(copy_file_post_build TARGET SOURCE DEST)
	add_custom_command(TARGET ${TARGET} POST_BUILD
			COMMAND "${CMAKE_COMMAND}" -E copy
			${SOURCE}
			${DEST}
			COMMENT "Copy ${SOURCE} -> ${DEST}"
			USES_TERMINAL)
endfunction()
#-----------------------------------------------------------------------------------------------
function(copy_file_from_project_binary TARGET FILENAME DEST_DIR)
	copy_file_post_build(${TARGET} ${PROJECT_BINARY_DIR}/${FILENAME} ${DEST_DIR}/${FILENAME})
endfunction()
#-----------------------------------------------------------------------------------------------
function(copy_file_from_project_binary_to_metaffi_home TARGET FILENAME)
	copy_file_from_project_binary(${TARGET} ${FILENAME} $ENV{METAFFI_HOME})
endfunction()
#-----------------------------------------------------------------------------------------------
# https://stackoverflow.com/questions/32183975/how-to-print-all-the-properties-of-a-target-in-cmake
function(print_properties)
	message("CMAKE_PROPERTY_LIST = ${CMAKE_PROPERTY_LIST}")
endfunction()
#-----------------------------------------------------------------------------------------------
function(print_target_properties target)
	if(NOT TARGET ${target})
		message(STATUS "There is no target named '${target}'")
		return()
	endif()

	foreach(property ${CMAKE_PROPERTY_LIST})
		string(REPLACE "<CONFIG>" "${CMAKE_BUILD_TYPE}" property ${property})

		# Fix https://stackoverflow.com/questions/32197663/how-can-i-remove-the-the-location-property-may-not-be-read-from-target-error-i
		if(property STREQUAL "LOCATION" OR property MATCHES "^LOCATION_" OR property MATCHES "_LOCATION$")
			continue()
		endif()

		get_property(was_set TARGET ${target} PROPERTY ${property} SET)
		if(was_set)
			get_target_property(value ${target} ${property})
			message("${target} ${property} = ${value}")
		endif()
	endforeach()
endfunction()
#-----------------------------------------------------------------------------------------------
function(get_sdk_utils_sources OUT_VAR)
	file(GLOB tmp ${METAFFI_SDK}/utils/*.cpp ${METAFFI_SDK}/utils/*.c)
	list(FILTER tmp EXCLUDE REGEX "_test\\.cpp$") # exclude unitests
	set(${OUT_VAR} ${tmp} PARENT_SCOPE)
endfunction()
#-----------------------------------------------------------------------------------------------
function(get_sdk_runtime_sources OUT_VAR)
	file(GLOB tmp ${METAFFI_SDK}/runtime/*.cpp ${METAFFI_SDK}/runtime/*.c)
	list(FILTER tmp EXCLUDE REGEX "_test\\.cpp$") # exclude unitests
	set(${OUT_VAR} ${tmp} PARENT_SCOPE)
endfunction()
#-----------------------------------------------------------------------------------------------
function(get_dir_sources DIR OUT_VAR)
	file(GLOB tmp ${DIR}/*.cpp ${DIR}/*.c)
	list(FILTER tmp EXCLUDE REGEX "_test\\.cpp$") # exclude unitests
	set(${OUT_VAR} "${tmp}" PARENT_SCOPE)
endfunction()
#-----------------------------------------------------------------------------------------------
# Downloads a file from URL if it doesn't exist at the given path
# Sets VAR_NAME to FILE_PATH, and downloads from URL if file doesn't exist
function(if_exists_or_download VAR_NAME FILE_PATH URL)
	set(${VAR_NAME} ${FILE_PATH} PARENT_SCOPE)
	
	if(NOT EXISTS ${FILE_PATH})
		get_filename_component(FILENAME ${FILE_PATH} NAME)
		message(STATUS "Downloading ${FILENAME}...")
		file(DOWNLOAD
			${URL}
			${FILE_PATH}
			SHOW_PROGRESS
			TLS_VERIFY ON
		)
	endif()
endfunction()
#-----------------------------------------------------------------------------------------------
