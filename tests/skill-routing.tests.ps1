[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$mainSkill = Get-Content -Raw (Join-Path $pluginRoot 'skills/spec-loop-web-tdd/SKILL.md')
$readme = Get-Content -Raw (Join-Path $pluginRoot 'README.md')
$grillDocs = Get-Content -Raw (Join-Path $pluginRoot 'docs/grill-me-integration.md')

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

Assert-True ($mainSkill.Contains('Capability discovery and optional skill routing')) 'main skill must define optional skill discovery.'
Assert-True ($mainSkill.Contains('superpowers:brainstorming')) 'main skill must prefer an existing superpowers brainstorming skill.'
Assert-True ($mainSkill.Contains('superpowers:systematic-debugging')) 'main skill must prefer an existing superpowers debugging skill.'
Assert-True ($mainSkill.Contains('grill-me')) 'main skill must route to standalone grill-me.'
Assert-True ($mainSkill.Contains('do not install')) 'main skill must prohibit duplicate installation when a capability is already available.'
Assert-True ($mainSkill.Contains('brainstorming -> grill-me')) 'main skill must document the composable brainstorming then grill-me route.'

foreach ($name in @('brainstorming', 'systematic-debugging', 'grill-me')) {
    $path = Join-Path $pluginRoot "skills/$name/SKILL.md"
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "plugin must ship a $name fallback entry skill."
    $skill = Get-Content -Raw $path
    Assert-True ($skill -match '(?i)do not install') "$name fallback must avoid duplicate installation."
}

Assert-True ($grillDocs.Contains('available skills') -and $grillDocs.Contains('skill ID') -and $grillDocs.Contains('source path/connection')) 'Grill-Me integration must explain reuse and connection reporting.'
Assert-True ($readme.Contains('Optional skill routing')) 'README must document optional skill routing.'

Write-Output 'PASS: optional skill routing tests'
