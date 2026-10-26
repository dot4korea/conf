# .NET Conf 로컬 미리보기 (실배포 https://.../conf/ 구조와 동일하게 서빙)
# 사용법: .\serve.ps1  (빌드 생략 시: .\serve.ps1 -SkipBuild)
param([switch]$SkipBuild)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$port = 8088
$url = "http://localhost:$port/conf/"

if (-not $SkipBuild) {
  Write-Host '>> 사이트 빌드 중...' -ForegroundColor Cyan
  dotnet run --project (Join-Path $repo 'src') -c Release -- deploy
}

$serveRoot = Join-Path $env:TEMP 'conf-serve'
New-Item -ItemType Directory -Path $serveRoot -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $serveRoot 'serve.json'), '{ "cleanUrls": true }')
$link = Join-Path $serveRoot 'conf'
if (-not (Test-Path $link)) {
  cmd /c mklink /j $link (Join-Path $repo 'src\output') | Out-Null
}

Write-Host ">> 서버 시작: $url" -ForegroundColor Green
$job = Start-Job -ScriptBlock {
  param($dir, $p)
  npx -y serve -l $p -n -S $dir
} -ArgumentList $serveRoot, $port

try {
  $ready = $false
  for ($i = 0; $i -lt 30 -and -not $ready; $i++) {
    Start-Sleep -Seconds 1
    try {
      if ((Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200) { $ready = $true }
    } catch {}
  }
  if (-not $ready) { throw '서버가 시작되지 않았습니다.' }
  try { Start-Process $url } catch {}
  Write-Host '브라우저가 열렸습니다. 종료하려면 Ctrl+C를 누르세요.' -ForegroundColor Yellow
  Wait-Job $job | Out-Null
}
finally {
  Stop-Job $job -ErrorAction SilentlyContinue | Out-Null
  Remove-Job $job -Force -ErrorAction SilentlyContinue
  Write-Host '서버를 종료했습니다.' -ForegroundColor Green
}
