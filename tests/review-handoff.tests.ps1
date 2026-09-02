[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$handoffScript = Join-Path $pluginRoot 'scripts/prepare-review-handoff.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('spec-loop-review-handoff-' + [guid]::NewGuid().ToString('N'))

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Invoke-Handoff([hashtable]$Arguments) {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $handoffScript @Arguments 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Review handoff exited with code $LASTEXITCODE." }
}

function Invoke-HandoffExpectFailure([hashtable]$Arguments) {
    try {
        Invoke-Handoff $Arguments
    } catch {
        return
    }
    throw 'ASSERTION FAILED: expected review handoff generation to fail.'
}

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
try {
    & git -C $tempRoot init --quiet
    & git -C $tempRoot config user.email 'test@example.invalid'
    & git -C $tempRoot config user.name 'Spec Loop Tests'

    New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot 'docs/specs') | Out-Null
    Set-Content -LiteralPath (Join-Path $tempRoot 'docs/specs/test.md') -Value '# Test SPEC' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $tempRoot 'tracked.txt') -Value 'base' -Encoding utf8
    & git -C $tempRoot add .
    & git -C $tempRoot commit --quiet -m base
    $base = (& git -C $tempRoot rev-parse HEAD).Trim()
    & git -C $tempRoot remote add origin https://github.com/example/test.git

    Set-Content -LiteralPath (Join-Path $tempRoot 'tracked.txt') -Value 'changed' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $tempRoot 'second.txt') -Value 'added' -Encoding utf8
    & git -C $tempRoot add .
    & git -C $tempRoot commit --quiet -m target
    $target = (& git -C $tempRoot rev-parse HEAD).Trim()

    $fullOutput = Join-Path $tempRoot 'full-review.txt'
    Invoke-Handoff @{
        SpecPath = 'docs/specs/test.md'
        ProjectPath = $tempRoot
        BaseCommit = $base
        TargetCommit = $target
        OutputPath = $fullOutput
    }
    $fullText = Get-Content -Raw $fullOutput
    Assert-True ($fullText.Contains('REVIEW_SCOPE: COMPLETE')) 'full diffs must declare complete review scope.'
    Assert-True ($fullText.Contains('tracked.txt') -and $fullText.Contains('second.txt')) 'full diffs must include every changed file.'
    Assert-True ($fullText.Contains('REVIEW OUTPUT CONTRACT')) 'review handoffs must declare an output contract.'
    Assert-True ($fullText.Contains('REPOSITORY_VERIFIED: YES/NO')) 'review handoffs must require repository attestation.'
    Assert-True ($fullText.Contains('- Severity: BLOCKER | MAJOR | MINOR | INFO')) 'review handoffs must define stable finding severity values.'
    Assert-True ($fullText.Contains('NO_FINDINGS: YES')) 'review handoffs must define the no-findings sentinel.'

    Invoke-HandoffExpectFailure @{
        SpecPath = 'docs/specs/test.md'
        ProjectPath = $tempRoot
        BaseCommit = $base
        TargetCommit = $target
        DiffPaths = @('tracked.txt')
        OutputPath = (Join-Path $tempRoot 'rejected-review.txt')
    }

    $scopedOutput = Join-Path $tempRoot 'scoped-review.txt'
    Invoke-Handoff @{
        SpecPath = 'docs/specs/test.md'
        ProjectPath = $tempRoot
        BaseCommit = $base
        TargetCommit = $target
        DiffPaths = @('tracked.txt')
        AllowPartialDiff = $true
        OutputPath = $scopedOutput
    }
    $scopedText = Get-Content -Raw $scopedOutput
    Assert-True ($scopedText.Contains('REVIEW_SCOPE: SCOPED')) 'partial diffs must declare scoped review.'
    Assert-True ($scopedText.Contains('second.txt')) 'partial diffs must list omitted changed files.'

    Invoke-HandoffExpectFailure @{
        SpecPath = 'docs/specs/test.md'
        ProjectPath = $tempRoot
        OutputPath = (Join-Path $tempRoot 'no-evidence-review.txt')
    }

    Write-Output 'PASS: review handoff scope tests'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
