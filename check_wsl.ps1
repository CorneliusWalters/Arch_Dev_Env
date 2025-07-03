Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss" | ForEach-Object {
    $distroName = (Get-ItemProperty $_.PSPath).DistributionName
    $distroId = $_.PSChildName
    Write-Host "UUID: $distroId | Name: $distroName"
  }