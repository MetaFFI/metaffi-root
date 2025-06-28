#!/usr/bin/env python3

import os
import sys
import subprocess
import platform
import tempfile
import shutil
from pathlib import Path
from typing import List, Optional
from colorama import init, Fore, Style

# Initialize colorama
init()


def write_color_output(text: str, color: str) -> None:
	"""Write colored output to console."""
	print(f"{color}{text}{Style.RESET_ALL}")

def execute_cmd_line(exe: str, args: List[str]) -> str:
	"""Execute a command line and handle errors."""
	# Print the command line
	cmd_line = f"{exe} {' '.join(args)}"
	write_color_output(cmd_line, Fore.YELLOW)
	
	try:
		result = subprocess.run([exe] + args, text=True, check=True, capture_output=True)
		return result.stdout
	except subprocess.CalledProcessError as e:
		write_color_output(f'The command line "{cmd_line}" failed with exit code {e.returncode}', Fore.RED)
		write_color_output("Error output:", Fore.RED)
		write_color_output(e.stderr, Fore.RED)
		raise

def execute_cmd_line_stream_output(exe: str, args: List[str]) -> None:
	"""Execute a command line and stream output to stdout/stderr in real-time."""
	# Print the command line
	cmd_line = f"{exe} {' '.join(args)}"
	write_color_output(cmd_line, Fore.YELLOW)
	
	try:
		# Run the process and stream output in real-time
		result = subprocess.run([exe] + args, text=True, check=True)
		# No return value since output is streamed directly
	except subprocess.CalledProcessError as e:
		write_color_output(f'The command line "{cmd_line}" failed with exit code {e.returncode}', Fore.RED)
		raise


def get_cmake_generator() -> str:
	"""Get the appropriate CMake generator based on platform."""
	return "Ninja" if platform.system() == "Windows" else "Unix Makefiles"


def show_help() -> None:
	"""Show help message."""
	write_color_output("Usage: ./build_target.py [Target] [Options]", Fore.CYAN)
	write_color_output("Options:", Fore.CYAN)
	write_color_output("  --target <name>     : Target to build (required unless --list is used)", Fore.CYAN)
	write_color_output("  --build-type <type> : Build type (Debug, Release, RelWithDebInfo)", Fore.CYAN)
	write_color_output("  --clean            : Clean build directory before building", Fore.CYAN)
	write_color_output("  --verbose          : Show detailed build output", Fore.CYAN)
	write_color_output("  --list             : List all available targets", Fore.CYAN)
	write_color_output("  --help             : Show this help message", Fore.CYAN)
	write_color_output("", Fore.CYAN)
	write_color_output("Examples:", Fore.CYAN)
	write_color_output("  ./build_target.py metaffi-core", Fore.CYAN)
	write_color_output("  ./build_target.py --list", Fore.CYAN)
	write_color_output("  ./build_target.py MetaFFI --build-type Release --clean", Fore.CYAN)


def get_cmake_targets(build_dir: str, build_type: str) -> List[str]:
	"""Get available targets from CMake."""
	generator = get_cmake_generator()
	
	# Configure CMake if build directory is empty
	if not Path(build_dir).joinpath("CMakeCache.txt").exists():
		configure_cmake(build_dir, build_type)

	# Get targets from CMake
	targets = execute_cmd_line("cmake", ["--build", build_dir, "--target", "help"])
	 
	# Parse the output to get target names - improved parsing logic
	target_list = []
	 
	# Handle different output formats
	for line in targets.splitlines():
		line = line.strip()
  
		# get target 
		if not line.endswith(": phony"):
			continue

		line = line.replace(": phony", "")
  
		if '/' in line:
			continue
  
		if line.endswith("_cache"):
			continue
  
		if line.endswith(".exe") or line.endswith(".dll") or line.endswith("lib"):
			continue
  
		if line.endswith(".exe") or line.endswith(".dll") or line.endswith("lib"):
			continue
  
		if line == 'test' or line.endswith("/test"):
			continue

		# now it should contain only explicitly defined targets
  
		target_list.append(line)	
	
	target_list.append("all") # built-in target

	return target_list

  
def get_build_dir(build_type: str) -> str:
	"""Get the build directory path based on build type and platform."""
	build_type_lower = build_type.lower()
	build_dir = f"cmake-build-{build_type_lower}"
	if platform.system() == "Windows" and Path("/proc/version").exists():
		with open("/proc/version") as f:
			if "WSL" in f.read():
				build_dir = f"cmake-build-{build_type_lower}-wsl-2204"
	return build_dir


