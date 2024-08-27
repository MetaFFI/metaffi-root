from SCons.Script import Alias  # type: ignore

# ! --- define aliases ---
ALIAS_BUILD = 'build' # builds the MetaFFI projects

ALIAS_CORE = 'core' # builds the MetaFFI core project
ALIAS_CORE_UNITTESTS = 'core-unittests' # runs the MetaFFI core project tests

ALIAS_PYTHON3 = 'python3' # builds the Python3 language plugin
ALIAS_PYTHON3_UNITTESTS = 'python3-unittests' # runs the Python3 language plugin tests
ALIAS_PYTHON3_API_TESTS = 'python3-api-tests' # runs the Python3 language plugin cross-language tests
ALIAS_PYTHON3_PUBLISH_API = 'python3-publish-api' # publishes the Python3 language plugin to PyPI
ALIAS_PYTHON3_ALL = 'python3-all' # builds the Python3 language plugin and runs all tests

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
Alias(ALIAS_PYTHON3, [])
Alias(ALIAS_PYTHON3_UNITTESTS, [])
Alias(ALIAS_PYTHON3_API_TESTS, [])
Alias(ALIAS_PYTHON3_PUBLISH_API, [])
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
