[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PromptPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [string]$AgentChatRoot = $env:AGENTCHAT_ROOT,
    [ValidateSet('medium', 'high', 'xhigh', 'pro')]
    [string]$Effort = 'high',
    [switch]$ValidateReviewContract
)

$pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$target = Join-Path $pluginRoot 'scripts\run-web-gpt.ps1'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw "Spec-loop plugin scripts are unavailable at $target. Install the complete plugin package, not only its skills."
}
& pwsh -NoProfile -ExecutionPolicy Bypass -File $target @PSBoundParameters
exit $LASTEXITCODE
