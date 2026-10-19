# Opens the editor with the Unreal MCP server on http://127.0.0.1:8000/mcp.
param([string]$Map = '')
. "$PSScriptRoot\common.ps1"
Require $Editor 'UnrealEditor.exe'; Require $Project 'Project'
$args = @($Project)
if ($Map) { $args += $Map }
$args += '-ModelContextProtocolStartServer', '-ModelContextProtocolPort=8000', '-log'
Start-Process $Editor -ArgumentList $args
Write-Output "Editor starting; MCP at http://127.0.0.1:8000/mcp"
