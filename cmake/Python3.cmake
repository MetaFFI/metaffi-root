include(${CMAKE_CURRENT_LIST_DIR}/Utils.cmake)

if(WIN32)
	get_app_path("py" PYTHON_EXECUTABLE)
	set(PYTHON_EXECUTABLE_ARG "-3.11")
else()
	get_app_path("python3.11" PYTHON_EXECUTABLE)
	set(PYTHON_EXECUTABLE_ARG "")
endif()


macro(add_py_test NAME)
	cmake_parse_arguments("add_py_test"
			"" # bool vals
			"WORKING_DIRECTORY" # single val
			"" # multi-vals
			${ARGN})

	cmake_parse_arguments("add_py_test"
			"" # bool vals
			"" # single val
			"DEPENDENCIES" # multi-vals
			${ARGN})

	if(WIN32)
		set(PYEXECNAME "py")
		get_app_path(${PYEXECNAME} PYEXECFULLPATH)
	else()
		set(PYEXECFULLPATH "/usr/bin/python3.11")
	endif()

	message(STATUS "Python executable: ${PYEXECFULLPATH}")


	if("${add_py_test_WORKING_DIRECTORY}" STREQUAL "")
		set(add_go_test_WORKING_DIRECTORY .)
	endif()

	if(NOT "${add_py_test_DEPENDENCIES}" STREQUAL "")
		foreach(DEP ${add_py_test_DEPENDENCIES})
			execute_process(COMMAND ${PYEXECFULLPATH} -m pip install ${DEP} --upgrade)
		endforeach()
	endif()



	if(EXISTS ${PYEXECFULLPATH})
		add_test(NAME "(python3 test) ${NAME}"
				COMMAND ${PYEXECFULLPATH} -m unittest ${NAME}
				WORKING_DIRECTORY ${add_py_test_WORKING_DIRECTORY})
	else()
		message(WARNING "Python executable not found at ${PYEXECFULLPATH}. Test ${NAME} not added.")
	endif()
endmacro()