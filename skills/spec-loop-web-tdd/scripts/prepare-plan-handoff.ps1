[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SpecPath,
    [string]$UserRequest,
    [string]$UserRequestFile,
    [string]$ProjectPath = (Get-Location).Path,
    [string]$OutputPath = 'docs/work/plan-prompt.txt',
    [string[]]$ContextFiles = @()
)

$pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$target = Join-Path $pluginRoot 'scripts\prepare-plan-handoff.ps1'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw "Spec-loop plugin scripts are unavailable at $target. Install the complete plugin package, not only its skills."
}
& $target @PSBoundParameters
exit $LASTEXITCODE
