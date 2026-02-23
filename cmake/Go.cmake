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

# OUTPUT_TYPE: "shared" (default) or "executable". Optional PACKAGE (e.g. ./cmd/foo). Builds from SOURCE_DIR.
macro(go_build TARGET)
	set(one_value_args OUTPUT_DIR OUTPUT_NAME OUTPUT_TYPE PACKAGE)
	set(multi_value_args SOURCE_DIR DEPENDENT)
	cmake_parse_arguments(GO_BUILD "" "${one_value_args}" "SOURCE_DIR;DEPENDENT" ${ARGN})

	if(NOT GO_BUILD_OUTPUT_DIR OR NOT GO_BUILD_OUTPUT_NAME OR NOT GO_BUILD_SOURCE_DIR)
		message(FATAL_ERROR "go_build: OUTPUT_DIR, OUTPUT_NAME, SOURCE_DIR required")
	endif()
	if(NOT GO_BUILD_OUTPUT_TYPE)
		set(GO_BUILD_OUTPUT_TYPE "shared")
	endif()

	set(GO_DEPENDENT_FILES)
	foreach(DEPENDENT_DIR ${GO_BUILD_DEPENDENT})
		file(GLOB_RECURSE GO_FILES "${DEPENDENT_DIR}/*.go")
		list(APPEND GO_DEPENDENT_FILES ${GO_FILES})
	endforeach()

	if(GO_BUILD_OUTPUT_TYPE STREQUAL "executable")
		if(IS_ABSOLUTE "${GO_BUILD_OUTPUT_DIR}")
			set(GO_BUILD_OUTPUT_PATH "${GO_BUILD_OUTPUT_DIR}/${GO_BUILD_OUTPUT_NAME}${CMAKE_EXECUTABLE_SUFFIX}")
		else()
			set(GO_BUILD_OUTPUT_PATH "$ENV{METAFFI_HOME}/${GO_BUILD_OUTPUT_DIR}/${GO_BUILD_OUTPUT_NAME}${CMAKE_EXECUTABLE_SUFFIX}")
		endif()
		if(GO_BUILD_PACKAGE)
			set(GO_BUILD_CMD COMMAND ${GOEXEC} build -o ${GO_BUILD_OUTPUT_PATH} ${GO_BUILD_PACKAGE})
		else()
			set(GO_BUILD_CMD COMMAND ${GOEXEC} build -o ${GO_BUILD_OUTPUT_PATH})
		endif()
	else()
		if(IS_ABSOLUTE "${GO_BUILD_OUTPUT_DIR}")
			set(GO_BUILD_OUTPUT_PATH "${GO_BUILD_OUTPUT_DIR}/${GO_BUILD_OUTPUT_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}")
		else()
			set(GO_BUILD_OUTPUT_PATH "$ENV{METAFFI_HOME}/${GO_BUILD_OUTPUT_DIR}/${GO_BUILD_OUTPUT_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}")
		endif()
		# c-shared requires exactly one main package; must specify PACKAGE (e.g. ./cmd/compiler_go_lib)
		if(GO_BUILD_PACKAGE)
			set(GO_BUILD_CMD COMMAND ${GOEXEC} build -buildmode=c-shared -gcflags=-shared -o ${GO_BUILD_OUTPUT_PATH} ${GO_BUILD_PACKAGE})
		else()
			set(GO_BUILD_CMD COMMAND ${GOEXEC} build -buildmode=c-shared -gcflags=-shared -o ${GO_BUILD_OUTPUT_PATH} .)
		endif()
	endif()
	get_filename_component(GO_BUILD_OUTPUT_DIR_PATH "${GO_BUILD_OUTPUT_PATH}" DIRECTORY)

	add_custom_command(
		OUTPUT ${GO_BUILD_OUTPUT_PATH}
		COMMAND ${CMAKE_COMMAND} -E make_directory ${GO_BUILD_OUTPUT_DIR_PATH}
		${GO_BUILD_CMD}
		WORKING_DIRECTORY ${GO_BUILD_SOURCE_DIR}
		DEPENDS ${GO_DEPENDENT_FILES}
		COMMENT "Building Go (${GO_BUILD_OUTPUT_TYPE}) for ${TARGET}"
		USES_TERMINAL
	)
	add_custom_target(${TARGET} ALL DEPENDS ${GO_BUILD_OUTPUT_PATH})
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

	# Go CGO tests include headers/sources from METAFFI_HOME/include and sdk headers.
	# Make these include roots available by default for all go test invocations.
	set(_go_test_cgo_flags "-I$ENV{METAFFI_HOME} -I$ENV{METAFFI_HOME}/include -I$ENV{METAFFI_SOURCE_ROOT}/sdk")
	if(NOT "$ENV{CGO_CFLAGS}" STREQUAL "")
		set(_go_test_cgo_flags "${_go_test_cgo_flags} $ENV{CGO_CFLAGS}")
	endif()
	if(NOT "$ENV{CGO_CPPFLAGS}" STREQUAL "")
		set(_go_test_cppflags "${_go_test_cgo_flags} $ENV{CGO_CPPFLAGS}")
	else()
		set(_go_test_cppflags "${_go_test_cgo_flags}")
	endif()

	if(WIN32)
		set(_go_test_path "$ENV{METAFFI_HOME};$ENV{PATH}")
	else()
		set(_go_test_path "$ENV{METAFFI_HOME}:$ENV{PATH}")
	endif()

	add_test(NAME "(go test) ${NAME}"
			COMMAND ${CMAKE_COMMAND} -E env
			"PATH=${_go_test_path}"
			"CGO_CFLAGS=${_go_test_cgo_flags}"
			"CGO_CPPFLAGS=${_go_test_cppflags}"
			${GOEXEC} test -v
			WORKING_DIRECTORY ${add_go_test_WORKING_DIRECTORY})
endmacro()
