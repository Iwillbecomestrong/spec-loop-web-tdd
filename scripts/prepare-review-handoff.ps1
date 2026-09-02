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

$resolvedProject = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
$resolvedSpec = (Resolve-Path -LiteralPath (Join-Path $resolvedProject $SpecPath) -ErrorAction Stop).Path
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $resolvedProject $OutputPath }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutput) | Out-Null
$modeJson = & (Join-Path $PSScriptRoot 'detect-repository-mode.ps1') -ProjectPath $resolvedProject
$sections = [System.Collections.Generic.List[string]]::new()
$seen = @{}
$git = Get-Command git -ErrorAction SilentlyContinue
$hasGitEvidence = [bool]($git -and $BaseCommit -and $TargetCommit)
$hasBeforeSnapshot = [bool]$BeforeSnapshot
$hasAfterSnapshot = [bool]$AfterSnapshot
$hasSnapshotEvidence = [bool]($hasBeforeSnapshot -and $hasAfterSnapshot)

if ($hasBeforeSnapshot -xor $hasAfterSnapshot) {
    throw 'No-Git review requires both BeforeSnapshot and AfterSnapshot for comparison.'
}

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

function Get-SnapshotFiles([string]$RelativePath) {
    $root = Join-Path $resolvedProject $RelativePath
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Snapshot directory not found: $root"
    }
    $files = @{}
    foreach ($file in (Get-ChildItem -File -Recurse -LiteralPath $root | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
        $files[$relative] = $file
    }
    return $files
}

function Read-SnapshotFile($File) {
    if ($File.Length -gt $MaxSnapshotBytes) {
        return [pscustomobject]@{ kind = 'OMITTED (size limit)'; text = $null; bytes = $File.Length }
    }
    $bytes = [IO.File]::ReadAllBytes($File.FullName)
    if ($bytes -contains [byte]0) {
        return [pscustomobject]@{ kind = 'BINARY (content omitted)'; text = $null; bytes = $bytes.Length }
    }
    try {
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    } catch {
        return [pscustomobject]@{ kind = 'BINARY (content omitted)'; text = $null; bytes = $bytes.Length }
    }
    return [pscustomobject]@{ kind = 'TEXT'; text = $text; bytes = $bytes.Length }
}

Add-Section 'Review instruction' @'
Review the implementation against the confirmed SPEC and the exact change evidence below.
Check SPEC compliance, plan consistency, local README contracts, regressions, edge cases, test adequacy, documentation sync, and scope creep.
Return findings with severity, file/location, evidence, and a concrete fix recommendation. Distinguish blockers from minors.
The response will be captured verbatim to docs/work/review-<target>.md.

REVIEW OUTPUT CONTRACT
The response MUST begin with these attestation lines, using only YES or NO:
REPOSITORY_VERIFIED: YES/NO
BASE_COMMIT_VERIFIED: YES/NO
TARGET_COMMIT_VERIFIED: YES/NO
SPEC_VERIFIED: YES/NO

Then provide:
## Findings
For each finding, include exactly these labeled fields:
- Severity: BLOCKER | MAJOR | MINOR | INFO
- File:
- Location:
- Evidence:
- Reason:
- Recommended Fix:

If no findings exist, include the fixed sentinel `NO_FINDINGS: YES` under `## Findings`.
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
    Add-Section 'No-Git snapshot protocol' "Compare paired before and after snapshots. The handoff embeds bounded text contents, marks added/deleted/unchanged/modified files, and explicitly marks binary or size-limited content omissions. Snapshot content is limited to $MaxSnapshotBytes bytes per file and in total. Treat only files included in the snapshots or context list as in scope."
    $beforeFiles = Get-SnapshotFiles $BeforeSnapshot
    $afterFiles = Get-SnapshotFiles $AfterSnapshot
    $snapshotPaths = @($beforeFiles.Keys + $afterFiles.Keys | Sort-Object -Unique)
    $manifestLines = [System.Collections.Generic.List[string]]::new()
    $contentSections = [System.Collections.Generic.List[string]]::new()
    $contentBytesUsed = 0
    foreach ($relative in $snapshotPaths) {
        $beforeFile = $beforeFiles[$relative]
        $afterFile = $afterFiles[$relative]
        $beforeRecord = if ($beforeFile) { Read-SnapshotFile $beforeFile } else { [pscustomobject]@{ kind = 'ABSENT'; text = $null; bytes = 0 } }
        $afterRecord = if ($afterFile) { Read-SnapshotFile $afterFile } else { [pscustomobject]@{ kind = 'ABSENT'; text = $null; bytes = 0 } }
        $status = if (-not $beforeFile) { 'ADDED' } elseif (-not $afterFile) { 'DELETED' } elseif ($beforeRecord.text -eq $afterRecord.text -and $beforeRecord.kind -eq 'TEXT' -and $afterRecord.kind -eq 'TEXT') { 'UNCHANGED' } else { 'MODIFIED' }
        $omission = @(@($beforeRecord.kind, $afterRecord.kind) | Where-Object { $_ -in @('BINARY (content omitted)', 'OMITTED (size limit)') })
        $neededBytes = if ($beforeRecord.kind -eq 'TEXT') { $beforeRecord.bytes } else { 0 }
        $neededBytes += if ($afterRecord.kind -eq 'TEXT') { $afterRecord.bytes } else { 0 }
        if ($omission.Count -eq 0 -and $contentBytesUsed + $neededBytes -gt $MaxSnapshotBytes) {
            $omission = @('OMITTED (size limit)')
        }
        if ($omission.Count -gt 0) {
            $status = "$status; $($omission -join ', ')"
            $beforeText = if ($beforeFile) { "($($beforeRecord.kind))" } else { '(absent)' }
            $afterText = if ($afterFile) { "($($afterRecord.kind))" } else { '(absent)' }
        } else {
            $contentBytesUsed += $neededBytes
            $beforeText = if ($beforeFile) { $beforeRecord.text } else { '(absent)' }
            $afterText = if ($afterFile) { $afterRecord.text } else { '(absent)' }
        }
        $manifestLines.Add("$status`t$relative`tbefore_bytes=$($beforeRecord.bytes)`tafter_bytes=$($afterRecord.bytes)")
        $contentSections.Add("### $status - $relative`nBefore:`n~~~text`n$beforeText`n~~~`nAfter:`n~~~text`n$afterText`n~~~")
    }
    Add-Section 'Before/after snapshot manifest' ("SNAPSHOT_MAX_BYTES: $MaxSnapshotBytes`nCONTENT_BYTES_INCLUDED: $contentBytesUsed`n" + ($manifestLines -join "`n"))
    Add-Section 'Before/after snapshot contents' ($contentSections -join "`n`n")
}

foreach ($path in $ContextFiles) { Add-FileSection (Join-Path $resolvedProject $path) }

$header = "SPEC-LOOP WEB REVIEW HANDOFF`nGenerated: $([DateTime]::UtcNow.ToString('o'))`nProject: $resolvedProject`n"
Set-Content -LiteralPath $resolvedOutput -Value ($header + "`n" + ($sections -join "`n`n")) -Encoding utf8
Write-Output $resolvedOutput
