include(FetchContent)

# verifies the path exists, if not, clones the repository
macro(verify_project_exists path url)
	if(NOT EXISTS ${path})
		message(STATUS "${path} does not exist. Cloning from ${url} branch 'main'...")

		# Clone the repository
		execute_process(
				COMMAND git clone --recurse-submodules --branch main ${url} ${path}
				RESULT_VARIABLE result
				OUTPUT_VARIABLE output
				ERROR_VARIABLE error
		)

		if(result)
			message(FATAL_ERROR "Failed to clone repository: ${error}")
		else()
			message(STATUS "Cloning completed successfully.")
		endif()
	endif()
endmacro()
