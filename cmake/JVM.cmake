find_package(Java REQUIRED)
find_package(JNI REQUIRED)
include(UseJava)

if(NOT DEFINED METAFFI_JAVA_RELEASE)
	set(METAFFI_JAVA_RELEASE 11)
endif()

macro(build_jar TARGET_NAME)
	# Parse arguments
	set(options)
	set(one_value_args OUTPUT_DIR OUTPUT_NAME)
	set(multi_value_args SOURCES INCLUDE_JARS)
	cmake_parse_arguments(BUILD_JAR "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

	# Ensure required parameters are set
	if(NOT BUILD_JAR_SOURCES)
		message(FATAL_ERROR "build_jar: SOURCES parameter is required")
	endif()
	if(NOT BUILD_JAR_OUTPUT_DIR)
		message(FATAL_ERROR "build_jar: OUTPUT_DIR parameter is required")
	endif()
	if(NOT BUILD_JAR_OUTPUT_NAME)
		message(FATAL_ERROR "build_jar: OUTPUT_NAME parameter is required")
	endif()

	# Prepare the source files list (at configure time, but only for validation)
	file(GLOB_RECURSE JAVA_SOURCES ${BUILD_JAR_SOURCES})

	if(NOT JAVA_SOURCES)
		message(FATAL_ERROR "build_jar: No Java source files found in specified SOURCES")
	endif()

	# Set up the JAR output directory and output path
	if(IS_ABSOLUTE "${BUILD_JAR_OUTPUT_DIR}")
		set(JAR_OUTPUT_DIR ${BUILD_JAR_OUTPUT_DIR})
	else()
		set(JAR_OUTPUT_DIR $ENV{METAFFI_HOME}/${BUILD_JAR_OUTPUT_DIR})
	endif()
	set(JAR_OUTPUT_NAME ${BUILD_JAR_OUTPUT_NAME})
	set(JAR_OUTPUT_PATH ${JAR_OUTPUT_DIR}/${JAR_OUTPUT_NAME}.jar)

	# Create temporary directory for compiled classes (at build time)
	set(CLASSES_DIR ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}_classes)

	# Build classpath from INCLUDE_JARS for compilation
	set(CLASSPATH "")
	if(BUILD_JAR_INCLUDE_JARS)
		# Join list with platform-appropriate separator into a single string
		if(WIN32)
			string(JOIN ";" CLASSPATH ${BUILD_JAR_INCLUDE_JARS})
		else()
			string(JOIN ":" CLASSPATH ${BUILD_JAR_INCLUDE_JARS})
		endif()
	endif()

	# Compile Java sources to classes directory (at build time)
	# Use separate COMMAND entries to ensure classpath is passed correctly
	if(CLASSPATH)
		# Escape semicolons in classpath for Windows (use backslash-escape or double quotes)
		# On Windows, we need to ensure the classpath string is properly quoted
		if(WIN32)
			# Replace semicolons with escaped semicolons or use a different approach
			# Actually, we'll pass it as a single argument by using COMMAND with explicit quoting
			add_custom_command(
				OUTPUT ${CLASSES_DIR}/.compiled
				COMMAND ${CMAKE_COMMAND} -E make_directory ${CLASSES_DIR}
				COMMAND ${Java_JAVAC_EXECUTABLE} --release ${METAFFI_JAVA_RELEASE} -cp "${CLASSPATH}" -d "${CLASSES_DIR}" ${JAVA_SOURCES}
				COMMAND ${CMAKE_COMMAND} -E touch ${CLASSES_DIR}/.compiled
				DEPENDS ${JAVA_SOURCES}
				WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
				COMMENT "Compiling Java sources for ${TARGET_NAME}"
			)
		else()
			add_custom_command(
				OUTPUT ${CLASSES_DIR}/.compiled
				COMMAND ${CMAKE_COMMAND} -E make_directory ${CLASSES_DIR}
				COMMAND ${Java_JAVAC_EXECUTABLE} --release ${METAFFI_JAVA_RELEASE} -cp "${CLASSPATH}" -d "${CLASSES_DIR}" ${JAVA_SOURCES}
				COMMAND ${CMAKE_COMMAND} -E touch ${CLASSES_DIR}/.compiled
				DEPENDS ${JAVA_SOURCES}
				WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
				COMMENT "Compiling Java sources for ${TARGET_NAME}"
			)
		endif()
	else()
		add_custom_command(
			OUTPUT ${CLASSES_DIR}/.compiled
			COMMAND ${CMAKE_COMMAND} -E make_directory ${CLASSES_DIR}
			COMMAND ${Java_JAVAC_EXECUTABLE} --release ${METAFFI_JAVA_RELEASE} -d "${CLASSES_DIR}" ${JAVA_SOURCES}
			COMMAND ${CMAKE_COMMAND} -E touch ${CLASSES_DIR}/.compiled
			DEPENDS ${JAVA_SOURCES}
			WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
			COMMENT "Compiling Java sources for ${TARGET_NAME}"
		)
	endif()

	# Create JAR from compiled classes and include external JARs (at build time)
	# First create the JAR with compiled classes, then update it with INCLUDE_JARS
	if(BUILD_JAR_INCLUDE_JARS)
		# Create JAR with classes, then update with external JARs
		add_custom_command(
			OUTPUT ${JAR_OUTPUT_PATH}
			COMMAND ${CMAKE_COMMAND} -E make_directory ${JAR_OUTPUT_DIR}
			COMMAND ${Java_JAR_EXECUTABLE} cf ${JAR_OUTPUT_PATH} -C ${CLASSES_DIR} .
			COMMAND ${Java_JAR_EXECUTABLE} uf ${JAR_OUTPUT_PATH} ${BUILD_JAR_INCLUDE_JARS}
			DEPENDS ${CLASSES_DIR}/.compiled ${BUILD_JAR_INCLUDE_JARS}
			WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
			COMMENT "Creating JAR ${JAR_OUTPUT_NAME}.jar with included JARs"
		)
	else()
		# Create JAR with classes only
		add_custom_command(
			OUTPUT ${JAR_OUTPUT_PATH}
			COMMAND ${CMAKE_COMMAND} -E make_directory ${JAR_OUTPUT_DIR}
			COMMAND ${Java_JAR_EXECUTABLE} cf ${JAR_OUTPUT_PATH} -C ${CLASSES_DIR} .
			DEPENDS ${CLASSES_DIR}/.compiled
			WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
			COMMENT "Creating JAR ${JAR_OUTPUT_NAME}.jar"
		)
	endif()

	# Create target that depends on JAR (builds at build time)
	add_custom_target(${TARGET_NAME}
		DEPENDS ${JAR_OUTPUT_PATH}
	)

	# Display a message to indicate where the JAR will be created
	message(STATUS "JAR target ${TARGET_NAME} will be built at ${JAR_OUTPUT_PATH}")

	# Set the EXCLUDE_FROM_DEFAULT_BUILD property
	set_target_properties(${TARGET_NAME} PROPERTIES EXCLUDE_FROM_DEFAULT_BUILD TRUE)
