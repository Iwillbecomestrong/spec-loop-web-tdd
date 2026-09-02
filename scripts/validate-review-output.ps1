[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResponsePath
)

$ErrorActionPreference = 'Stop'
$resolvedResponse = (Resolve-Path -LiteralPath $ResponsePath -ErrorAction Stop).Path
$content = (Get-Content -Raw -LiteralPath $resolvedResponse).TrimStart([char]0xFEFF)
$lines = @($content -split "`r?`n")
$expectedHeaders = @(
    'REPOSITORY_VERIFIED: YES|NO'
    'BASE_COMMIT_VERIFIED: YES|NO'
    'TARGET_COMMIT_VERIFIED: YES|NO'
    'SPEC_VERIFIED: YES|NO'
)

if ($lines.Count -lt $expectedHeaders.Count) {
    throw 'Review output is missing the required four-line attestation header.'
}
for ($index = 0; $index -lt $expectedHeaders.Count; $index++) {
    if ($lines[$index] -notmatch "^$($expectedHeaders[$index])$") {
        throw "Invalid attestation header at line $($index + 1)."
    }
}

$findingsIndex = -1
for ($index = $expectedHeaders.Count; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match '^## Findings\s*$') {
        $findingsIndex = $index
        break
    }
}
if ($findingsIndex -lt 0) { throw 'Review output must contain a ## Findings section.' }

$findings = ($lines[($findingsIndex + 1)..($lines.Count - 1)] -join "`n").Trim()
if ($findings -eq 'NO_FINDINGS: YES') {
    Write-Output 'VALID: review output contract (no findings)'
    return
}
if ($findings -match '(?m)^NO_FINDINGS: YES\s*$') {
    throw 'NO_FINDINGS: YES cannot be combined with findings.'
}

$allowedSeverities = @('BLOCKER', 'MAJOR', 'MINOR', 'INFO')

$severityMatches = [regex]::Matches($findings, '(?m)^- Severity: ')
if ($severityMatches.Count -eq 0) { throw 'Findings must contain a Severity field or NO_FINDINGS: YES.' }
if ($findings.Substring(0, $severityMatches[0].Index).Trim()) {
    throw 'Each finding must begin with a Severity field.'
}

for ($index = 0; $index -lt $severityMatches.Count; $index++) {
    $start = $severityMatches[$index].Index
    $end = if ($index + 1 -lt $severityMatches.Count) { $severityMatches[$index + 1].Index } else { $findings.Length }
    $block = $findings.Substring($start, $end - $start)
    if ($block -notmatch '(?m)^- Severity: (.+?)\s*$') {
        throw 'Each finding must begin with a Severity field.'
    }
    $severity = $Matches[1].Trim()
    if ($allowedSeverities -notcontains $severity) {
        throw "Invalid finding severity: $severity."
    }

    foreach ($field in @('File', 'Location', 'Evidence', 'Reason', 'Recommended Fix')) {
        if ($block -notmatch "(?m)^- $([regex]::Escape($field)): .+") {
            throw "Each finding must contain a non-empty $field field."
        }
    }
}

Write-Output 'VALID: review output contract (findings present)'
