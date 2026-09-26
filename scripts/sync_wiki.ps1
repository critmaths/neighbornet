# PowerShell script to manually sync docs/ folder to GitHub Wiki
param(
    [string]$RepoUrl = "https://github.com/critmaths/neighbornet.wiki.git"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$DocsDir = Join-Path $RootDir "docs"
$TempWikiDir = Join-Path $RootDir ".tmp_wiki_clone"

Write-Host "Syncing NeighborNet docs to GitHub Wiki..." -ForegroundColor Cyan

if (Test-Path $TempWikiDir) {
    Remove-Item -Recurse -Force $TempWikiDir
}

try {
    Write-Host "Cloning wiki repository: $RepoUrl" -ForegroundColor Yellow
    git clone $RepoUrl $TempWikiDir

    Write-Host "Copying documentation markdown files..." -ForegroundColor Yellow
    Get-ChildItem -Path $DocsDir -Filter "*.md" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $TempWikiDir -Force
    }

    Push-Location $TempWikiDir
    git config user.name "NeighborNet Wiki Sync"
    git config user.email "critmaths@gmail.com"
    git add .
    $status = git status --porcelain
    if ($status) {
        git commit -m "docs: sync wiki documentation from master docs/ folder"
        git push origin master
        Write-Host "GitHub Wiki successfully updated and pushed!" -ForegroundColor Green
    } else {
        Write-Host "GitHub Wiki is already up-to-date. No changes needed." -ForegroundColor Green
    }
} catch {
    Write-Host "Wiki sync error: $_" -ForegroundColor Red
} finally {
    Pop-Location -ErrorAction SilentlyContinue
    if (Test-Path $TempWikiDir) {
        Remove-Item -Recurse -Force $TempWikiDir
    }
}
