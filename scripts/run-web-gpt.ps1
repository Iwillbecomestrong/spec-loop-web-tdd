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

if (-not $AgentChatRoot) { $AgentChatRoot = 'E:\ai-toolkit\skills\AgentChat' }
$resolvedPrompt = (Resolve-Path -LiteralPath $PromptPath -ErrorAction Stop).Path
$cli = Join-Path $AgentChatRoot 'wrappers\gpt-web\cli.js'
if (-not (Test-Path -LiteralPath $cli -PathType Leaf)) {
    throw "AgentChat gpt-web CLI not found: $cli. Set AGENTCHAT_ROOT or pass -AgentChatRoot."
}
$node = Get-Command node -ErrorAction Stop
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path (Get-Location).Path $OutputPath }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutput) | Out-Null
$stderrPath = "$resolvedOutput.stderr.log"

$stdoutLines = Get-Content -Raw -LiteralPath $resolvedPrompt | & $node.Source $cli ask -e $Effort 2> $stderrPath
$exitCode = $LASTEXITCODE
$stdout = ($stdoutLines -join "`n").Trim()
if ($exitCode -ne 0) { throw "gpt-web failed with exit code $exitCode. See $stderrPath" }
if (-not $stdout) { throw "gpt-web returned no response. See $stderrPath" }

if ($ValidateReviewContract) {
    $candidatePath = "$resolvedOutput.contract-check.tmp"
    try {
        Set-Content -LiteralPath $candidatePath -Value $stdout -Encoding utf8
        & (Join-Path $PSScriptRoot 'validate-review-output.ps1') -ResponsePath $candidatePath | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Review output contract validation failed. See $candidatePath" }
    } finally {
        if (Test-Path -LiteralPath $candidatePath) { Remove-Item -LiteralPath $candidatePath -Force }
    }
}

Set-Content -LiteralPath $resolvedOutput -Value $stdout -Encoding utf8
Write-Output $resolvedOutput
