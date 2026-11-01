#Requires -Version 5.1
<#
.SYNOPSIS
  mission-ledger-append (A-120 / C7) -- append ONE schema-valid, CRLF-terminated, append-only,
  valid-JSON entry to .mission/ledger/entries.jsonl.

.DESCRIPTION
  Scaffold-not-author: the operator supplies the entry CONTENT (the prose, via -ContentFile) + the
  id/type/scope/tags; this command scaffolds the envelope (created_at/ts/author/source_trace_id/
  supersedes), enforces the schema shape + CRLF + append-only (A-120/A-125), and atomically commits.
  The invariants are inherited from mission-lib.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Id,
    [Parameter(Mandatory)][ValidateSet('decision','correction','constraint','gotcha','lesson','runtime')][string]$Type,
    [Parameter(Mandatory)][ValidateSet('product','framework','global')][string]$Scope,
    [Parameter(Mandatory)][string]$ContentFile,     # operator-authored content (prose is NOT machine-authored)
    [string]$ScopeRef = $null,
    [string[]]$Tags = @(),
    [string]$Author = 'claude-code:orchestrator-guide',
    [string[]]$Supersedes = @(),                       # F-036/M-16: array so ONE entry can supersede several (the A-166 suite_id backfill supersedes 2 legacy baseline-records per suite)
    [string]$SuiteId = $null,                          # F-036/M-16 (A-168/A-164): the structured suite_id field on green-gate baseline-records -- A-147 selects on THIS, not a scope tag
    [switch]$NoCommit                                 # M-11 callers bundle; default commits as one unit
)

. (Join-Path $PSScriptRoot 'mission-lib.ps1')
$root = Get-MissionRoot

if (-not (Test-Path $ContentFile)) { Stop-WithError "content file not found: $ContentFile" }
if (-not $NoCommit) { Assert-CleanWorkingTree -Root $root }   # A-126

$content = [System.IO.File]::ReadAllText($ContentFile)
$ts = Get-UtcStamp
$entry = [ordered]@{
    id              = $Id
    created_at      = $ts
    created_by      = $Author
    ts              = $ts
    author          = $Author
    type            = $Type
    scope           = $Scope
    scope_ref       = $ScopeRef
    content         = $content
    source_trace_id = $null
    supersedes      = $(if ($Supersedes.Count) { $Supersedes } else { $null })
    tags            = $Tags
}
# F-036/M-16 (A-168/A-164): carry the structured suite_id FIELD (after scope_ref) so the A-147 matcher
# selects baseline-records on it, NOT on the overloaded ADR-028 'framework' scope tag. Omitted on
# non-suite entries -- no suite_id:null pollution of the generic append. Round-trips intact (A-168).
if ($SuiteId) { $entry.Insert(8, 'suite_id', $SuiteId) }

Add-LedgerEntry -Root $root -Entry $entry           # A-120/A-125: CRLF + append-only + valid JSON

if (-not $NoCommit) {
    $body = "ledger: $Id`r`n`r`nAppend a $Type/$Scope ledger entry ($Id).`r`n"
    $msg = New-CommitMessageFile -Root $root -Body $body
    Invoke-AtomicCommit -Root $root -Paths @('.mission/ledger/entries.jsonl') -MessageFile $msg | Out-Null
}
Write-Host "mission ledger-append: done ($Id)" -ForegroundColor Cyan
