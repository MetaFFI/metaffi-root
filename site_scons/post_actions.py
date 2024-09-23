import sys
import subprocess
import SCons.Node
import SCons.Node.FS
from colorama import Fore
import os
import platform

def execute_doctest_unitest(target, source, env):
	
	# if platform.system() == 'Windows':
	# 	env['ENV']['PATH'] = os.environ['PATH']
	# else:
	# 	env['ENV']['LD_LIBRARY_PATH'] = os.environ['LD_LIBRARY_PATH']

	if isinstance(target, list):
		target = target[0].abspath
	
	if isinstance(target, SCons.Node.FS.File):
		print(f'Executing doctest: ({env.GetLaunchDir()}) {target.abspath}')
	elif isinstance(target, str):
		print(f'Executing doctest: ({env.GetLaunchDir()}) {target}')
	else:
		raise ValueError(f'Unsupported target type: {type(target)}')
	


	exit_code = env.Execute(target)
	if exit_code:
		print(f"doctest unit test failed with exit code {exit_code}", file=sys.stderr)
		sys.exit(1)
		
	
def execute_go_unitest(target, source, env):
	print(f'Executing Go Test: {os.getcwd()}')
	exit_code = env.Execute('go mod tidy')
	if exit_code:
		print(f"Failed 'go mod tidy' with exit code {exit_code}", file=sys.stderr)
		sys.exit(1)

	exit_code = env.Execute('go test -v')
	if exit_code:
		print(f"Go test failed with exit code {exit_code}", file=sys.stderr)
		sys.exit(1)

