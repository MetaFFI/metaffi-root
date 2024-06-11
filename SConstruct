import os
from re import S
import SCons.Environment
import SCons.Script
import SCons.Node.FS
import sys
import environment_custom_methods
from git import Repo  # GitPython
from SCons.Script.Main import Progress

# * ---- Set up the environment ----
env = SCons.Environment.Environment()

env['PATH'] = os.environ['PATH']
env['LocalAppData'] = os.environ['LocalAppData']
env['AppData'] = os.environ['AppData']
env['ProgramData'] = os.environ['ProgramData']
env['ProgramFiles'] = os.environ['ProgramFiles']
env['SystemRoot'] = os.environ['SystemRoot']
env['TEMP'] = os.environ['TEMP']
env['METAFFI_HOME'] = os.environ['METAFFI_HOME']


# * ---- Progress logger ----
def progress_logger_func(node):
	# print(f'Processing {node.abspath}')
	return None

Progress(progress_logger_func)

# * ---- Set custom methods and builders ----2
# 53
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

# * verify conan package manager exists
if not env.WhereWithError('conan'):
	print('Conan package manager is not installed. Install using "pip install conan" Exiting...', file=sys.stderr)
	env.Exit(1)

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

# unitests
SCons.Script.AddOption('--unitests',
                       dest='unitests',
                       action='store_true',
					   default=False,
                       help='Run the unit tests')

# unitests + cross-language tests
SCons.Script.AddOption('--all-tests',
					   dest='all-tests',
					   action='store_true',
					   default=False,
					   help='Run unit tests and cross-language tests')


# * ---- Build the MetaFFI projects ----
default_targets = []
default_targets.append(SCons.Script.SConscript('metaffi-core/SConscript_metaffi-core', exports='env'))

#env.Default(default_targets)
