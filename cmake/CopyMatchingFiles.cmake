if(NOT DEFINED SRC_DIR)
	message(FATAL_ERROR "CopyMatchingFiles.cmake: SRC_DIR is required")
endif()

if(NOT DEFINED DST_DIR)
	message(FATAL_ERROR "CopyMatchingFiles.cmake: DST_DIR is required")
endif()

if(NOT DEFINED PATTERN)
	message(FATAL_ERROR "CopyMatchingFiles.cmake: PATTERN is required")
endif()

file(GLOB MATCHED_FILES "${SRC_DIR}/${PATTERN}")

if(NOT MATCHED_FILES)
	message(STATUS "No files matched ${SRC_DIR}/${PATTERN}; skipping runtime dependency copy")
	return()
endif()

foreach(f IN LISTS MATCHED_FILES)
	if(IS_DIRECTORY "${f}")
		continue()
	endif()
	execute_process(
		COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${f}" "${DST_DIR}/"
		RESULT_VARIABLE copy_result
	)
	if(NOT copy_result EQUAL 0)
		message(FATAL_ERROR "Failed copying file ${f} to ${DST_DIR}")
	endif()
endforeach()

