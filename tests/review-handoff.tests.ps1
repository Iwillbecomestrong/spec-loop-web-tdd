[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$handoffScript = Join-Path $pluginRoot 'scripts/prepare-review-handoff.ps1'
$validatorScript = Join-Path $pluginRoot 'scripts/validate-review-output.ps1'
$runnerScript = Join-Path $pluginRoot 'scripts/run-web-gpt.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('spec-loop-review-handoff-' + [guid]::NewGuid().ToString('N'))
$noGitRoot = Join-Path ([IO.Path]::GetTempPath()) ('spec-loop-review-no-git-' + [guid]::NewGuid().ToString('N'))

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

function Invoke-Validator([string]$ResponsePath) {
    $output = @(& pwsh -NoProfile -ExecutionPolicy Bypass -File $validatorScript -ResponsePath $ResponsePath 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Review output validator exited with code ${LASTEXITCODE}: $($output -join ' ')" }
}

function Invoke-ValidatorExpectFailure([string]$ResponsePath) {
    try {
        Invoke-Validator $ResponsePath
    } catch {
        return
    }
    throw "ASSERTION FAILED: expected review output validation to fail for $ResponsePath."
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

    $validResponse = Join-Path $tempRoot 'valid-response.md'
    Set-Content -LiteralPath $validResponse -Value (@(
        'REPOSITORY_VERIFIED: YES'
        'BASE_COMMIT_VERIFIED: YES'
        'TARGET_COMMIT_VERIFIED: YES'
        'SPEC_VERIFIED: YES'
        ''
        '## Findings'
        '- Severity: MINOR'
        '- File: tracked.txt'
        '- Location: line 1'
        '- Evidence: test evidence'
        '- Reason: test reason'
        '- Recommended Fix: test fix'
    ) -join "`n") -Encoding utf8
    Invoke-Validator $validResponse

    $noFindingsResponse = Join-Path $tempRoot 'no-findings-response.md'
    Set-Content -LiteralPath $noFindingsResponse -Value (@(
        'REPOSITORY_VERIFIED: YES'
        'BASE_COMMIT_VERIFIED: YES'
        'TARGET_COMMIT_VERIFIED: YES'
        'SPEC_VERIFIED: YES'
        ''
        '## Findings'
        'NO_FINDINGS: YES'
    ) -join "`n") -Encoding utf8
    Invoke-Validator $noFindingsResponse

    $contradictoryNoFindingsResponse = Join-Path $tempRoot 'contradictory-no-findings-response.md'
    Set-Content -LiteralPath $contradictoryNoFindingsResponse -Value (@(
        'REPOSITORY_VERIFIED: YES'
        'BASE_COMMIT_VERIFIED: YES'
        'TARGET_COMMIT_VERIFIED: YES'
        'SPEC_VERIFIED: YES'
        ''
        '## Findings'
        'NO_FINDINGS: YES'
        ''
        '- Severity: MAJOR'
        '- File: broken.ps1'
        '- Location: line 10'
        '- Evidence: test evidence'
        '- Reason: test reason'
        '- Recommended Fix: test fix'
    ) -join "`n") -Encoding utf8
    Invoke-ValidatorExpectFailure $contradictoryNoFindingsResponse

    $reverseNoFindingsResponse = Join-Path $tempRoot 'reverse-no-findings-response.md'
    Set-Content -LiteralPath $reverseNoFindingsResponse -Value (@(
        'REPOSITORY_VERIFIED: YES'
        'BASE_COMMIT_VERIFIED: YES'
        'TARGET_COMMIT_VERIFIED: YES'
        'SPEC_VERIFIED: YES'
        ''
        '## Findings'
        '- Severity: MAJOR'
        '- File: broken.ps1'
        '- Location: line 10'
        '- Evidence: test evidence'
        '- Reason: test reason'
        '- Recommended Fix: test fix'
        'NO_FINDINGS: YES'
    ) -join "`n") -Encoding utf8
    Invoke-ValidatorExpectFailure $reverseNoFindingsResponse

    $missingHeaderResponse = Join-Path $tempRoot 'missing-header-response.md'
    Set-Content -LiteralPath $missingHeaderResponse -Value '## Findings`nNO_FINDINGS: YES' -Encoding utf8
    Invoke-ValidatorExpectFailure $missingHeaderResponse

    $invalidSeverityResponse = Join-Path $tempRoot 'invalid-severity-response.md'
    Set-Content -LiteralPath $invalidSeverityResponse -Value (@(
        'REPOSITORY_VERIFIED: YES'
        'BASE_COMMIT_VERIFIED: YES'
        'TARGET_COMMIT_VERIFIED: YES'
        'SPEC_VERIFIED: YES'
        ''
        '## Findings'
        '- Severity: URGENT'
        '- File: tracked.txt'
        '- Location: line 1'
        '- Evidence: test evidence'
        '- Reason: test reason'
        '- Recommended Fix: test fix'
    ) -join "`n") -Encoding utf8
    Invoke-ValidatorExpectFailure $invalidSeverityResponse

    $missingFindingsResponse = Join-Path $tempRoot 'missing-findings-response.md'
    Set-Content -LiteralPath $missingFindingsResponse -Value (@(
        'REPOSITORY_VERIFIED: YES'
        'BASE_COMMIT_VERIFIED: YES'
        'TARGET_COMMIT_VERIFIED: YES'
        'SPEC_VERIFIED: YES'
    ) -join "`n") -Encoding utf8
    Invoke-ValidatorExpectFailure $missingFindingsResponse

    $splitFindingResponse = Join-Path $tempRoot 'split-finding-response.md'
    Set-Content -LiteralPath $splitFindingResponse -Value (@(
        'REPOSITORY_VERIFIED: YES'
        'BASE_COMMIT_VERIFIED: YES'
        'TARGET_COMMIT_VERIFIED: YES'
        'SPEC_VERIFIED: YES'
        ''
        '## Findings'
        '- Severity: BLOCKER'
        '- File: first.cs'
        ''
        '- Severity: MAJOR'
        '- Location: line 10'
        '- Evidence: test evidence'
        '- Reason: test reason'
        '- Recommended Fix: test fix'
    ) -join "`n") -Encoding utf8
    Invoke-ValidatorExpectFailure $splitFindingResponse

    $runnerText = Get-Content -Raw -LiteralPath $runnerScript
    Assert-True ($runnerText.Contains('[guid]::NewGuid()')) 'contract-check files must use unique names.'

    New-Item -ItemType Directory -Force -Path (Join-Path $noGitRoot 'docs/specs') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $noGitRoot 'before') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $noGitRoot 'after') | Out-Null
    Set-Content -LiteralPath (Join-Path $noGitRoot 'docs/specs/test.md') -Value '# No-Git SPEC' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $noGitRoot 'before/value.txt') -Value 'before value' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $noGitRoot 'after/value.txt') -Value 'after value' -Encoding utf8

    Invoke-HandoffExpectFailure @{
        SpecPath = 'docs/specs/test.md'
        ProjectPath = $noGitRoot
        BeforeSnapshot = 'before'
        OutputPath = (Join-Path $noGitRoot 'only-before-review.txt')
    }
    Invoke-HandoffExpectFailure @{
        SpecPath = 'docs/specs/test.md'
        ProjectPath = $noGitRoot
        AfterSnapshot = 'after'
        OutputPath = (Join-Path $noGitRoot 'only-after-review.txt')
    }

    Set-Content -LiteralPath (Join-Path $noGitRoot 'before/removed.txt') -Value 'removed value' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $noGitRoot 'after/added.txt') -Value 'added value' -Encoding utf8
    [IO.File]::WriteAllBytes((Join-Path $noGitRoot 'before/binary.bin'), [byte[]](0, 1, 2, 3))
    [IO.File]::WriteAllBytes((Join-Path $noGitRoot 'after/binary.bin'), [byte[]](0, 1, 2, 4))
    $snapshotOutput = Join-Path $noGitRoot 'snapshot-review.txt'
    Invoke-Handoff @{
        SpecPath = 'docs/specs/test.md'
        ProjectPath = $noGitRoot
        BeforeSnapshot = 'before'
        AfterSnapshot = 'after'
        OutputPath = $snapshotOutput
    }
    $snapshotText = Get-Content -Raw $snapshotOutput
    Assert-True ($snapshotText.Contains('before value')) 'No-Git handoffs must include before snapshot contents.'
    Assert-True ($snapshotText.Contains('after value')) 'No-Git handoffs must include after snapshot contents.'
    Assert-True ($snapshotText.Contains('ADDED') -and $snapshotText.Contains('added.txt')) 'No-Git handoffs must mark added files.'
    Assert-True ($snapshotText.Contains('DELETED') -and $snapshotText.Contains('removed.txt')) 'No-Git handoffs must mark deleted files.'
    Assert-True ($snapshotText.Contains('BINARY') -and $snapshotText.Contains('binary.bin')) 'No-Git handoffs must mark binary omissions.'

    $boundedOutput = Join-Path $noGitRoot 'bounded-snapshot-review.txt'
    Invoke-Handoff @{
        SpecPath = 'docs/specs/test.md'
        ProjectPath = $noGitRoot
        BeforeSnapshot = 'before'
        AfterSnapshot = 'after'
        MaxSnapshotBytes = 4
        OutputPath = $boundedOutput
    }
    $boundedText = Get-Content -Raw $boundedOutput
    Assert-True ($boundedText.Contains('OMITTED') -and $boundedText.Contains('size limit')) 'No-Git handoffs must mark size-limited omissions.'

    Write-Output 'PASS: review handoff scope tests'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $noGitRoot) {
        Remove-Item -LiteralPath $noGitRoot -Recurse -Force
    }
}
