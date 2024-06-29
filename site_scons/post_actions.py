import sys
import subprocess
import SCons.Node
import SCons.Node.FS
from colorama import Fore
import os

def execute_doctest_unitest(target, source, env):
	
	target_to_print = target
	
	if isinstance(target_to_print, list):
		target_to_print = target_to_print[0]
	
	if isinstance(target_to_print, SCons.Node.FS.File):
		print(f'Executing doctest: {target_to_print.abspath}')
	else:
		print(f'Executing doctest: {target_to_print}')
		
	env.Execute(target)
		
	
def execute_go_unitest(target, source, env):
	print(f'Executing Go Test: {os.getcwd()}')
	env.Execute('go mod tidy')
	env.Execute('go test -v')

