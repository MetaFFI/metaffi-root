import os
from re import S
import SCons.Environment
import SCons.Script
import SCons.Node.FS
import sys

from regex import R
import environment_custom_methods
from git import Repo  # GitPython
from SCons.Script.Main import Progress
from colorama import Fore, Style, Back
import re

from site_scons import *
from site_scons.environment_custom_methods import IsWindows

# * ---- Colorize Scons output ----
class ColorizedStdoutWrapper(object):
	def __init__(self, stream):
		self.stream = stream
		self.patterns = [
			(r'^scons: \*\*\*', Fore.RED),
			(r'^scons: building terminated', Fore.RED),
			(r'^scons: done building targets.', Fore.GREEN),
			(r'^scons:', Fore.YELLOW),
			(r'^Install file:', Fore.YELLOW),
			(r'^metaffi ', Fore.CYAN),
			('Creating library', Fore.MAGENTA),
			('failed:', Fore.RED),
			('Error:', Fore.RED),
			(r'^Executing Go Test:', Fore.LIGHTBLUE_EX),
			(r'^Executing doctest:', Fore.LIGHTBLUE_EX),
			(r'^=== RUN', Fore.LIGHTBLUE_EX),
			(r'^--- PASS:', Fore.GREEN),
			(r'\[no test files\]', Fore.RED),
			(r'javac -cp', Fore.LIGHTBLUE_EX),
			(r'\.java:[0-9]+:', Fore.LIGHTRED_EX),
			(r'warning C[0-9]+:', Fore.LIGHTYELLOW_EX),
			(r'^subprocess\.CalledProcessError', Fore.RED),
			(r'error C[0-9]+:', Fore.LIGHTRED_EX),
		]

	def write(self, text):
		# Define patterns and their corresponding color codes
		
		
		# Check each pattern and apply the first matching color
		for pattern, color in self.patterns:
			if re.search(pattern, text):
				colored_text = color + text + Fore.RESET
				self.stream.write(colored_text)
				break
		else:
			# If no pattern matches, write the text as is
			self.stream.write(f'{text}')

	def flush(self):
		self.stream.flush()

# Wrap sys.stdout with the custom wrapper
sys.stdout = ColorizedStdoutWrapper(sys.stdout)
sys.stderr = ColorizedStdoutWrapper(sys.stderr)



# * ---- Set up the environment ----
env = SCons.Environment.Environment()

required_env_vars = ['LocalAppData', 'AppData', 'ProgramData', 'ProgramFiles', 'SystemRoot', 'TEMP', 'METAFFI_HOME', 'TERM', 'JAVA_HOME', 'PYTHONHOME']

for var in required_env_vars:
	if var in os.environ:
		env['ENV'][var] = os.environ[var]

env['METAFFI_HOME'] = os.environ['METAFFI_HOME']

for p in os.environ['PATH'].split(os.pathsep):
	if p not in env['ENV']['PATH']:
		env.AppendENVPath('PATH', p)

# * ---- Set custom methods and builders ----
environment_custom_methods.add_custom_methods(env)

# * ---- Make sure $METAFFI_HOME environment variable is set ----
is_found, err_msg = environment_custom_methods.verify_metaffi_home()
if not is_found:
	print(err_msg, file=sys.stderr)
	env.Exit(1)

# * ---- Make sure that all the MetaFFI projects exist. If not, clone them. ----

# ensure_project_exists: ensures that the given target_dir, and if not, if clones with submodules
# the form the given URL
def verify_project_exist(path, url) -> bool:
	if not os.path.exists(path):
		try:
			print(f'{path} does not exist. Cloning from {url} branch "main"... ', end='')
			repo = Repo.clone_from(url, path, branch='main', recursive=True)
			print(f'Done')
			return True
		except Exception as e:
			print(f'Failed with Error: {e}')
			return False
	else:
		return True


sconstruct_dir = env.Dir('#').abspath
if not verify_project_exist(sconstruct_dir + '/metaffi-core', 'https://github.com/MetaFFI/metaffi-core.git'):
	print('Failed to clone metaffi-core. Exiting...', file=sys.stderr)
	env.Exit(1)

