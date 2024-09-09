param(
    [Parameter(Mandatory=$true)][string]$Source, # ex. vcpkg/buildtrees/
    [Parameter(Mandatory=$true)][string]$Destination # ex. logs/
)

Write-Host "Copying logs: $Source ==> $Destination"
if (Test-Path $Destination) {
    Remove-Item -Recurse -Force $Destination
}
Get-ChildItem -Path $Source -Recurse -Filter *.log | ForEach-Object {
  $destPath = $_.FullName -replace [regex]::Escape((Resolve-Path -Path $Source).Path), $Destination
  Write-Host "> $($_.FullName) ==> $destPath"
  New-Item -ItemType Directory -Path (Split-Path $destPath) -Force -ErrorAction SilentlyContinue | Out-Null
  Copy-Item -Path $_.FullName -Destination $destPath
}
