# PackageManagement.cmake

# add_vcpkg macro
macro(add_vcpkg_integration)
	# Only set toolchain file if not already set
	if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
		set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
	endif()
	find_program(VCPKG_EXECUTABLE vcpkg)
	if(NOT VCPKG_EXECUTABLE)
		message(FATAL_ERROR "vcpkg not found")
	endif()

	set(VCPKG_LIBRARY_LINKAGE dynamic)  # Force shared library installation

	set(Boost_USE_STATIC_LIBS OFF)
	set(Boost_USE_STATIC_RUNTIME OFF)
endmacro()

macro(find_or_install_package package)
	find_package(${package} ${ARGN})

	if(NOT ${package}_FOUND)
		# find program vcpkg
		find_program(VCPKG_EXECUTABLE vcpkg)

		execute_process(COMMAND ${VCPKG_EXECUTABLE} install ${package}:x64-windows
				RESULT_VARIABLE exit_code)
		if(exit_code)
			message(FATAL_ERROR "Failed to install ${package}")
		endif()

		find_package(${package} REQUIRED ${ARGN})
	endif()
endmacro()