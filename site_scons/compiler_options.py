from enum import Enum
import os
import platform
import re
from enum import Enum
import os
import SCons.Environment
from typing import List

class Compiler(Enum):
	GCC = 'gcc'
	CL = 'cl'
	CLANG = 'clang'
	CLCLANG = 'cl-clang'

class CompilerEnvVarOptions:
	def __init__(self, cpp_compiler: Compiler, environment: SCons.Environment.Environment):
		self.cpp_compiler = cpp_compiler
		self.env_vars = environment

		if self.cpp_compiler == Compiler.GCC:
			self.env_vars['CC'] = 'gcc'
			self.env_vars['CXX'] = 'g++'
			self.env_vars.setdefault('CXXFLAGS', []).append("-fexceptions") # Enable C++ exceptions
			self.env_vars.setdefault('CXXFLAGS', []).append("-finput-charset=UTF-8") # Set the source and execution character set to UTF-8
			self.env_vars.setdefault('CXXFLAGS', []).append("-Wno-unused-parameter") # Disable warning C4100: 'identifier': unreferenced formal parameter

			# set rpath to $ORIGIN and $ORIGIN/lib for mac
			if platform.system() == 'Darwin':
				self.env_vars.setdefault('RPATH', []).append("@loader_path")
				self.env_vars.setdefault('RPATH', []).append("@loader_path/lib")
			else :
				self.env_vars.setdefault('RPATH', []).append("$ORIGIN")
				self.env_vars.setdefault('RPATH', []).append("$ORIGIN/lib")

		elif self.cpp_compiler == Compiler.CL:
			self.env_vars['CC'] = 'cl'
			self.env_vars['CXX'] = 'cl'
			self.env_vars.setdefault('CXXFLAGS', []).append(f"/EHsc") # Enable C++ exceptions
			self.env_vars.setdefault('CXXFLAGS', []).append("/utf-8") # Set the source and execution character set to UTF-8
			self.env_vars.setdefault('CXXFLAGS', []).append("/wd4100") # Disable warning C4100: 'identifier': unreferenced formal parameter
		elif self.cpp_compiler == Compiler.CLANG:
			self.env_vars['CC'] = 'clang'
			self.env_vars['CXX'] = 'clang++'
			self.env_vars.setdefault('CXXFLAGS', []).append("-fexceptions")
			self.env_vars.setdefault('CXXFLAGS', []).append("-finput-charset=UTF-8")
			self.env_vars.setdefault('CXXFLAGS', []).append("-Wno-unused-parameter")

			# set rpath to $ORIGIN and $ORIGIN/lib for mac
			if platform.system() == 'Darwin':
				self.env_vars.setdefault('RPATH', []).append("@loader_path")
				self.env_vars.setdefault('RPATH', []).append("@loader_path/lib")
			else :
				self.env_vars.setdefault('RPATH', []).append("$ORIGIN")
				self.env_vars.setdefault('RPATH', []).append("$ORIGIN/lib")

		elif self.cpp_compiler == Compiler.CLCLANG:
			self.env_vars['CC'] = 'cl-clang'
			self.env_vars['CXX'] = 'cl-clang'
			self.env_vars.setdefault('CXXFLAGS', []).append("-fexceptions")
			self.env_vars.setdefault('CXXFLAGS', []).append("-finput-charset=UTF-8")
			self.env_vars.setdefault('CXXFLAGS', []).append("-Wno-unused-parameter")

			# set rpath to $ORIGIN and $ORIGIN/lib for mac
			if platform.system() == 'Darwin':
				self.env_vars.setdefault('RPATH', []).append("@loader_path")
				self.env_vars.setdefault('RPATH', []).append("@loader_path/lib")
			else :
				self.env_vars.setdefault('RPATH', []).append("$ORIGIN")
				self.env_vars.setdefault('RPATH', []).append("$ORIGIN/lib")

		else:
			raise ValueError(f"Unknown compiler: {cpp_compiler}")
		
		arch = platform.machine()

		if arch == "AMD64":
			self.env_vars['architecture'] = "x64"
		else:
			self.env_vars['architecture'] = arch


	def set_warning_level(self, level: int):
		if self.cpp_compiler in (Compiler.GCC, Compiler.CLANG, Compiler.CLCLANG):
			self.env_vars.setdefault('CXXFLAGS', []).append(f"-W{level}")
		elif self.cpp_compiler == Compiler.CL:
			cl_warning_options = {
				1: "/W1",
				2: "/W2",
				3: "/W3",
				4: "/W4"
			}
			self.env_vars.setdefault('CXXFLAGS', []).append(cl_warning_options.get(level, "/W3"))
		else:
			raise ValueError(f"Unknown compiler: {self.cpp_compiler}")

	def use_pic(self):
		if self.cpp_compiler in (Compiler.GCC):
			self.env_vars.setdefault('CXXFLAGS', []).append("-fPIC")
		elif self.cpp_compiler == Compiler.CLANG or self.cpp_compiler == Compiler.CLCLANG:
			# CLANG doesn't have an equivalent for -fPIC; omit it for CLANG
			pass
		elif self.cpp_compiler == Compiler.CL:
			# CL doesn't have an equivalent for -fPIC; omit it for CL
			pass
		else:
			raise ValueError(f"Unknown compiler: {self.cpp_compiler}")

	def set_static_runtime(self):
		if self.cpp_compiler == Compiler.GCC:
			self.env_vars.setdefault('LDFLAGS', []).append("-static-libgcc")
		elif self.cpp_compiler == Compiler.CLANG or self.cpp_compiler == Compiler.CLCLANG:
			# CLANG doesn't have an equivalent for -static-libgcc; omit it for CLANG
			pass
		elif self.cpp_compiler == Compiler.CL:
			self.env_vars.setdefault('LDFLAGS', []).append("/MT")
		else:
			raise ValueError(f"Unknown compiler: {self.cpp_compiler}")

	def set_dynamic_runtime(self):
		if self.cpp_compiler == Compiler.GCC:
			self.env_vars.setdefault('LDFLAGS', []).append("-shared-libgcc")
		elif self.cpp_compiler == Compiler.CLANG or self.cpp_compiler == Compiler.CLCLANG:
			# CLANG doesn't have an equivalent for -shared-libgcc; omit it for CLANG
			pass
		elif self.cpp_compiler == Compiler.CL:
			self.env_vars.setdefault('LDFLAGS', []).append("/MD")
		else:
			raise ValueError(f"Unknown compiler: {self.cpp_compiler}")

	def set_include_directories(self, dirs: list):
		if isinstance(dirs, str):
			dirs = [dirs]
		self.env_vars.setdefault('CPPPATH', []).extend(dirs)  # Append to CPPPATH

	def set_lib_directories(self, dirs: list):
		if isinstance(dirs, str):
			dirs = [dirs]
		self.env_vars.setdefault('LIBPATH', []).extend(dirs)  # Append to LIBPATH

	def add_library(self, lib: List[str]):
		if isinstance(lib, str):
			lib = [lib]
		self.env_vars.setdefault('LIBS', []).extend(lib)

	def set_cpp_standard(self, version: int):
		if self.cpp_compiler == Compiler.GCC:
			self.env_vars.setdefault('CXXFLAGS', []).append(f"-std=c++{version}")
		elif self.cpp_compiler == Compiler.CLANG or self.cpp_compiler == Compiler.CLCLANG:
			self.env_vars.setdefault('CXXFLAGS', []).append(f"-std=c++{version}")
		elif self.cpp_compiler == Compiler.CL:
			self.env_vars.setdefault('CXXFLAGS', []).append(f"/std:c++{version}")
		else:
			raise ValueError(f"Unknown compiler: {self.cpp_compiler}")

	def set_debug(self):
		if self.cpp_compiler == Compiler.GCC:
			# Add debug-specific options
			self.env_vars.setdefault('CXXFLAGS', []).append("-g")
		elif self.cpp_compiler == Compiler.CLANG or self.cpp_compiler == Compiler.CLCLANG:
			# Add debug-specific options
			self.env_vars.setdefault('CXXFLAGS', []).append("-g")
		elif self.cpp_compiler == Compiler.CL:
			# Add debug-specific options
			self.env_vars.setdefault('CXXFLAGS', []).extend(["/Zi", "/EHsc", "/MD"])
			self.env_vars.setdefault('CCFLAGS', []).extend(["/Zi", "/MD"])
			self.env_vars.setdefault('LINKFLAGS', []).append("/DEBUG")
		else:
			raise ValueError(f"Unknown compiler: {self.cpp_compiler}")

	def set_release(self):
		# Add release-specific options
		if self.cpp_compiler == Compiler.GCC:
			self.env_vars.setdefault('CXXFLAGS', []).append("-O3")
		elif self.cpp_compiler == Compiler.CLANG or self.cpp_compiler == Compiler.CLCLANG:
			self.env_vars.setdefault('CXXFLAGS', []).append("-O3")
		elif self.cpp_compiler == Compiler.CL:
			self.env_vars.setdefault('CXXFLAGS', []).append("/O2")
		else:
			raise ValueError(f"Unknown compiler: {self.cpp_compiler}")
		

	def set_release_with_debug_info(self):
		# Add options for release with debug information
		if self.cpp_compiler == Compiler.GCC:
			self.env_vars.setdefault('CXXFLAGS', []).append("-O2")
			self.env_vars.setdefault('CXXFLAGS', []).append("-g")
		elif self.cpp_compiler == Compiler.CLANG or self.cpp_compiler == Compiler.CLCLANG:
			self.env_vars.setdefault('CXXFLAGS', []).append("-O2")
			self.env_vars.setdefault('CXXFLAGS', []).append("-g")
		elif self.cpp_compiler == Compiler.CL:
			self.env_vars.setdefault('CXXFLAGS', []).append("/O2")
			self.env_vars.setdefault('CXXFLAGS', []).append("/Zi")
		else:
			raise ValueError(f"Unknown compiler: {self.cpp_compiler}")
		

	def set_architecture(self, arch: str):
		self.env_vars['architecture'] = arch

		if self.cpp_compiler == Compiler.GCC:
			self.env_vars['CXXFLAGS'].append(f"-march={arch}")
		elif self.cpp_compiler == Compiler.CLANG or self.cpp_compiler == Compiler.CLCLANG:
			self.env_vars['CXXFLAGS'].append(f"-march={arch}")
		elif self.cpp_compiler == Compiler.CL:
			self.env_vars['CXXFLAGS'].append(f"/arch:{arch}")

	def set_output_directories(self, project_name: str, target: str):
		# the directory is #/output/[operating_system]/[architecture]/[target]
		arch = self.env_vars["architecture"]
		self.env_vars['BASE_OUTPUT_DIR'] = self.env_vars.Dir(f'#/output/{platform.system()}/{arch}/{project_name}/').abspath
		self.env_vars['OUTPUT_BIN'] = self.env_vars.Dir(self.env_vars['BASE_OUTPUT_DIR']+'/bin/').File(target).abspath
		self.env_vars['OBJPREFIX'] = self.env_vars.Dir(self.env_vars['BASE_OUTPUT_DIR']+'/obj/').abspath + '/'
		# self.env_vars['LIBPREFIX'] = self.env_vars.Dir(self.env_vars['BASE_OUTPUT_DIR']+'/lib/').abspath + '/'


