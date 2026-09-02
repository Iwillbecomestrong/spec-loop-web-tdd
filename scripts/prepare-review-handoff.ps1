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
    [string[]]$DiffPaths = @()
)

$resolvedProject = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
$resolvedSpec = (Resolve-Path -LiteralPath (Join-Path $resolvedProject $SpecPath) -ErrorAction Stop).Path
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $resolvedProject $OutputPath }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutput) | Out-Null
$modeJson = & (Join-Path $PSScriptRoot 'detect-repository-mode.ps1') -ProjectPath $resolvedProject
$sections = [System.Collections.Generic.List[string]]::new()
$seen = @{}

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

$git = Get-Command git -ErrorAction SilentlyContinue
if ($git -and $BaseCommit -and $TargetCommit) {
    $diffArgs = @('diff', '--no-ext-diff', '--unified=80', $BaseCommit, $TargetCommit)
    if ($DiffPaths.Count -gt 0) { $diffArgs += '--'; $diffArgs += $DiffPaths }
    $diff = (& $git.Source -C $resolvedProject @diffArgs 2>$null) -join "`n"
    if ($LASTEXITCODE -eq 0 -and $diff) {
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
