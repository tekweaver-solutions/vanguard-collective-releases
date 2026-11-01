#Requires -Version 5.1
<#
.SYNOPSIS
  Copy input materials into .mission/inputs/<category>/ and append an
  entry to .mission/inputs/INDEX.md.

.DESCRIPTION
  Used during Phase 2 of the mission lifecycle. Inputs are intended to
  be immutable once the Design Phase begins (ADR-008); use this script
  only before Mission.state transitions to Planning.

  Locates the mission root via the script's own location: this file is
  expected to live at <root>/tools/mission-inputs-import.ps1.

.PARAMETER SourcePath
  A file or a directory. If a directory, all files at its top level are
  imported (does NOT recurse).

.PARAMETER Category
  One of: requirements, samples, brand, context.

.PARAMETER Description
  Optional one-line description recorded in INDEX.md. Use rich,
  human-meaningful prose -- the designer reads INDEX.md first.

.PARAMETER ExtractBinary
  Optional switch. When set, and the imported file is a recognized
  binary format (.docx, .pdf, .xlsx, .pptx, .png, .jpg, .jpeg, .tiff,
  .bmp), the script invokes Docling on the just-imported file to
  produce a structure-preserving markdown sibling in the same category
  directory, and adds a second INDEX.md entry for the .md.

  WHY an explicit opt-in flag rather than auto-conversion or a runtime
  Read-Host prompt:
    1. The first Docling run downloads layout-detection model weights
       (hundreds of MB). Surprise downloads in the import flow are
       hostile to the operator -- the flag puts that cost in front.
    2. The agent's PowerShell tool harness is non-interactive; a
       Read-Host y/n prompt would hang.
    3. Explicit flags are reproducible from shell history; runtime
       prompts are not.

  See ADR-019 (tools/mission-cli/config/adr-019-input-extraction.md)
  for the framework-wide rationale.

  WITHOUT this flag: binary files are still imported, but the script
  prints a one-paragraph notice telling the operator how to enable
  extraction on a subsequent invocation. To extract after the fact,
  re-run the same import command and add -ExtractBinary; the script
  detects the existing destination and proceeds directly to extraction
  without re-copying.

.EXAMPLE
  PS> .\tools\mission-inputs-import.ps1 `
        -SourcePath "C:\path\to\brief.md" `
        -Category requirements `
        -Description "Primary requirements brief for the engagement..."

.EXAMPLE
  PS> .\tools\mission-inputs-import.ps1 `
        -SourcePath "C:\path\to\reference-sheet.pdf" `
        -Category samples `
        -Description "Reference sheet, full PDF." `
        -ExtractBinary
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('requirements','samples','brand','context')]
    [string]$Category,

    [Parameter(Mandatory = $false)]
    [string]$Description = "(no description supplied -- hand-edit INDEX.md)",

    [Parameter(Mandatory = $false)]
    [switch]$ExtractBinary
)

$ErrorActionPreference = 'Stop'

# Recognized binary extensions for Docling extraction (ADR-019).
$BinaryExtensions = @('.docx','.pdf','.xlsx','.pptx','.png','.jpg','.jpeg','.tiff','.bmp')

# ----- Locate mission root via this script's own location -----
$root = (Get-Item $PSScriptRoot).Parent.FullName
if (-not (Test-Path (Join-Path $root ".mission\mission.yaml"))) {
    Write-Error "Mission root not found. Expected .mission\mission.yaml at: $root"
    exit 1
}

# ----- Resolve and validate SourcePath -----
if (-not (Test-Path $SourcePath)) {
    Write-Error "SourcePath does not exist: $SourcePath"
    exit 1
}

$srcItem = Get-Item -Path $SourcePath
$filesToImport = @()
if ($srcItem.PSIsContainer) {
    $filesToImport = @(Get-ChildItem -Path $SourcePath -File)
    if ($filesToImport.Count -eq 0) {
        Write-Error "SourcePath is a directory but contains no top-level files: $SourcePath"
        exit 1
    }
} else {
    $filesToImport = @($srcItem)
}

# ----- Ensure category subdirectory exists -----
$inputsDir = Join-Path $root ".mission\inputs"
$catDir = Join-Path $inputsDir $Category
if (-not (Test-Path $catDir)) {
    New-Item -ItemType Directory -Path $catDir -Force | Out-Null
}

# ----- INDEX.md scaffold (if missing) -----
$indexPath = Join-Path $inputsDir "INDEX.md"

if (-not (Test-Path $indexPath)) {
    $scaffold = @'
# .mission/inputs/ Index

Manifest of all input materials for this mission. The designer reads this file first.

Inputs are immutable once the Design Phase begins (ADR-008). After `Mission.state` transitions to `Planning`, do not import or modify files in this directory.

## requirements/

(no files)

## samples/

(no files)

## brand/

(no files)

## context/

(no files)

## Known gaps (referenced but not yet imported)

(none)
'@
    [System.IO.File]::WriteAllText($indexPath, $scaffold)
}

# ----- Append a bullet entry under the right category section -----
function Append-IndexRow {
    param(
        [string]$IndexPath,
        [string]$Category,
        [string]$RelDestPath,
        [string]$SourceOriginal,
        [string]$Description
    )

    $content = [System.IO.File]::ReadAllText($IndexPath)
    $sectionHeader = "## $Category/"
    $headerIdx = $content.IndexOf($sectionHeader)
    if ($headerIdx -lt 0) {
        throw "INDEX.md is missing section header: '$sectionHeader'"
    }

    $bodyStart = $headerIdx + $sectionHeader.Length
    $nextHeaderIdx = $content.IndexOf("`n## ", $bodyStart)
    if ($nextHeaderIdx -lt 0) {
        $bodyEnd = $content.Length
        $isLastSection = $true
    } else {
        $bodyEnd = $nextHeaderIdx
        $isLastSection = $false
    }

    $body = $content.Substring($bodyStart, $bodyEnd - $bodyStart)
    $entry = "- ``$RelDestPath`` (from ``$SourceOriginal``) -- $Description"

    if ($body.Trim() -eq "(no files)") {
        $newBody = "`n`n" + $entry
    } else {
        $newBody = $body.TrimEnd() + "`n" + $entry
    }

    if ($isLastSection) {
        $newBody = $newBody + "`n"
    } else {
        $newBody = $newBody + "`n`n"
    }

    $newContent = $content.Substring(0, $bodyStart) + $newBody + $content.Substring($bodyEnd)
    [System.IO.File]::WriteAllText($IndexPath, $newContent)
}