endmacro()

#-----------------------------------------------------------------------------------------------
# Compiles Java classes
# Usage: compile_java(TARGET_NAME SOURCES OUTPUT_DIR [CLASSPATH "path"] [DEPENDS ...] [COMMENT "message"])
macro(compile_java TARGET_NAME)
	# Parse arguments
	set(options)
	set(one_value_args OUTPUT_DIR COMMENT)
	set(multi_value_args SOURCES CLASSPATH DEPENDS)
	cmake_parse_arguments(COMPILE_JAVA "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

	# Ensure required parameters are set
	if(NOT COMPILE_JAVA_SOURCES)
		message(FATAL_ERROR "compile_java: SOURCES parameter is required")
	endif()
	if(NOT COMPILE_JAVA_OUTPUT_DIR)
		message(FATAL_ERROR "compile_java: OUTPUT_DIR parameter is required")
	endif()

	# Create output directory
	file(MAKE_DIRECTORY ${COMPILE_JAVA_OUTPUT_DIR})

	# Find Java source files - handle both glob patterns and file lists
	set(JAVA_SOURCES "")
	foreach(SOURCE_PATTERN ${COMPILE_JAVA_SOURCES})
		# Check if it's a glob pattern (contains * or ?)
		if(SOURCE_PATTERN MATCHES "[*?]")
			file(GLOB_RECURSE GLOB_SOURCES ${SOURCE_PATTERN})
			list(APPEND JAVA_SOURCES ${GLOB_SOURCES})
		else()
			# It's a direct file path
			if(EXISTS ${SOURCE_PATTERN})
				list(APPEND JAVA_SOURCES ${SOURCE_PATTERN})
			endif()
		endif()
	endforeach()

	# Set default comment if not provided
	if(NOT COMPILE_JAVA_COMMENT)
		set(COMPILE_JAVA_COMMENT "Compiling Java classes")
	endif()

	# Build javac command
	set(JAVAC_CMD ${Java_JAVAC_EXECUTABLE}
		--release ${METAFFI_JAVA_RELEASE}
	)

	# Add classpath if provided
	# Join classpath list into a single string with platform-appropriate separator
	if(COMPILE_JAVA_CLASSPATH)
		if(WIN32)
			string(JOIN ";" CLASSPATH_STR ${COMPILE_JAVA_CLASSPATH})
		else()
			string(JOIN ":" CLASSPATH_STR ${COMPILE_JAVA_CLASSPATH})
		endif()
		# Escape semicolons so CMake doesn't treat them as list separators
		string(REPLACE ";" "\;" CLASSPATH_STR_ESCAPED "${CLASSPATH_STR}")
		list(APPEND JAVAC_CMD -cp "${CLASSPATH_STR_ESCAPED}")
	endif()

	# Add output directory and sources
	list(APPEND JAVAC_CMD -d ${COMPILE_JAVA_OUTPUT_DIR})
	list(APPEND JAVAC_CMD ${JAVA_SOURCES})

	# Use target name in output marker to avoid conflicts when multiple targets use same output dir
	add_custom_command(
		OUTPUT ${COMPILE_JAVA_OUTPUT_DIR}/.${TARGET_NAME}.compiled
		COMMAND ${JAVAC_CMD}
		COMMAND ${CMAKE_COMMAND} -E touch ${COMPILE_JAVA_OUTPUT_DIR}/.${TARGET_NAME}.compiled
		DEPENDS ${JAVA_SOURCES} ${COMPILE_JAVA_DEPENDS}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		COMMENT ${COMPILE_JAVA_COMMENT}
		VERBATIM
	)

	add_custom_target(${TARGET_NAME}
		DEPENDS ${COMPILE_JAVA_OUTPUT_DIR}/.${TARGET_NAME}.compiled
	)

endmacro()
#-----------------------------------------------------------------------------------------------
# Runs JUnit tests and adds to CTest
# Usage: add_junit_test(TARGET_NAME TEST_CLASSES CLASSPATH OUTPUT_DIR [DEPENDS ...] [COMMENT "message"])
macro(add_junit_test TARGET_NAME)
	# Parse arguments
	set(options)
	set(one_value_args OUTPUT_DIR COMMENT)
	set(multi_value_args TEST_CLASSES CLASSPATH DEPENDS)
	cmake_parse_arguments(ADD_JUNIT "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

	# Ensure required parameters are set
	if(NOT ADD_JUNIT_TEST_CLASSES)
		message(FATAL_ERROR "add_junit_test: TEST_CLASSES parameter is required")
	endif()
	if(NOT ADD_JUNIT_CLASSPATH)
		message(FATAL_ERROR "add_junit_test: CLASSPATH parameter is required")
	endif()
	if(NOT ADD_JUNIT_OUTPUT_DIR)
		message(FATAL_ERROR "add_junit_test: OUTPUT_DIR parameter is required")
	endif()

	# Set default comment if not provided
	if(NOT ADD_JUNIT_COMMENT)
		set(ADD_JUNIT_COMMENT "Running JUnit tests")
	endif()

	# Join classpath list into a single string with platform-appropriate separator
	if(WIN32)
		string(JOIN ";" CLASSPATH_STR ${ADD_JUNIT_CLASSPATH})
	else()
		string(JOIN ":" CLASSPATH_STR ${ADD_JUNIT_CLASSPATH})
	endif()

	# Create output directory if needed (at configure time for CTest)
	file(MAKE_DIRECTORY ${ADD_JUNIT_OUTPUT_DIR})

	# Add test to CTest so it can be run via ctest
	# Pass COMMAND arguments directly instead of using a list variable
	# Set testdata.classes.dir system property to point to the build output directory
	add_test(
		NAME "(junit test) ${TARGET_NAME}"
		COMMAND ${Java_JAVA_EXECUTABLE} -Dtestdata.classes.dir=${CMAKE_CURRENT_BINARY_DIR}/test/com/metaffi/idl/testdata -cp "${CLASSPATH_STR}" org.junit.runner.JUnitCore ${ADD_JUNIT_TEST_CLASSES}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	)

	# Set test properties and dependencies
	set_tests_properties("(junit test) ${TARGET_NAME}" PROPERTIES
		LABELS "junit"
	)
	
	# Set test dependencies if provided
	if(ADD_JUNIT_DEPENDS)
		set_tests_properties("(junit test) ${TARGET_NAME}" PROPERTIES
			DEPENDS "${ADD_JUNIT_DEPENDS}"
		)
	endif()

	# Create custom command to run tests (for build-time execution)
	add_custom_command(
		OUTPUT ${ADD_JUNIT_OUTPUT_DIR}/.tests_run
		COMMAND ${Java_JAVA_EXECUTABLE} -Dtestdata.classes.dir=${CMAKE_CURRENT_BINARY_DIR}/test/com/metaffi/idl/testdata -cp "${CLASSPATH_STR}" org.junit.runner.JUnitCore ${ADD_JUNIT_TEST_CLASSES}
		DEPENDS ${ADD_JUNIT_DEPENDS}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		COMMENT ${ADD_JUNIT_COMMENT}
	)

	# Create target that depends on the test run marker (for build-time execution)
	add_custom_target(${TARGET_NAME}_build
		DEPENDS ${ADD_JUNIT_OUTPUT_DIR}/.tests_run
	)

endmacro()
#-----------------------------------------------------------------------------------------------
#
# Runs a Java main-class test and adds to CTest
# Usage: add_java_main_test(TARGET_NAME TEST_CLASS CLASSPATH OUTPUT_DIR [WORKING_DIRECTORY dir] [DEPENDS ...] [COMMENT "message"])
macro(add_java_main_test TARGET_NAME)
	# Parse arguments
	set(options)
	set(one_value_args TEST_CLASS OUTPUT_DIR COMMENT WORKING_DIRECTORY)
	set(multi_value_args CLASSPATH DEPENDS)
	cmake_parse_arguments(ADD_JAVA_MAIN "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

	# Ensure required parameters are set
	if(NOT ADD_JAVA_MAIN_TEST_CLASS)
		message(FATAL_ERROR "add_java_main_test: TEST_CLASS parameter is required")
	endif()
	if(NOT ADD_JAVA_MAIN_CLASSPATH)
		message(FATAL_ERROR "add_java_main_test: CLASSPATH parameter is required")
	endif()
	if(NOT ADD_JAVA_MAIN_OUTPUT_DIR)
		message(FATAL_ERROR "add_java_main_test: OUTPUT_DIR parameter is required")
	endif()

	# Set default comment if not provided
	if(NOT ADD_JAVA_MAIN_COMMENT)
		set(ADD_JAVA_MAIN_COMMENT "Running Java main-class tests")
	endif()

	# Join classpath list into a single string with platform-appropriate separator
	if(WIN32)
		string(JOIN ";" CLASSPATH_STR ${ADD_JAVA_MAIN_CLASSPATH})
	else()
		string(JOIN ":" CLASSPATH_STR ${ADD_JAVA_MAIN_CLASSPATH})
	endif()

	# Create output directory if needed
	file(MAKE_DIRECTORY ${ADD_JAVA_MAIN_OUTPUT_DIR})

	# Set working directory if provided
	if(ADD_JAVA_MAIN_WORKING_DIRECTORY)
		set(JAVA_MAIN_WORKDIR ${ADD_JAVA_MAIN_WORKING_DIRECTORY})
	else()
		set(JAVA_MAIN_WORKDIR ${CMAKE_CURRENT_SOURCE_DIR})
	endif()

	# Add test to CTest
	add_test(
		NAME "(java main test) ${TARGET_NAME}"
		COMMAND ${Java_JAVA_EXECUTABLE} -cp "${CLASSPATH_STR}" ${ADD_JAVA_MAIN_TEST_CLASS}
		WORKING_DIRECTORY ${JAVA_MAIN_WORKDIR}
	)

	set_tests_properties("(java main test) ${TARGET_NAME}" PROPERTIES
		LABELS "java"
	)

	# Set test dependencies if provided
	if(ADD_JAVA_MAIN_DEPENDS)
		set_tests_properties("(java main test) ${TARGET_NAME}" PROPERTIES
			DEPENDS "${ADD_JAVA_MAIN_DEPENDS}"
		)
	endif()

	# Create custom command to run tests (for build-time execution)
	add_custom_command(
		OUTPUT ${ADD_JAVA_MAIN_OUTPUT_DIR}/.tests_run
		COMMAND ${Java_JAVA_EXECUTABLE} -cp "${CLASSPATH_STR}" ${ADD_JAVA_MAIN_TEST_CLASS}
		DEPENDS ${ADD_JAVA_MAIN_DEPENDS}
		WORKING_DIRECTORY ${JAVA_MAIN_WORKDIR}
		COMMENT ${ADD_JAVA_MAIN_COMMENT}
	)

	# Create target that depends on the test run marker (for build-time execution)
	add_custom_target(${TARGET_NAME}_build
		DEPENDS ${ADD_JAVA_MAIN_OUTPUT_DIR}/.tests_run
	)

endmacro()
#-----------------------------------------------------------------------------------------------
