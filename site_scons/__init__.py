from SCons.Script import Alias  # type: ignore

# ! --- define aliases ---
ALIAS_BUILD = 'build' # builds the MetaFFI projects

ALIAS_CORE = 'core' # builds the MetaFFI core project
ALIAS_CORE_UNITTESTS = 'core-unittests' # runs the MetaFFI core project tests

ALIAS_C = 'c' # builds the Go language plugin
ALIAS_C_UNITTESTS = 'c-unittests' # runs the Go language plugin tests
ALIAS_C_API_TESTS = 'c-api-tests' # runs the Go language plugin cross-language tests
ALIAS_c_ALL = 'c-all' # builds the Go language plugin and runs all tests

ALIAS_PYTHON311 = 'python311' # builds the Python3 language plugin
ALIAS_PYTHON311_UNITTESTS = 'python311-unittests' # runs the Python3 language plugin tests
ALIAS_PYTHON311_API_TESTS = 'python311-api-tests' # runs the Python3 language plugin cross-language tests
ALIAS_PYTHON311_PUBLISH_API = 'python311-publish-api' # publishes the Python3 language plugin to PyPI
ALIAS_PYTHON311_ALL = 'python311-all' # builds the Python3 language plugin and runs all tests

ALIAS_PYTHON312 = 'python312' # builds the Python3 language plugin
ALIAS_PYTHON312_UNITTESTS = 'python312-unittests' # runs the Python3 language plugin tests
ALIAS_PYTHON312_API_TESTS = 'python312-api-tests' # runs the Python3 language plugin cross-language tests
ALIAS_PYTHON312_PUBLISH_API = 'python312-publish-api' # publishes the Python3 language plugin to PyPI
ALIAS_PYTHON312_ALL = 'python312-all' # builds the Python3 language plugin and runs all tests

ALIAS_GO = 'go' # builds the Go language plugin
ALIAS_GO_UNITTESTS = 'go-unittests' # runs the Go language plugin tests
ALIAS_GO_API_TESTS = 'go-api-tests' # runs the Go language plugin cross-language tests
ALIAS_GO_ALL = 'go-all' # builds the Go language plugin and runs all tests

ALIAS_OPENJDK = 'openjdk' # builds the OpenJDK language plugin
ALIAS_OPENJDK_UNITTESTS = 'openjdk-unittests' # runs the OpenJDK language plugin tests
ALIAS_OPENJDK_API_TESTS = 'openjdk-api-tests' # runs the OpenJDK language plugin cross-language tests
ALIAS_OPENJDK_ALL = 'openjdk-all' # builds the OpenJDK language plugin and runs all tests

ALIAS_UNITTESTS = 'unittests' # runs all unittests
ALIAS_API_TESTS = 'api-tests' # runs all cross-language tests
ALIAS_ALL_TESTS = 'all-tests' # runs all unittests and cross-language tests

ALIAS_BUILD_INSTALLER = 'build-installer' # builds the MetaFFI installer project

ALIAS_BUILD_AND_TEST = 'build-and-test' # builds all projects and runs all tests

ALIAS_BUILD_CONTAINER_U2204 = 'build-container-u2204' # builds the Ubuntu 20.04 container
ALIAS_BUILD_CONTAINER_WIN_S2022_CORE = 'build-container-win-server-core-2022' # builds the Windows Server Nano 2022 container

ALIAS_BUILD_ALL_CONTAINERS = 'build-all-containers' # builds all containers

Alias(ALIAS_BUILD, [])
Alias(ALIAS_CORE, [])
Alias(ALIAS_CORE_UNITTESTS, [])
Alias(ALIAS_PYTHON311, [])
Alias(ALIAS_PYTHON311_UNITTESTS, [])
Alias(ALIAS_PYTHON311_API_TESTS, [])
Alias(ALIAS_PYTHON311_PUBLISH_API, [])
Alias(ALIAS_PYTHON312, [])
Alias(ALIAS_PYTHON312_UNITTESTS, [])
Alias(ALIAS_PYTHON312_API_TESTS, [])
Alias(ALIAS_PYTHON312_PUBLISH_API, [])
Alias(ALIAS_GO, [])
Alias(ALIAS_GO_UNITTESTS, [])
Alias(ALIAS_GO_API_TESTS, [])
Alias(ALIAS_OPENJDK, [])
Alias(ALIAS_OPENJDK_UNITTESTS, [])
Alias(ALIAS_OPENJDK_API_TESTS, [])
Alias(ALIAS_UNITTESTS, [])
Alias(ALIAS_API_TESTS, [])
Alias(ALIAS_ALL_TESTS, [])
Alias(ALIAS_BUILD_INSTALLER, [])
Alias(ALIAS_BUILD_AND_TEST, [])
Alias(ALIAS_BUILD_CONTAINER_U2204, [])
Alias(ALIAS_BUILD_CONTAINER_WIN_S2022_CORE, [])
Alias(ALIAS_BUILD_ALL_CONTAINERS, [])
