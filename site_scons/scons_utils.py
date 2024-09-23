from SCons.Node import NodeList
from SCons.Node.FS import File
import platform

def search_lib_in_nodeslist(nodes: NodeList) -> list | None:
	res = []
	for node in nodes:
		if node.name.endswith('lib'):
			res.append(node.abspath)
	
	if len(res) == 0:
		return None
	else:
		return res
	
def python3_executable(version: str | None = None) -> str:
	# for windows - py
	# else - python3
	
	if version is None:
		return 'py' if platform.system() == 'Windows' else 'python3'
	else:
		return f'py -{version}' if platform.system() == 'Windows' else f'python{version}'

def to_list_of_str_or_str(input) -> str | list[str] | None:
	if input is None:
		return None
	
	if isinstance(input, str):
		return input
	
	if isinstance(input, File):
		return input.abspath
	
	if isinstance(input, list):
		if len(input) == 0:
			return []
		
		if isinstance(input[0], File):
			if len(input) == 1:
				return input[0].abspath
			
			return [f.abspath for f in input]
		if isinstance(input[0], str):
			return input
		
	raise ValueError('Unexpected input type: ' + str(type(input)))
