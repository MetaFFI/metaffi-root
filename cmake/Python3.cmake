include(${CMAKE_CURRENT_LIST_DIR}/Utils.cmake)

if(WIN32)
	set(PYTHON_EXECUTABLE "$ENV{LOCALAPPDATA}/Programs/Python/Python311/python3.exe")
	set(PYTHON_EXECUTABLE_ARG "")
else()
	set(PYTHON_EXECUTABLE "/usr/bin/python3.11")
	set(PYTHON_EXECUTABLE_ARG "")
endif()


macro(add_py_test NAME)
	cmake_parse_arguments("add_py_test"
			"" # bool vals
			"WORKING_DIRECTORY;MODULE" # single val
			"" # multi-vals
			${ARGN})

	cmake_parse_arguments("add_py_test"
			"" # bool vals
			"" # single val
			"DEPENDENCIES" # multi-vals
			${ARGN})

	if(WIN32)
		set(PYEXECFULLPATH "$ENV{LOCALAPPDATA}/Programs/Python/Python311/python3.exe")
	else()
		set(PYEXECFULLPATH "/usr/bin/python3.11")
	endif()

	message(STATUS "Python executable: ${PYEXECFULLPATH}")


	if("${add_py_test_WORKING_DIRECTORY}" STREQUAL "")
		set(add_py_test_WORKING_DIRECTORY .)
	endif()

	if(add_py_test_MODULE)
		set(_py_test_module ${add_py_test_MODULE})
	else()
		set(_py_test_module ${NAME})
	endif()

	if(NOT "${add_py_test_DEPENDENCIES}" STREQUAL "")
		foreach(DEP ${add_py_test_DEPENDENCIES})
			execute_process(COMMAND ${PYEXECFULLPATH} -m pip install ${DEP} --upgrade)
		endforeach()
	endif()



	if(EXISTS ${PYEXECFULLPATH})
		add_test(NAME "(python3 test) ${NAME}"
				COMMAND ${PYEXECFULLPATH} -m unittest ${_py_test_module}
				WORKING_DIRECTORY ${add_py_test_WORKING_DIRECTORY})
	else()
		message(WARNING "Python executable not found at ${PYEXECFULLPATH}. Test ${NAME} not added.")
	endif()
endmacro()