include(${CMAKE_CURRENT_LIST_DIR}/Utils.cmake)
get_app_path("go" GOEXEC)

macro(add_go_target NAME)
	add_custom_target(${NAME} ALL)
endmacro()

function(go_get TARGET)
	cmake_parse_arguments("add_go"
			"" # bool vals
			"WORKING_DIRECTORY" # single val
			"" # multi-vals
			${ARGN})

	if("${add_go_test_WORKING_DIRECTORY}" STREQUAL "")
		set(add_go_test_WORKING_DIRECTORY ".")
	endif()
	add_custom_command(TARGET ${TARGET}
			WORKING_DIRECTORY ${add_go_WORKING_DIRECTORY}
			COMMAND ${GOEXEC} get -v -u -t
			COMMENT "Running \"go get\" for target ${target_name}"
			USES_TERMINAL )
endfunction()

macro(go_build TARGET)
	set(options)
	set(one_value_args OUTPUT_DIR OUTPUT_NAME)
	set(multi_value_args SOURCE_DIR DEPENDENT)
	cmake_parse_arguments(GO_BUILD "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

	if(NOT GO_BUILD_OUTPUT_DIR)
		message(FATAL_ERROR "go_build: OUTPUT_DIR parameter is required")
	endif()
	if(NOT GO_BUILD_OUTPUT_NAME)
		message(FATAL_ERROR "go_build: OUTPUT_NAME parameter is required")
	endif()
	if(NOT GO_BUILD_SOURCE_DIR)
		message(FATAL_ERROR "go_build: SOURCE_DIR parameter is required")
	endif()

	# Gather all *.go files in the DEPENDENT directories
	set(GO_DEPENDENT_FILES)
	foreach(DEPENDENT_DIR ${GO_BUILD_DEPENDENT})
		file(GLOB_RECURSE GO_FILES "${DEPENDENT_DIR}/*.go")
		list(APPEND GO_DEPENDENT_FILES ${GO_FILES})
	endforeach()

	add_custom_command(
			OUTPUT $ENV{METAFFI_HOME}/${GO_BUILD_OUTPUT_DIR}/${GO_BUILD_OUTPUT_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}
			COMMAND ${GOEXEC} build -buildmode=c-shared -gcflags=-shared -o $ENV{METAFFI_HOME}/${GO_BUILD_OUTPUT_DIR}/${GO_BUILD_OUTPUT_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}
			WORKING_DIRECTORY ${GO_BUILD_SOURCE_DIR}
			DEPENDS ${GO_DEPENDENT_FILES}
			COMMENT "Building go C-Shared dynamic library for target ${TARGET} to $ENV{METAFFI_HOME}/${GO_BUILD_OUTPUT_DIR}/${GO_BUILD_OUTPUT_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}"
			USES_TERMINAL
	)

	add_custom_target(${TARGET} ALL
			DEPENDS $ENV{METAFFI_HOME}/${GO_BUILD_OUTPUT_DIR}/${GO_BUILD_OUTPUT_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}
	)
endmacro()

# Add "go test" for the Target
macro(add_go_test NAME)
	cmake_parse_arguments("add_go_test"
			"" # bool vals
			"WORKING_DIRECTORY" # single val
			"" # multi-vals
			${ARGN})

	if("${add_go_test_WORKING_DIRECTORY}" STREQUAL "")
		set(add_go_test_WORKING_DIRECTORY .)
	endif()

	add_test(NAME "(go test) ${NAME}"
			COMMAND ${GOEXEC} test -v
			WORKING_DIRECTORY ${add_go_test_WORKING_DIRECTORY})
endmacro()