def get_output_dir(build_type: str) -> Path:
	"""Get the output directory path based on platform and build type."""
	platform_name = "windows" if platform.system() == "Windows" else "linux"
	return Path("output") / platform_name / "x64" / build_type


def handle_list_operation(build_type: str) -> None:
	"""Handle the --list operation to show available targets."""
	build_dir = get_build_dir(build_type)
	available_targets = get_cmake_targets(build_dir, build_type)
	write_color_output("Available targets:", Fore.CYAN)
	for target in available_targets:
		write_color_output(f"  - {target}", Fore.GREEN)


def configure_cmake(build_dir: str, build_type: str, verbose: bool = True, stream_output: bool = False) -> None:
	"""Configure CMake with the specified parameters."""
	write_color_output("Configuring CMake...", Fore.CYAN)
	generator = get_cmake_generator()
	cmake_args = [
		"-G", generator,
		"-S", str(Path.cwd()),
		"-B", build_dir,
		f"-DCMAKE_BUILD_TYPE={build_type}"
	]
	if verbose:
		cmake_args.append("-DCMAKE_VERBOSE_MAKEFILE=ON")
	
	if stream_output:
		execute_cmd_line_stream_output("cmake", cmake_args)
	else:
		execute_cmd_line("cmake", cmake_args)


def execute_cmake_build(build_dir: str, target: str, build_type: str, verbose: bool = True) -> None:
	"""Execute CMake build for the specified target."""
	write_color_output(f"Building target: {target}", Fore.CYAN)
	build_args = [
		"--build", build_dir,
		"--target", target,
		"--config", build_type
	]
	if verbose:
		build_args.append("--verbose")

	execute_cmd_line_stream_output("cmake", build_args)
	

def main() -> None:
	"""Main function."""
	import argparse
	
	parser = argparse.ArgumentParser(description="Build MetaFFI targets")
	parser.add_argument("target", nargs="?", help="Target to build")
	parser.add_argument("--build-type", choices=["Debug", "Release", "RelWithDebInfo"], help="Build type")
	parser.add_argument("--clean", action="store_true", help="Clean build directory before building")
	parser.add_argument("--list", action="store_true", help="List all available targets")
	parser.add_argument("--verbose", action="store_true", help="Show detailed build output")
	args = parser.parse_args()
	
	if args.list:
		# if --list was chosen and there's not build type, then use Debug
		if not args.build_type:
			args.build_type = "Debug"
   
		handle_list_operation(args.build_type)
		return

	if not args.target:
		write_color_output("No target specified", Fore.RED)
		write_color_output("Use --list to see available targets or --help for help", Fore.RED)
		return

	if not args.build_type:
		# revert to Debug
		write_color_output("No build type specified, reverting to Debug", Fore.MAGENTA)
		args.build_type = "Debug"

	# Set up paths
	build_dir = get_build_dir(args.build_type)
	output_dir = get_output_dir(args.build_type)

	# print chosen build type, build dir, and output dir
	write_color_output(f"Chosen build type: {args.build_type}", Fore.CYAN)
	write_color_output(f"Build directory: {build_dir}", Fore.CYAN)
	write_color_output(f"Output directory: {output_dir}", Fore.CYAN)

	# Validate CMake is installed
	execute_cmd_line("cmake", ["--version"])

	# Clean build directory if requested
	if args.clean:
		write_color_output("Cleaning build directory...", Fore.YELLOW)
		if Path(build_dir).exists():
			shutil.rmtree(build_dir)

	# Create build directory if it doesn't exist
	Path(build_dir).mkdir(parents=True, exist_ok=True)

	# Configure CMake if build directory is empty or clean was requested
	configure_cmake(build_dir, args.build_type, True, True)

	# Build the specified target
	execute_cmake_build(build_dir, args.target, args.build_type, True)

	write_color_output(f"Build completed successfully for target: {args.target}", Fore.GREEN)
	write_color_output(f"Output directory: {output_dir}", Fore.GREEN)

if __name__ == "__main__":
	# make sure the current directory is the script's directory
	os.chdir(os.path.dirname(os.path.abspath(__file__)))
	main() 