def default_debug_compiler_options(env: SCons.Environment.Environment) -> CompilerEnvVarOptions:
	if platform.system() == 'Windows':
		# Set the default compiler to CL
		compiler_options = CompilerEnvVarOptions(Compiler.CL, env)
		compiler_options.set_warning_level(4)
		compiler_options.set_dynamic_runtime()
		compiler_options.set_cpp_standard(20)
		compiler_options.set_debug()

	elif platform.system() == 'Linux':
		# Set the default compiler to GCC
		compiler_options = CompilerEnvVarOptions(Compiler.GCC, env)
		compiler_options.set_warning_level(4)
		compiler_options.use_pic()
		compiler_options.set_dynamic_runtime()
		compiler_options.set_cpp_standard(20)
		compiler_options.set_debug()

	elif platform.system() == 'Darwin':
		# Set the default compiler to CLANG
		compiler_options = CompilerEnvVarOptions(Compiler.CLANG, env)
		compiler_options.set_warning_level(4)
		compiler_options.use_pic()
		compiler_options.set_dynamic_runtime()
		compiler_options.set_cpp_standard(20)
		compiler_options.set_debug()

	else:
		# unsupported platform
		raise ValueError(f"Unsupported platform: {platform.system()}")
	
	return compiler_options


def default_release_compiler_options(env: SCons.Environment.Environment) -> CompilerEnvVarOptions:
	if platform.system() == 'Windows':
		# Set the default compiler to CL
		compiler_options = CompilerEnvVarOptions(Compiler.CL, env)
		compiler_options.set_warning_level(4)
		compiler_options.set_dynamic_runtime()
		compiler_options.set_cpp_standard(20)
		compiler_options.set_release()
	elif platform.system() == 'Linux':
		# Set the default compiler to GCC
		compiler_options = CompilerEnvVarOptions(Compiler.GCC, env)
		compiler_options.set_warning_level(4)
		compiler_options.use_pic()
		compiler_options.set_dynamic_runtime()
		compiler_options.set_cpp_standard(20)
		compiler_options.set_release()
	elif platform.system() == 'Darwin':
		# Set the default compiler to CLANG
		compiler_options = CompilerEnvVarOptions(Compiler.CLANG, env)
		compiler_options.set_warning_level(4)
		compiler_options.use_pic()
		compiler_options.set_dynamic_runtime()
		compiler_options.set_cpp_standard(20)
		compiler_options.set_release()
	else:
		# unsupported platform
		raise ValueError(f"Unsupported platform: {platform.system()}")
	
	return compiler_options
	
