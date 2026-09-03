[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SpecPath,
    [string]$UserRequest,
    [string]$ProjectPath = (Get-Location).Path,
    [string]$BaseCommit,
    [string]$TargetCommit,
    [string]$BeforeSnapshot,
    [string]$AfterSnapshot,
    [string]$OutputPath = 'docs/work/review-prompt.txt',
    [string[]]$ContextFiles = @(),
    [string[]]$DiffPaths = @(),
    [switch]$AllowPartialDiff,
    [ValidateRange(1, 104857600)]
    [int]$MaxSnapshotBytes = 1048576
)

$pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$target = Join-Path $pluginRoot 'scripts\prepare-review-handoff.ps1'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw "Spec-loop plugin scripts are unavailable at $target. Install the complete plugin package, not only its skills."
}
& pwsh -NoProfile -ExecutionPolicy Bypass -File $target @PSBoundParameters
exit $LASTEXITCODE
