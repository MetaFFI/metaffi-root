import re
from typing import Tuple
import os
import SCons.Script
import SCons.Node.FS
from SCons.Environment import Environment
import sys
import glob
import subprocess
import compiler_options
import post_actions
from typing import *
from colorama import Fore

from site_scons import scons_utils

def verify_metaffi_home() -> Tuple[bool, str]:
	if 'METAFFI_HOME' not in os.environ:
		msg = 'METAFFI_HOME environment variable is not set.'
		msg += 'Set METAFFI_HOME to where you want MetaFFI to be installed.'
		return False, msg

	metaffi_home = os.environ['METAFFI_HOME']
	if not os.path.exists(metaffi_home):
		try:
			os.makedirs(metaffi_home)
		except Exception as e:
			return False, f'Failed to create METAFFI_HOME: {e}'
			
	return True, None

def WhereWithError(env: Environment, cmd: str) -> Tuple[bool, str]:
	if not env.WhereIs(cmd):
		path = env['ENV']['PATH'].split(os.path.pathsep)
		msg = f'{cmd} is not installed.\nSCons PATH: {path}'
		return False, msg
	
	return True, None


def LoadConanPackagesInfo(env: Environment):
	# if current directory (based on current __FILE__ location) doesn't have conanfile.txt, raise an error that the current directory has no conanfile.txt
	if not env.Dir('.').File('conanfile.txt').exists():
		expected_file_location = env.Dir('.').File('conanfile.txt').abspath
		print(f'{expected_file_location} not found in the current directory. Exiting...', file=sys.stderr)
		env.Exit(1)

	# if SConscript_conandeps doesn't exist, run 'conan install . --build=missing' and delete generated batch files
	# make sure not to delete batch files that were generated by the user
	if not os.path.exists(env.Dir('.').File('SConscript_conandeps').abspath):
		# get all existing batch files
		# run 'conan install . --build=missing'
		# delete all the batch files generated by conan, but make sure not to delete the batch files that were generated by the user
		
		# get all existing batch files before installing
		batch_files_before = glob.glob(os.path.join(env.Dir('.').abspath, '*.bat'))

		print('Running conan install . --build=missing')
		process = subprocess.run('conan install . --build=missing', shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		# Print stdout and stderr
		print(process.stdout.decode())
		print(process.stderr.decode(), file=sys.stderr)

		if process.returncode != 0:
			print('Failed to run conan install. Exiting...', file=sys.stderr)
			env.Exit(1)

		# delete all batch files that don't exist in batch_files_before
		batch_files_after = glob.glob(os.path.join(env.Dir('.').abspath, '*.bat'))
		for batch_file in batch_files_after:
			if batch_file not in batch_files_before:
				os.remove(batch_file)

		# make sure that SConscript_conandeps is created
		if not os.path.exists(env.Dir('.').File('SConscript_conandeps').abspath):
			print('Failed to create SConscript_conandeps. Exiting...', file=sys.stderr)
			env.Exit(1)

	conan_info = SCons.Script.SConscript('SConscript_conandeps')
	env['conan_info'] = conan_info

	# load CPPDEFINES, CPPFLAGS, CPPPATH, LIBS, LIBPATH from conan_info
	env.Append(CPPDEFINES=env['conan_info']['conandeps'].get('CPPDEFINES', []))
	env.Append(CPPFLAGS=env['conan_info']['conandeps'].get('CPPFLAGS', []))
	env.Append(CPPPATH=env['conan_info']['conandeps'].get('CPPPATH', []))
	env.Append(LIBS=env['conan_info']['conandeps'].get('LIBS', []))
	env.Append(LIBPATH=env['conan_info']['conandeps'].get('LIBPATH', []))


# CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS implementation
# extract symbols from object files
def DefFromWindowsObjs(target, source, env):

	# make sure that dumpbin is found
	if not env.WhereIs('dumpbin'):
		print('dumpbin.exe is not found. Exiting...', file=sys.stderr)
		env.Exit(1)
	
	# use dumpbin to extract symbols from object files
	object_files = [str(s.abspath) for s in source]
	symbols = []
	for object_file in object_files:
		try:
			process = subprocess.run([env.WhereIs('dumpbin'), '/SYMBOLS', object_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
			if process.returncode != 0:
				print(f'Failed to extract symbols from {object_file}. Exiting...', file=sys.stderr)
				env.Exit(1)
			# parse output and append to symbols list - make sure to append only the symbol name
			output = process.stdout.decode()
			# Adjust the regex pattern based on the actual format of the dumpbin output
			pattern = r'[0-9A-Fa-f]{3} [0-9A-Fa-f]{8} (.{5}) .*(External|Public).*\| ([^\s]+)'
			matches = re.finditer(pattern, output, re.MULTILINE)
			for match in matches:
				if 'UNDEF' not in match.group(0):
					symbol = match.group(3).strip()
					symbols.append(symbol)
		except Exception as e:
			print(f'Failed to extract symbols from {object_file}.\nError {e}.\nExiting...', file=sys.stderr)
			env.Exit(1)

	# make sure all symbols are unique by converting to set and back to list
	symbols = list(set(symbols))
	new_content = 'EXPORTS\n' + '\n'.join(['\t' + symbol for symbol in symbols])

	def_file_path = target[0].abspath
	try:
		# Read the existing DEF file content
		with open(def_file_path, 'r', encoding='utf-8') as f:
			existing_content = f.read()
	except FileNotFoundError:
		existing_content = ""

	# Write to the DEF file only if the content has changed
	if new_content != existing_content:
		with open(def_file_path, 'w', encoding='utf-8') as f:
			f.write(new_content)



def CPPSharedLibrary(env: Environment, target: str, project_name: str, sources: List[str], include_dirs: List[str]|None = None, lib_dirs: List[str]|None = None, libs: List[str]|None = None) -> SCons.Node.NodeList:
	if 'release' in env['BUILD_TYPE']:
		options = compiler_options.default_release_compiler_options(env)
	elif 'debug' in env['BUILD_TYPE']:
		options = compiler_options.default_debug_compiler_options(env)
	elif 'release_debug_info' in env['BUILD_TYPE']:
		options = compiler_options.default_release_with_debug_info_compiler_options(env)
	else:
		print(f'Unknown BUILD_TYPE: {env["BUILD_TYPE"]}. Exiting...', file=sys.stderr)
		env.Exit(1)

	if include_dirs is not None:
		options.set_include_directories(include_dirs)

	if lib_dirs is not None:
		options.set_lib_directories(lib_dirs)

	if libs is not None:
		options.add_library(libs)
	
	options.set_output_directories(project_name, target)

	# is filename contains ".", SCons produces an error, unless full file name is provided
	dynamic_lib_full_name = env['OUTPUT_BIN']+env.DynamicLibraryExtension()

	# if non-windows, just compile the shared object,
	# in windows, create object files, extract their symbols, make a def file, and then create the shared object
	if env['PLATFORM'] != 'win32':
		return env.SharedLibrary(dynamic_lib_full_name, source=sources)
	else:
		fullpath_without_extension = env['OUTPUT_BIN']
		def_file = fullpath_without_extension + '.def'

		# make sure the directory of env['OUTPUT_BIN'] exists
		if not os.path.exists(os.path.dirname(fullpath_without_extension)):
			os.makedirs(os.path.dirname(fullpath_without_extension))

		# compile object files
		object_files = env.Object(sources)
		env.Depends(object_files, sources)
		deffile = env.DefFromWindowsObjs(target=def_file, source=object_files)
		env.Depends(deffile, object_files)
		
		# create shared object
		# windows shared object specific flags
		env.setdefault('SHLINKFLAGS', []).append('/DEF:'+def_file)
		env['SHLINKFLAGS'].append('/DLL')

		dll = env.SharedLibrary(target=dynamic_lib_full_name, source=object_files, SHLIBPREFIX='')
		env.Depends(dll, deffile)

		return dll


def CPPProgram(env: Environment, target: str, project_name: str, sources: List[str], include_dirs: List[str] = [], lib_dirs: List[str] = [], libs: List[str] = []) -> SCons.Node.NodeList:
		
	if 'release' in env['BUILD_TYPE']:
		options = compiler_options.default_release_compiler_options(env)
	elif 'debug' in env['BUILD_TYPE']:
		options = compiler_options.default_debug_compiler_options(env)
	elif 'release_debug_info' in env['BUILD_TYPE']:
		options = compiler_options.default_release_with_debug_info_compiler_options(env)
	else:
		print(f'Unknown BUILD_TYPE: {env["BUILD_TYPE"]}. Exiting...', file=sys.stderr)
		env.Exit(1)

	if include_dirs is not None:
		options.set_include_directories(include_dirs)
	
	if lib_dirs is not None:
		options.set_lib_directories(lib_dirs)

	if libs is not None:
		options.add_library(libs)
	
	options.set_output_directories(project_name, target)

	return env.Program(target=env['OUTPUT_BIN'], source=sources)


def GoTest(env: Environment, target: str, path: str) -> SCons.Node.NodeList:
	return env.Command(target=target, source=[], action=post_actions.execute_go_unitest, chdir=path)

def DynamicLibraryExtension(env: Environment) -> str:
	if env['PLATFORM'] == 'win32':
		return '.dll'
	elif env['PLATFORM'] == 'linux':
		return '.so'
	elif env['PLATFORM'] == 'darwin':
		return '.dylib'
	else:
		print(f'Unknown PLATFORM: {env["PLATFORM"]}. Exiting...', file=sys.stderr)
		env.Exit(1)

def IsWindows(env: Environment) -> bool:
	return env['PLATFORM'] == 'win32'

def IsLinux(env: Environment) -> bool:
	return env['PLATFORM'] == 'linux'

def IsMac(env: Environment) -> bool:
	return env['PLATFORM'] == 'darwin'

def IsDebug(env: Environment) -> bool:
	return 'debug' in env['BUILD_TYPE']

def IsRelease(env: Environment) -> bool:
	return 'release' in env['BUILD_TYPE']

def IsReleaseDebugInfo(env: Environment) -> bool:
	return 'release_debug_info' in env['BUILD_TYPE']

# assumes conan already loaded using LoadConanPackagesInfo
def SearchConanBinaryFile(env: Environment, package_name: str, binary_name: str) -> str|None:
	for binlib in env['conan_info'][package_name]['BINPATH']:
		binpath = os.path.join(binlib, binary_name)
		if os.path.exists(binpath):
			return binpath
	
	return None

# * Go Builder for SCons
def GoBuildProgram(target, source, env):
	# source is a directory
	# target is a file
	# execute "go build -o target source"

	if not os.path.exists(source):
		print(f'Source directory f{source} does not exist. Exiting...', file=sys.stderr)
		env.Exit(1)

	if not os.path.isabs(target):
		target = os.path.join(source, target)

	goexec = env.WhereIs('go')
	if goexec is None:
		print('go is not installed or cannot be found. Exiting...', file=sys.stderr)
		env.Exit(1)

	exitcode = env.Execute(f"go get", chdir=os.path.dirname(source[0]))
	if exitcode is not None and exitcode != 0:
		print(f'Failed go get command with exit code {exitcode}. Exiting...', file=sys.stderr)
		env.Exit(1)

	exitcode = env.Execute(f"go build -o {target} .", chdir=os.path.dirname(source[0]))
	if exitcode is not None and exitcode != 0:
		print(f'Failed to build Go program. Exiting...', file=sys.stderr)
		env.Exit(1)

def GoBuildCSharedLib(env: Environment, target: str, source_dir: str) -> SCons.Node.NodeList:

	if isinstance(target, list):
		if len(target) != 1:
			print(f'Only a single target is supported, not {len(target)} targets. Exiting...', file=sys.stderr)
			env.Exit(1)

		target = target[0]

	if isinstance(target, SCons.Node.FS.File):
		target = target.abspath

	if not target.endswith(env.DynamicLibraryExtension()):
		target += env.DynamicLibraryExtension()

	return env.GoBuildCSharedLibBuilder(target=target, source=env.Glob(f'{source_dir}/*.go'))
	
def GoBuildCSharedLibBuilder(target, source, env):
	# source is a directory
	# target is a file
	# execute "go build -buildmode=c-shared -gcflags=-shared -o target source"

	source = scons_utils.to_list_of_str_or_str(source)
	target = scons_utils.to_list_of_str_or_str(target)

	if isinstance(source, list):
		source = os.path.dirname(source[0])
	else:
		source = os.path.dirname(source)

	if not isinstance(target, str):
		print('expected a single target file. got: ' + str(target), sys.stderr)
		env.Exit(1)

	if not target.endswith(env.DynamicLibraryExtension()):
		target += f'{env.DynamicLibraryExtension()}'

	if not os.path.isabs(target):
		target = os.path.join(source, target)

	goexec = env.WhereIs('go.exe')
	if goexec is None:
		print('go is not installed or cannot be found. Exiting...', file=sys.stderr)
		env.Exit(1)

	curpath = os.getcwd()

	try:
		os.chdir(source)
		exitcode = env.Execute(f"go get")
		if exitcode is not None and exitcode != 0:
			print(f'Failed go get command with exit code {exitcode}. Exiting...', file=sys.stderr)
			env.Exit(1)

		exitcode = env.Execute(f"go build -buildmode=c-shared -gcflags=-shared -o {target} .")
		if exitcode is not None and exitcode != 0:
			print(f'Failed to build Go program. Exiting...', file=sys.stderr)
			env.Exit(1)
	finally:
		os.chdir(curpath)

def MetaFFICompileGuest(env: Environment, output_dir: str, source_idl: str) -> SCons.Node.NodeList:
	# run the command "metaffi -c --idl source_idl -o output_dir -g"
	
	def compile_metaffi_guest(target, source, env):
		if not os.path.exists(source_idl):
			print(f'Source/IDL file {source_idl} does not exist. Exiting...', file=sys.stderr)
			env.Exit(1)

		# if "output_dir" doesn't exist - create it
		if not os.path.exists(output_dir):
			os.makedirs(output_dir)
			
		print(f"metaffi -c --idl {source_idl} -o {output_dir} -g")
		exitcode = env.Execute(f"metaffi -c --idl {source_idl} -o {output_dir} -g")
		if exitcode is not None and exitcode != 0:
			print(f'Failed to compile MetaFFI guest. Exit code: {exitcode}. Exiting...', file=sys.stderr)
			env.Exit(1)
	
	return env.Command(target=output_dir, source=source_idl, action=compile_metaffi_guest, chdir=os.path.dirname(source_idl))

def MetaFFICompileHost(target, source, env):
	plugin = env.get('plugin', None)
	if plugin is None:
		print('plugin is not set. Exiting...', file=sys.stderr)
		env.Exit(1)

	# run the command "metaffi -c --idl source -o target -h plugin"
	if not os.path.exists(source):
		print(f'Source file {source} does not exist. Exiting...', file=sys.stderr)
		env.Exit(1)

	if not os.path.isabs(target):
		target = os.path.join(os.path.dirname(source), target)

	exitcode = env.Execute(f'metaffi -c --idl \'{source}\' -o \'{target}\' -h {plugin}')
	if exitcode is not None:
		print(f'Failed to compile MetaFFI host. Exiting...', file=sys.stderr)
		env.Exit(1)

def JaraJar(env: Environment, target: str, source: List[str], project_name: str, classpath: List[str]|None = None) -> SCons.Node.NodeList:
	if 'release' in env['BUILD_TYPE']:
		options = compiler_options.default_release_compiler_options(env)
	elif 'debug' in env['BUILD_TYPE']:
		options = compiler_options.default_debug_compiler_options(env)
	elif 'release_debug_info' in env['BUILD_TYPE']:
		options = compiler_options.default_release_with_debug_info_compiler_options(env)
	else:
		print(f'Unknown BUILD_TYPE: {env["BUILD_TYPE"]}. Exiting...', file=sys.stderr)
		env.Exit(1)

	options.set_output_directories(project_name, target)

	if classpath is not None:
		env['classpath'] = classpath

	return env.JavaJarBuilder(target=env['OUTPUT_BIN'], source=source)

def JavaJarBuilder(target, source, env):
	# source is a list of files
	# target is a file
	# env['classpath'] might be set with classpath
	# class files should be built to env['OBJPREFIX']/target_name directory
	# create jar should be built to env['OUTPUT_BIN'] directory
	# execute "javac -d env['OBJPREFIX']/target_name source"
	# execute "jar cvf env['OUTPUT_BIN']/target_name source"

	classpath = env.get('classpath', None)

	if isinstance(source, str):
		source = [source]

	if len(source) == 0:
		print('No source files provided. Exiting...', file=sys.stderr)
		env.Exit(1)

	if isinstance(source[0], SCons.Node.FS.File):
		source = [src.abspath for src in source]

	for src in source:
		if not os.path.exists(src):
			print(f'Source file {src} does not exist. Exiting...', file=sys.stderr)
			env.Exit(1)

	if isinstance(target, list):
		if len(target) != 1:
			print(f'Only a single target is supported, not {len(target)}. Exiting...', file=sys.stderr)
			env.Exit(1)

		target = target[0]

	if isinstance(target, SCons.Node.FS.File):
		target = target.abspath

	if not os.path.isabs(target):
		target = os.path.join(source, target)

	if not target.endswith('.jar'):
		target += '.jar'
		
	# execute javac and jar with subprocess
	class_files_dir = env['OBJPREFIX']
	jar_file = target

	# compile java files
	if classpath is not None:
		javac_cmd = ['javac', '-d', class_files_dir, '-cp']
		javac_cmd.append(os.path.pathsep.join(classpath))
		javac_cmd.extend(source)
	else:
		javac_cmd = ['javac', '-d', class_files_dir]
		javac_cmd.extend(source)
	env.Execute(' '.join(javac_cmd))
	# subprocess.run(javac_cmd, check=True, env=env['ENV'])

	# create jar file
	jar_cmd = ['jar', 'cvf', jar_file, '-C', class_files_dir, '.']
	env.Execute(' '.join(jar_cmd))
	# subprocess.run(jar_cmd, check=True, env=env['ENV'])


def add_custom_methods(env: Environment):
	env.AddMethod(WhereWithError, 'WhereWithError')
	env.AddMethod(LoadConanPackagesInfo, 'LoadConanPackagesInfo')
	env.AddMethod(CPPProgram, 'CPPProgram')
	env.AddMethod(GoTest, 'GoTest')
	env.AddMethod(CPPSharedLibrary, 'CPPSharedLibrary')
	env.AddMethod(DynamicLibraryExtension, 'DynamicLibraryExtension')
	env.AddMethod(IsWindows, 'IsWindows')
	env.AddMethod(IsLinux, 'IsLinux')
	env.AddMethod(IsMac, 'IsMac')
	env.AddMethod(IsDebug, 'IsDebug')
	env.AddMethod(IsRelease, 'IsRelease')
	env.AddMethod(IsReleaseDebugInfo, 'IsReleaseDebugInfo')
	env.AddMethod(SearchConanBinaryFile, 'SearchConanBinaryFile')
	env.AddMethod(JaraJar, 'JavaJar')
	env.AddMethod(GoBuildCSharedLib, 'GoBuildCSharedLib')
	env.AddMethod(MetaFFICompileGuest, 'MetaFFICompileGuest')
	env.AddMethod(MetaFFICompileHost, 'MetaFFICompileHost')

	env.Append(BUILDERS={'DefFromWindowsObjs': env.Builder(action=DefFromWindowsObjs),
						'GoBuildProgram': env.Builder(action=GoBuildProgram),
						'GoBuildCSharedLibBuilder': env.Builder(action=GoBuildCSharedLibBuilder),
						'JavaJarBuilder': env.Builder(action=JavaJarBuilder)})

	