if not verify_project_exist(sconstruct_dir + '/lang-plugin-python3',
							'https://github.com/MetaFFI/lang-plugin-python3.git'):
	print('Failed to clone lang-plugin-python3. Exiting...', file=sys.stderr)
	env.Exit(1)

if not verify_project_exist(sconstruct_dir + '/lang-plugin-go', 'https://github.com/MetaFFI/lang-plugin-go.git'):
	print('Failed to clone lang-plugin-go. Exiting...', file=sys.stderr)
	env.Exit(1)

if not verify_project_exist(sconstruct_dir + '/lang-plugin-openjdk',
							'https://github.com/MetaFFI/lang-plugin-openjdk.git'):
	print('Failed to clone lang-plugin-openjdk. Exiting...', file=sys.stderr)
	env.Exit(1)

if not verify_project_exist(sconstruct_dir + '/dev-container', 'https://github.com/MetaFFI/dev-container.git'):
	print('Failed to clone dev-container. Exiting...', file=sys.stderr)
	env.Exit(1)

if not verify_project_exist(sconstruct_dir + '/metaffi-installer', 'https://github.com/MetaFFI/metaffi-installer.git'):
	print('Failed to clone metaffi-installer. Exiting...', file=sys.stderr)
	env.Exit(1)

# * verify conan package manager exists
if not env.WhereWithError('conan'):
	print('Conan package manager is not installed. Install using "pip install conan" Exiting...', file=sys.stderr)
	env.Exit(1)

# * METAFFI_HOME will also be a global lib search path in build environment
env.setdefault('LIBPATH', []).extend([env['METAFFI_HOME'],
									 env['METAFFI_HOME'] + '/python311',
									 env['METAFFI_HOME'] + '/go',
									 env['METAFFI_HOME'] + '/openjdk'])


# * ---- set build type ----
if 'debug' in SCons.Script.COMMAND_LINE_TARGETS:
	env['BUILD_TYPE'] = 'debug'
elif 'release' in SCons.Script.COMMAND_LINE_TARGETS:
	env['BUILD_TYPE'] = 'release'
elif 'release_debug_info' in SCons.Script.COMMAND_LINE_TARGETS:
	env['BUILD_TYPE'] = 'release_debug_info'
else:
	env['BUILD_TYPE'] = 'debug'


# * --- Command line options ---

# set build type
SCons.Script.AddOption('--build-type',
					   dest='build_type',
					   type='string',
					   nargs=1,
					   action='store',
					   default='debug',
					   help='Build type (debug, release, release_debug_info)')

SCons.Script.AddOption('--print-aliases', dest='print-aliases', action='store_true', help='Shows available aliases')


# * ---- Build the MetaFFI projects ----
SCons.Script.SConscript('metaffi-core/SConscript_metaffi-core', exports='env')
SCons.Script.SConscript('lang-plugin-python3/SConscript_python3', exports='env')
SCons.Script.SConscript('lang-plugin-openjdk/SConscript_openjdk', exports='env')
SCons.Script.SConscript('lang-plugin-go/SConscript_go', exports='env')
SCons.Script.SConscript('metaffi-installer/SConscript_installer', exports='env')

SCons.Script.Alias(ALIAS_BUILD, [ALIAS_CORE, ALIAS_PYTHON3, ALIAS_OPENJDK, ALIAS_GO])
SCons.Script.Alias(ALIAS_UNITTESTS, [ALIAS_CORE_UNITTESTS, ALIAS_PYTHON3_UNITTESTS, ALIAS_OPENJDK_UNITTESTS, ALIAS_GO_UNITTESTS])
SCons.Script.Alias(ALIAS_API_TESTS, [ALIAS_PYTHON3_API_TESTS, ALIAS_GO_API_TESTS, ALIAS_OPENJDK_API_TESTS])

SCons.Script.Alias(ALIAS_BUILD_AND_TEST, [ALIAS_BUILD, ALIAS_UNITTESTS, ALIAS_API_TESTS])

