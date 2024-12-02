find_package(Java REQUIRED)
find_package(JNI REQUIRED)
include(UseJava)

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

  # Prepare the source files list
  file(GLOB_RECURSE JAVA_SOURCES ${BUILD_JAR_SOURCES})

  if(NOT JAVA_SOURCES)
    message(FATAL_ERROR "build_jar: No Java source files found in specified SOURCES")
  endif()

  # Set up the JAR output directory and output path
  set(JAR_OUTPUT_DIR $ENV{METAFFI_HOME}/${BUILD_JAR_OUTPUT_DIR})
  set(JAR_OUTPUT_NAME ${BUILD_JAR_OUTPUT_NAME})

  # Create the output directory
  file(MAKE_DIRECTORY ${JAR_OUTPUT_DIR})

  # Create the target JAR
  add_jar(${TARGET_NAME}
          SOURCES ${JAVA_SOURCES}
          OUTPUT_NAME ${JAR_OUTPUT_NAME}
          OUTPUT_DIR ${JAR_OUTPUT_DIR}
          INCLUDE_JARS ${BUILD_JAR_INCLUDE_JARS}
  )

  # Display a message to indicate where the JAR is created
  message(STATUS "Building JAR for target ${TARGET_NAME} at ${JAR_OUTPUT_DIR}/${JAR_OUTPUT_NAME}.jar")
endmacro()
