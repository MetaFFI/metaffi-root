# PackageManagement.cmake

# add_vcpkg macro
macro(add_vcpkg_integration)
	set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
	find_program(VCPKG_EXECUTABLE vcpkg)
	if(NOT VCPKG_EXECUTABLE)
		message(FATAL_ERROR "vcpkg not found")
	endif()
endmacro()

macro(find_or_install_package package)
	find_package(${package} QUIET ${ARGN})
	if(NOT ${package}_FOUND)

		# find program vcpkg
		find_program(VCPKG_EXECUTABLE vcpkg)

		execute_process(COMMAND ${VCPKG_EXECUTABLE} install ${package}
				RESULT_VARIABLE exit_code)
		if(exit_code)
			message(FATAL_ERROR "Failed to install ${package}")
		endif()
		find_package(${package} REQUIRED ${ARGN})
	endif()
endmacro()