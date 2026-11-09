$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Invoke-Git {
  param([string[]]$Arguments)
  & git @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function Push-LocalCommits {
  $aheadBehind = (& git rev-list --left-right --count 'origin/main...HEAD').Trim()
  if ($LASTEXITCODE -ne 0) {
    return
  }

  $parts = $aheadBehind -split '\s+'
  if ($parts.Count -eq 2 -and [int]$parts[1] -gt 0) {
    Write-Host "Pushing pending commit(s)..."
    Invoke-Git @('push', 'origin', 'main')
  }
}

function Commit-AndPush {
  $changes = (& git status --porcelain -- index.html).Trim()
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($changes)) {
    Push-LocalCommits
    return
  }

  Write-Host "Detected saved changes in index.html."
  Invoke-Git @('add', '--', 'index.html')
  $message = "Auto-sync index.html $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  Invoke-Git @('commit', '-m', $message, '-m', 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>')
  Push-LocalCommits
}

Write-Host "Watching index.html for saves. Press Ctrl+C to stop."
$lastWrite = [datetime]::MinValue

while ($true) {
  try {
    $file = Get-Item (Join-Path $repoRoot 'index.html')
    if ($file.LastWriteTimeUtc -ne $lastWrite) {
      $lastWrite = $file.LastWriteTimeUtc
      Start-Sleep -Seconds 2
      Commit-AndPush
    } else {
      Push-LocalCommits
    }
  } catch {
    Write-Warning $_.Exception.Message
  }
  Start-Sleep -Seconds 2
}
