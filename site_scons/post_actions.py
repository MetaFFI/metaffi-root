import sys
import subprocess
import SCons.Node
import SCons.Node.FS

def execute_unitest(target, source, env):

	def execute(cmd: str, cwd: str|None = None) -> int|None:
		print(f'Executing: {cmd}')
		process = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd)
		print(process.stdout.decode())
		print(process.stderr.decode(), file=sys.stderr)

		return process.returncode

	if isinstance(target, list):
		target = target[0]

	if isinstance(target, SCons.Node.NodeList):
		target = target[0]

	if isinstance(target, SCons.Node.FS.File):
		target = str(target)

	exit_code = execute(target)
	if exit_code != 0:
		print(f"'{target}' - Failed with exit code {exit_code}", file=sys.stderr)
		env.Exit(1)
		
	
def execute_go_unitest(target, source, env):
	def execute() -> int|None:
		print(f'Executing: go test -v')
		process = subprocess.run(f'go test -v', shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		print(process.stdout.decode())
		print(process.stderr.decode(), file=sys.stderr)

		return process.returncode

	exit_code = execute()
	if exit_code != 0:
		print(f"'{target}' - Failed with exit code {exit_code}", file=sys.stderr)
		env.Exit(1)

