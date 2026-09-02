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
if ($findings -match '(?m)^NO_FINDINGS: YES\s*$') {
    Write-Output 'VALID: review output contract (no findings)'
    return
}

$severityMatches = [regex]::Matches($findings, '(?m)^- Severity: (.+?)\s*$')
if ($severityMatches.Count -eq 0) { throw 'Findings must contain a Severity field or NO_FINDINGS: YES.' }
$allowedSeverities = @('BLOCKER', 'MAJOR', 'MINOR', 'INFO')
foreach ($match in $severityMatches) {
    if ($allowedSeverities -notcontains $match.Groups[1].Value.Trim()) {
        throw "Invalid finding severity: $($match.Groups[1].Value.Trim())."
    }
}

foreach ($field in @('File', 'Location', 'Evidence', 'Reason', 'Recommended Fix')) {
    if ($findings -notmatch "(?m)^- $([regex]::Escape($field)): .+") {
        throw "Findings must contain a non-empty $field field."
    }
}

Write-Output 'VALID: review output contract (findings present)'