SCons.Script.Alias(ALIAS_ALL_TESTS, [ALIAS_UNITTESTS, ALIAS_API_TESTS])

SCons.Script.Alias(ALIAS_PYTHON3_ALL, [ALIAS_PYTHON3, ALIAS_PYTHON3_UNITTESTS, ALIAS_PYTHON3_API_TESTS])
SCons.Script.Alias(ALIAS_GO_ALL, [ALIAS_GO, ALIAS_GO_UNITTESTS, ALIAS_GO_API_TESTS])
SCons.Script.Alias(ALIAS_OPENJDK_ALL, [ALIAS_OPENJDK, ALIAS_OPENJDK_UNITTESTS, ALIAS_OPENJDK_API_TESTS])


SCons.Script.Default(ALIAS_BUILD)


def print_aliases(env):
	aliases = [
		(ALIAS_BUILD, "Builds all MetaFFI projects", Fore.LIGHTYELLOW_EX),
		(ALIAS_CORE, "Builds MetaFFI core", Fore.LIGHTYELLOW_EX),
		(ALIAS_PYTHON3, "Builds Python3 plugin", Fore.LIGHTYELLOW_EX),
		(ALIAS_GO, "Builds Go plugin", Fore.LIGHTYELLOW_EX),
		(ALIAS_OPENJDK, "Builds OpenJDK plugin", Fore.LIGHTYELLOW_EX),
		(ALIAS_UNITTESTS, "Runs all unit tests", Fore.LIGHTMAGENTA_EX),
		(ALIAS_CORE_UNITTESTS, "Runs MetaFFI core unit tests", Fore.LIGHTMAGENTA_EX),
		(ALIAS_PYTHON3_UNITTESTS, "Runs Python3 plugin unit tests", Fore.LIGHTMAGENTA_EX),
		(ALIAS_GO_UNITTESTS, "Runs Go plugin unit tests", Fore.LIGHTMAGENTA_EX),
		(ALIAS_OPENJDK_UNITTESTS, "Runs OpenJDK plugin unit tests", Fore.LIGHTMAGENTA_EX),
		(ALIAS_API_TESTS, "Runs all API tests", Fore.LIGHTGREEN_EX),
		(ALIAS_PYTHON3_API_TESTS, "Runs Python3 plugin API tests", Fore.LIGHTGREEN_EX),
		(ALIAS_GO_API_TESTS, "Runs Go plugin API tests", Fore.LIGHTGREEN_EX),
		(ALIAS_OPENJDK_API_TESTS, "Runs OpenJDK plugin API tests", Fore.LIGHTGREEN_EX),
		(ALIAS_BUILD_AND_TEST, "Builds and runs all unit tests and API tests", Fore.LIGHTBLUE_EX),
		(ALIAS_ALL_TESTS, "Runs all unit tests and API tests", Fore.LIGHTBLUE_EX),
		(ALIAS_PYTHON3_ALL, "Builds, runs unit tests and API tests for Python3 plugin", Fore.LIGHTRED_EX),
		(ALIAS_GO_ALL, "Builds, runs unit tests and API tests for Go plugin", Fore.LIGHTRED_EX),
		(ALIAS_OPENJDK_ALL, "Builds, runs unit tests and API tests for OpenJDK plugin", Fore.LIGHTRED_EX),
		(ALIAS_PYTHON3_PUBLISH_API, 'Publish MetaFFI Python3 API library to PyPI', Fore.CYAN+Style.DIM),
	]

	# Determine the maximum length of the alias names
	max_alias_length = max(len(alias) for alias, _, _ in aliases)

	print(f'{Fore.CYAN}{Style.BRIGHT}Available aliases:{Fore.RESET}')
	for alias, description, color in aliases:
		print(f'{color}  {alias:<{max_alias_length}} {Style.RESET_ALL} - {description}')
	print()




if SCons.Script.GetOption('print-aliases'):
	print_aliases(env)
	env.Exit()