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
    [switch]$AllowPartialDiff
)

$resolvedProject = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
$resolvedSpec = (Resolve-Path -LiteralPath (Join-Path $resolvedProject $SpecPath) -ErrorAction Stop).Path
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $resolvedProject $OutputPath }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutput) | Out-Null
$modeJson = & (Join-Path $PSScriptRoot 'detect-repository-mode.ps1') -ProjectPath $resolvedProject
$sections = [System.Collections.Generic.List[string]]::new()
$seen = @{}
$git = Get-Command git -ErrorAction SilentlyContinue
$hasGitEvidence = [bool]($git -and $BaseCommit -and $TargetCommit)
$hasSnapshotEvidence = [bool]($BeforeSnapshot -or $AfterSnapshot)

if (-not $hasGitEvidence -and -not $hasSnapshotEvidence) {
    throw 'Review evidence is required: provide BaseCommit and TargetCommit, or a before/after snapshot.'
}

function Add-Section([string]$Title, [string]$Body) {
    if ($Body) { $sections.Add("## $Title`n`n$($Body.Trim())") }
}

function Add-FileSection([string]$Path, [string]$Title = $null) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $full = (Resolve-Path -LiteralPath $Path).Path
    if ($seen.ContainsKey($full)) { return }
    $seen[$full] = $true
    $relative = [IO.Path]::GetRelativePath($resolvedProject, $full)
    $heading = if ($Title) { $Title } else { "File: $relative" }
    Add-Section $heading "~~~text`n$(Get-Content -Raw -LiteralPath $full)`n~~~"
}

Add-Section 'Review instruction' @'
Review the implementation against the confirmed SPEC and the exact change evidence below.
Check SPEC compliance, plan consistency, local README contracts, regressions, edge cases, test adequacy, documentation sync, and scope creep.
Return findings with severity, file/location, evidence, and a concrete fix recommendation. Distinguish blockers from minors.
The response will be captured verbatim to docs/work/review-<target>.md.
'@
Add-Section 'Repository mode' $modeJson
Add-Section 'User request' $UserRequest
Add-FileSection $resolvedSpec 'Confirmed SPEC'

if ($hasGitEvidence) {
    $allChangedArgs = @('diff', '--name-only', '--no-ext-diff', $BaseCommit, $TargetCommit)
    $allChangedFiles = @((& $git.Source -C $resolvedProject @allChangedArgs 2>$null) | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })
    if ($LASTEXITCODE -ne 0) { throw "Unable to enumerate changed files for $BaseCommit..$TargetCommit." }

    $includedChangedFiles = $allChangedFiles
    if ($DiffPaths.Count -gt 0) {
        $scopedArgs = @('diff', '--name-only', '--no-ext-diff', $BaseCommit, $TargetCommit, '--') + $DiffPaths
        $includedChangedFiles = @((& $git.Source -C $resolvedProject @scopedArgs 2>$null) | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })
        if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate the requested review paths.' }
    }

    $includedSet = @{}
    foreach ($path in $includedChangedFiles) { $includedSet[$path.Replace('\', '/')] = $true }
    $omittedChangedFiles = @($allChangedFiles | Where-Object { -not $includedSet.ContainsKey($_.Replace('\', '/')) })
    if ($omittedChangedFiles.Count -gt 0 -and -not $AllowPartialDiff) {
        throw "DiffPaths omits changed files: $($omittedChangedFiles -join ', '). Re-run without DiffPaths or explicitly pass -AllowPartialDiff."
    }

    $reviewScope = if ($omittedChangedFiles.Count -gt 0) { 'SCOPED' } else { 'COMPLETE' }
    $scopeLines = @(
        "REVIEW_SCOPE: $reviewScope"
        "ALL_CHANGED_FILES:"
        $(if ($allChangedFiles.Count) { $allChangedFiles -join "`n" } else { '(none)' })
        "INCLUDED_CHANGED_FILES:"
        $(if ($includedChangedFiles.Count) { $includedChangedFiles -join "`n" } else { '(none)' })
        "OMITTED_CHANGED_FILES:"
        $(if ($omittedChangedFiles.Count) { $omittedChangedFiles -join "`n" } else { '(none)' })
    )
    if ($reviewScope -eq 'SCOPED') {
        $scopeLines += 'WARNING: This handoff is an explicitly allowed partial review; omitted changed files are outside the supplied diff and must not be treated as reviewed.'
    }
    Add-Section 'Review scope' ($scopeLines -join "`n")

    $diffArgs = @('diff', '--no-ext-diff', '--unified=80', $BaseCommit, $TargetCommit)
    if ($DiffPaths.Count -gt 0) { $diffArgs += '--'; $diffArgs += $DiffPaths }
    $diff = (& $git.Source -C $resolvedProject @diffArgs 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Unable to read diff for $BaseCommit..$TargetCommit." }
    if ($allChangedFiles.Count -gt 0) {
        Add-Section "Change diff ($BaseCommit..$TargetCommit)" "~~~diff`n$diff`n~~~"
    }
}

if ($BeforeSnapshot -or $AfterSnapshot) {
    Add-Section 'No-Git snapshot protocol' 'Compare the corresponding files in the before and after snapshots. Treat only files included in the snapshots or context list as in scope.'
    if ($BeforeSnapshot) { Add-Section 'Before snapshot manifest' ((Get-ChildItem -File -Recurse -LiteralPath (Join-Path $resolvedProject $BeforeSnapshot) | ForEach-Object { [IO.Path]::GetRelativePath($resolvedProject, $_.FullName) }) -join "`n") }
    if ($AfterSnapshot) { Add-Section 'After snapshot manifest' ((Get-ChildItem -File -Recurse -LiteralPath (Join-Path $resolvedProject $AfterSnapshot) | ForEach-Object { [IO.Path]::GetRelativePath($resolvedProject, $_.FullName) }) -join "`n") }
}

foreach ($path in $ContextFiles) { Add-FileSection (Join-Path $resolvedProject $path) }

$header = "SPEC-LOOP WEB REVIEW HANDOFF`nGenerated: $([DateTime]::UtcNow.ToString('o'))`nProject: $resolvedProject`n"
Set-Content -LiteralPath $resolvedOutput -Value ($header + "`n" + ($sections -join "`n`n")) -Encoding utf8
Write-Output $resolvedOutput