# ----- Copy + index each file (with optional Docling extraction) -----
$imported = @()
$extracted = @()
$binaryNoticed = @()

foreach ($f in $filesToImport) {
    $destFile = Join-Path $catDir $f.Name
    $relDest = "$Category/$($f.Name)"

    if (Test-Path $destFile) {
        if ($ExtractBinary) {
            Write-Host "Destination already exists: $relDest -- skipping copy, proceeding to extraction." -ForegroundColor Yellow
        } else {
            Write-Error "Destination already exists: $destFile -- refusing to overwrite. Delete and re-run, or add -ExtractBinary to skip the copy and run extraction on the existing file."
            exit 1
        }
    } else {
        Copy-Item -Path $f.FullName -Destination $destFile -Force
        Append-IndexRow -IndexPath $indexPath -Category $Category -RelDestPath $relDest -SourceOriginal $f.FullName -Description $Description
        $imported += $relDest
    }

    # ----- Binary detection (ADR-019) -----
    $ext = [System.IO.Path]::GetExtension($f.Name).ToLower()
    if ($BinaryExtensions -contains $ext) {
        if ($ExtractBinary) {
            $extractedFile = [System.IO.Path]::ChangeExtension($destFile, ".md")
            if (Test-Path $extractedFile) {
                Write-Host "Extraction sibling already exists: $extractedFile -- skipping re-extraction." -ForegroundColor Yellow
            } else {
                Write-Host "Running Docling extraction for $($f.Name)..." -ForegroundColor Yellow
                Write-Host "  (first Docling run on a fresh laptop downloads layout model weights -- hundreds of MB)"
                & docling $destFile --to md --output $catDir 2>&1 | Out-Null
                if (Test-Path $extractedFile) {
                    $today = (Get-Date).ToString("yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
                    $extractedRel = "$Category/$([System.IO.Path]::GetFileNameWithoutExtension($f.Name)).md"
                    $extractedDesc = "Extracted from $($f.Name) via Docling on $today for designer readability. Sibling artifact; the binary remains the immutable source of truth (ADR-008 + ADR-019)."
                    Append-IndexRow -IndexPath $indexPath -Category $Category -RelDestPath $extractedRel -SourceOriginal "derived from $relDest" -Description $extractedDesc
                    $extracted += $extractedRel
                } else {
                    Write-Warning "Docling did not produce expected output at $extractedFile. Inspect the source and consider Pandoc as a fallback for .docx (see ADR-019)."
                }
            }
        } else {
            $binaryNoticed += $relDest
        }
    }
}

# ----- Remove .gitkeep now that category has real files -----
$gitkeep = Join-Path $catDir ".gitkeep"
if ((Test-Path $gitkeep) -and ($imported.Count -gt 0)) {
    Remove-Item $gitkeep -Force
}

Write-Host ""
if ($imported.Count -gt 0) {
    Write-Host "Imported $($imported.Count) file(s) into .mission/inputs/$Category/:" -ForegroundColor Green
    $imported | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}
if ($extracted.Count -gt 0) {
    Write-Host "Extracted $($extracted.Count) markdown sibling(s) via Docling:" -ForegroundColor Green
    $extracted | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}
if ($binaryNoticed.Count -gt 0) {
    Write-Host "NOTICE: the following imported files are binary formats that are opaque to the designer:" -ForegroundColor Yellow
    $binaryNoticed | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "To convert them to structure-preserving markdown via Docling (the framework standard per ADR-019),"
    Write-Host "re-run the same command and add -ExtractBinary. First Docling run on a fresh laptop downloads"
    Write-Host "layout-detection model weights (~hundreds of MB) -- that's expected, not a bug."
    Write-Host ""
}
Write-Host "INDEX.md updated at: $indexPath"
Write-Host "Hand-edit it to enrich descriptions or add a 'Known gaps' entry."
Write-Host ""