def default_release_with_debug_info_compiler_options(env: SCons.Environment.Environment) -> CompilerEnvVarOptions:
	if platform.system() == 'Windows':
		# Set the default compiler to CL
		compiler_options = CompilerEnvVarOptions(Compiler.CL, env)
		compiler_options.set_warning_level(4)
		compiler_options.set_dynamic_runtime()
		compiler_options.set_cpp_standard(20)
		compiler_options.set_release_with_debug_info()
	elif platform.system() == 'Linux':
		# Set the default compiler to GCC
		compiler_options = CompilerEnvVarOptions(Compiler.GCC, env)
		compiler_options.set_warning_level(4)
		compiler_options.use_pic()
		compiler_options.set_dynamic_runtime()
		compiler_options.set_cpp_standard(20)
		compiler_options.set_release_with_debug_info()
	elif platform.system() == 'Darwin':
		# Set the default compiler to CLANG
		compiler_options = CompilerEnvVarOptions(Compiler.CLANG, env)
		compiler_options.set_warning_level(4)
		compiler_options.use_pic()
		compiler_options.set_dynamic_runtime()
		compiler_options.set_cpp_standard(20)
		compiler_options.set_release_with_debug_info()
	else:
		# unsupported platform
		raise ValueError(f"Unsupported platform: {platform.system()}")
	
	return compiler_options
	

