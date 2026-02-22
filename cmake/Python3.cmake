include(${CMAKE_CURRENT_LIST_DIR}/Utils.cmake)

macro(get_python311_exec OUT_VAR)
	if(WIN32)
		find_program(_metaffi_python_exec NAMES python3.11.exe python3.exe python.exe python)
	else()
		find_program(_metaffi_python_exec NAMES python3.11 python3 python)
	endif()

	if(NOT _metaffi_python_exec)
		message(FATAL_ERROR "Python executable not found (expected Python 3.11 on PATH).")
	endif()

	set(${OUT_VAR} "${_metaffi_python_exec}")
endmacro()

get_python311_exec(PYTHON_EXECUTABLE)
set(PYTHON_EXECUTABLE_ARG "")


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

	get_python311_exec(PYEXECFULLPATH)

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
