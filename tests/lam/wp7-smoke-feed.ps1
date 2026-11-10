#Requires -Version 5.1
<#
.SYNOPSIS
  wp7-smoke-feed -- WP-7's replay of the smoke mission as a feed (UI-2 S2, group B; contract B-1, B-4, B-8).

.DESCRIPTION
  The smoke mission (tools\lam\build-smoke-mission.ps1) carries no feed: its builder installs no hook and registers no
  stream, and its validator results were written by the builder, never transcribed. The dashboard reads only a feed
  (ADR-045 principle 1), and the one writer that reads the mission's artifacts into it is the snapshot writer. So this
  replays THAT writer over the mission's own history: for each first-parent commit of -SmokeRoot, oldest first, the
  commit's .mission tree (and framework.lock, where the commit holds one) is extracted to a scratch folder named as the
  checkout is, -Framework's Get-MissionSnapshotState derives the state, and one mission_snapshot line is written when
  the state's canonical hash moved -- the writer's own rule -- stamped with the commit's AUTHOR date (the builder fixes
  every author date; c9's committer date is the build's clock) and the commit's id. seq runs from 1. The milestones'
  started_ts / done_ts stay null: they are the writer's observation times, which a replay does not have.

  The line is composed here as the emitter composes it (schema_version 1.2, the emitter's key order, ConvertTo-Json
  -Compress -Depth 12): source_path .mission/mission.yaml, sha256 that file's bytes at the commit. Nothing is written
  under -SmokeRoot. Prints one JSON object: {out, lines, commits, mission_id, seqs: [{seq, commit, ts}]}.

  -Tree <dir> instead replays nothing: ONE mission_snapshot of the mission folder <dir> as it stands (a scratch copy a
  member has planted), ts 2026-01-02T00:00:00.000Z, commit null.

  -Framework is the tree whose writer is replayed (default: the checkout this file sits in) -- a member reads the RED
  by pointing it at the base tree.
#>
[CmdletBinding()]
param(
    [string]$SmokeRoot,
    [string]$Tree,
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Framework,
    [string]$HostId = '00000000-0000-4000-8000-0000000000b1'
)
$ErrorActionPreference = 'Stop'
if (-not $Framework) { $Framework = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $Framework 'tools\lam\mission-telemetry.ps1')
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$sha = { param([byte[]]$B) $h = [System.Security.Cryptography.SHA256]::Create(); try { -join ($h.ComputeHash($B) | ForEach-Object { $_.ToString('x2') }) } finally { $h.Dispose() } }
$git = { param([string[]]$A) $o = @(& git -C $SmokeRoot @A 2>$null); if ($LASTEXITCODE -ne 0) { throw "git $($A -join ' ') exit $LASTEXITCODE" }; return $o }

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('w7sf' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $work -Force
if (-not $SmokeRoot -and -not $Tree) { throw 'name -SmokeRoot or -Tree' }
$leaf = if ($SmokeRoot) { Split-Path -Leaf ([System.IO.Path]::GetFullPath($SmokeRoot).TrimEnd('\', '/')) } else { '' }
$lines = New-Object System.Collections.Generic.List[string]
$seqs = @()
$last = ''
$missionId = $null
try {
    $commits = @(if ($Tree) { 'tree' } else { & $git @('rev-list', '--first-parent', '--reverse', 'HEAD') })
    $n = 0
    foreach ($c in $commits) {
      if ($Tree) { $dir = [System.IO.Path]::GetFullPath($Tree); $ts = '2026-01-02T00:00:00.000Z' } else {
        $n++
        $dir = Join-Path (Join-Path $work ('c{0:00}' -f $n)) $leaf
        $null = New-Item -ItemType Directory -Path $dir -Force
        $tar = Join-Path $work ('c{0:00}.tar' -f $n)
        $paths = @('.mission')
        if (@(& $git @('ls-tree', '--name-only', $c, 'framework.lock')).Count) { $paths += 'framework.lock' }
        $null = & $git (@('archive', '-o', $tar, $c) + $paths)
        & tar.exe -xf $tar -C $dir
        if ($LASTEXITCODE -ne 0) { throw "tar exit $LASTEXITCODE on $tar" }
        $ad = ([string](@(& $git @('log', '-1', '--format=%aI', $c))[0])).Trim()
        $ts = ([DateTimeOffset]::Parse($ad, $inv)).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', $inv)
      }
        $state = Get-MissionSnapshotState -Root $dir
        $h = & $sha ((New-Object System.Text.UTF8Encoding($false)).GetBytes((ConvertTo-MissionCanonicalJson $state)))
        if ($h -ceq $last) { continue }
        $last = $h
        $state['snapshot_sha256'] = $h
        if (-not $missionId) { $missionId = Get-MissionTelemetryYamlScalar -Text ([System.IO.File]::ReadAllText((Join-Path $dir '.mission\mission.yaml'))) -Key 'id' }
        $seq = $seqs.Count + 1
        $line = [ordered]@{
            schema_version = '1.2'; mission_id = $missionId; host_id = $HostId; seq = $seq; ts = $ts; kind = 'mission_snapshot'
            payload = $state; source_path = '.mission/mission.yaml'
            sha256 = (& $sha ([System.IO.File]::ReadAllBytes((Join-Path $dir '.mission\mission.yaml')))); commit = $(if ($Tree) { $null } else { $c })
        }
        $lines.Add(($line | ConvertTo-Json -Compress -Depth 12))
        $seqs += [ordered]@{ seq = $seq; commit = $(if ($Tree) { $null } else { $c }); ts = $ts }
    }
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent ([System.IO.Path]::GetFullPath($Out))) -Force
    [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($Out), (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    [ordered]@{ out = [System.IO.Path]::GetFullPath($Out); lines = $lines.Count; commits = $commits.Count; mission_id = $missionId; seqs = $seqs } | ConvertTo-Json -Compress -Depth 5
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
