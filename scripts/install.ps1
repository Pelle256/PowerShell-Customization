#Requires -Version 7.0

[CmdletBinding()]
param(
  [switch]$Y,
  [string]$ProfilePath,
  [string]$FastfetchConfigPath,
  [string]$LogoPath,
  [ValidateSet('Windows', 'Linux')]
  [string]$Platform,
  [switch]$LoadNow
  )

$ErrorActionPreference = 'Stop'
$isWindowsHost = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$isLinuxHost = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)

function Confirm-Action {
  param([string]$Prompt)

  $answer = Read-Host "$Prompt [y/N]"
  return $answer -match '^(?i)y(es)?$'
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Host "This script requires PowerShell 7 or newer. The current version is $($PSVersionTable.PSVersion)." -ForegroundColor Yellow
  return
}

Write-Host ""
Write-Host "           ██████╗  ██████╗ ██╗    ██╗███████╗██████╗ ███████╗██╗  ██╗███████╗██╗     ██╗               " -ForegroundColor Cyan
Write-Host "           ██╔══██╗██╔═══██╗██║    ██║██╔════╝██╔══██╗██╔════╝██║  ██║██╔════╝██║     ██║               " -ForegroundColor Cyan
Write-Host "           ██████╔╝██║   ██║██║ █╗ ██║█████╗  ██████╔╝███████╗███████║█████╗  ██║     ██║               " -ForegroundColor Cyan
Write-Host "           ██╔═══╝ ██║   ██║██║███╗██║██╔══╝  ██╔══██╗╚════██║██╔══██║██╔══╝  ██║     ██║               " -ForegroundColor Cyan
Write-Host "           ██║     ╚██████╔╝╚███╔███╔╝███████╗██║  ██║███████║██║  ██║███████╗███████╗███████╗          " -ForegroundColor Cyan
Write-Host "           ╚═╝      ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝          " -ForegroundColor Cyan
Write-Host ""
Write-Host " ██████ ██    ██ ███████ ████████  ██████  ███    ███ ██ ███████  █████  ████████ ██  ██████  ███    ██ " -ForegroundColor DarkMagenta
Write-Host "██      ██    ██ ██         ██    ██    ██ ████  ████ ██    ███  ██   ██    ██    ██ ██    ██ ████   ██ " -ForegroundColor DarkMagenta
Write-Host "██      ██    ██ ███████    ██    ██    ██ ██ ████ ██ ██   ███   ███████    ██    ██ ██    ██ ██ ██  ██ " -ForegroundColor DarkMagenta
Write-Host "██      ██    ██      ██    ██    ██    ██ ██  ██  ██ ██  ███    ██   ██    ██    ██ ██    ██ ██  ██ ██ " -ForegroundColor DarkMagenta
Write-Host " ██████  ██████  ███████    ██     ██████  ██      ██ ██ ███████ ██   ██    ██    ██  ██████  ██   ████ " -ForegroundColor DarkMagenta
Write-Host "                                                                                                        " -ForegroundColor DarkMagenta
Write-Host "========================================================================================================" -ForegroundColor DarkMagenta
Write-Host ""
Write-Host "By Pelle Schulte (@Pelle256 on GitHub)" -ForegroundColor Red -NoNewline
Write-Host " - https://short.pellesnium.com/github" -ForegroundColor DarkGray
Write-Host "GitHub repository: Pelle256/PowerShell-Customization" -ForegroundColor Red -NoNewline
Write-Host " - https://short.pellesnium.com/powershell-customization" -ForegroundColor DarkGray

$runningOnWindows = if ($Platform) {
  $Platform -eq 'Windows'
}
else {
  $isWindowsHost
}

function ConvertTo-HomeRelativePath {
  param([string]$Path)

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $homePath = [System.IO.Path]::GetFullPath($HOME)
  $comparison = if ($runningOnWindows) {
    [System.StringComparison]::OrdinalIgnoreCase
  }
  else {
    [System.StringComparison]::Ordinal
  }

  if ($fullPath.Equals($homePath, $comparison)) {
    return '~'
  }

  $homePrefix = $homePath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  if ($homePrefix.Length -eq 0) {
    $homePrefix = [System.IO.Path]::DirectorySeparatorChar.ToString()
  }

  if ($fullPath.StartsWith($homePrefix + [System.IO.Path]::DirectorySeparatorChar, $comparison)) {
    return '~' + $fullPath.Substring($homePrefix.Length)
  }

  return $fullPath
}

function Resolve-InstallPath {
  param(
    [string]$RequestedPath,
    [string]$DefaultPath,
    [string]$FileName
  )

  $path = if ([string]::IsNullOrWhiteSpace($RequestedPath)) { $DefaultPath } else { $RequestedPath }
  if ($path -match '[\\/]$') {
    $path = Join-Path -Path $path -ChildPath $FileName
  }

  return [System.IO.Path]::GetFullPath($path)
}

function Install-Fastfetch {
  if (Get-Command -Name 'fastfetch' -ErrorAction SilentlyContinue) {
    Write-Host 'Fastfetch is already installed.' -ForegroundColor Green
    return
  }

  if ($isWindowsHost) {
    $packageManager = Get-Command -Name 'winget' -ErrorAction SilentlyContinue
    if ($null -eq $packageManager) {
      throw 'Fastfetch is not installed and winget was not found. Install winget or Fastfetch, then run this installer again.'
    }

    Write-Host 'Installing Fastfetch with winget...' -ForegroundColor Cyan
    & $packageManager.Source install --id Fastfetch-cli.Fastfetch --exact --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
      throw "Fastfetch installation failed with winget (exit code $LASTEXITCODE)."
    }
    return
  }

  if (-not $isLinuxHost) {
    throw 'Automatic Fastfetch installation is supported only on Windows and Linux.'
  }

  $packageManagers = @(
    @{ Name = 'apt-get'; Arguments = @('install', '-y', 'fastfetch') },
    @{ Name = 'dnf'; Arguments = @('install', '-y', 'fastfetch') },
    @{ Name = 'pacman'; Arguments = @('-S', '--needed', '--noconfirm', 'fastfetch') },
    @{ Name = 'zypper'; Arguments = @('--non-interactive', 'install', 'fastfetch') },
    @{ Name = 'apk'; Arguments = @('add', 'fastfetch') },
    @{ Name = 'xbps-install'; Arguments = @('-y', 'fastfetch') },
    @{ Name = 'emerge'; Arguments = @('--ask=n', 'app-misc/fastfetch') }
  )
  $packageManager = $null
  $packageArguments = $null
  foreach ($candidate in $packageManagers) {
    $command = Get-Command -Name $candidate.Name -ErrorAction SilentlyContinue
    if ($null -ne $command) {
      $packageManager = $command
      $packageArguments = $candidate.Arguments
      break
    }
  }

  if ($null -eq $packageManager) {
    throw "Fastfetch is not installed and no supported Linux package manager was found (apt-get, dnf, pacman, zypper, apk, xbps-install, or emerge)."
  }
  $packageManagerName = $packageManager.Name

  if ([System.Environment]::UserName -ne 'root') {
    $sudo = Get-Command -Name 'sudo' -ErrorAction SilentlyContinue
    if ($null -eq $sudo) {
      throw "Fastfetch needs to be installed with $packageManagerName, but sudo was not found. Run this installer as root or install Fastfetch manually."
    }

    $packageArguments = @($packageManager.Source) + $packageArguments
    $packageManager = $sudo
  }

  Write-Host "Installing Fastfetch with $packageManagerName..." -ForegroundColor Cyan
  & $packageManager.Source @packageArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Fastfetch installation failed with $packageManagerName (exit code $LASTEXITCODE)."
  }
}

function Set-FastfetchLogo {
  param(
    [string]$ConfigFilePath,
    [string]$LogoFilePath
  )

  $contents = [System.IO.File]::ReadAllText($ConfigFilePath)
  $documentOptions = [System.Text.Json.JsonDocumentOptions]::new()
  $documentOptions.CommentHandling = [System.Text.Json.JsonCommentHandling]::Skip
  try {
    $config = [System.Text.Json.Nodes.JsonNode]::Parse($contents, $null, $documentOptions)
  }
  catch {
    throw "Could not parse Fastfetch config '$ConfigFilePath': $_"
  }

  if ($null -eq $config -or $config -isnot [System.Text.Json.Nodes.JsonObject]) {
    throw "Fastfetch config must contain a JSON object at its root: $ConfigFilePath"
  }

  if ($config['logo'] -isnot [System.Text.Json.Nodes.JsonObject]) {
    $config['logo'] = [System.Text.Json.Nodes.JsonObject]::new()
  }

  $logo = [System.Text.Json.Nodes.JsonObject]$config['logo']
  $display = [System.Text.Json.Nodes.JsonObject]$config['display']
  $logoConfigPath = ConvertTo-HomeRelativePath -Path $LogoFilePath
  if ($runningOnWindows) {
    $logoConfigPath = $logoConfigPath.Replace('\', '/')
    $logo['type'] = [System.Text.Json.Nodes.JsonValue]::Create('file')
    $logo['source'] = [System.Text.Json.Nodes.JsonValue]::Create($logoConfigPath)
    if ($logo['color'] -isnot [System.Text.Json.Nodes.JsonObject]) {
      $logo['color'] = [System.Text.Json.Nodes.JsonObject]::new()
    }
    $logoColor = [System.Text.Json.Nodes.JsonObject]$logo['color']
    $logoColor['1'] = [System.Text.Json.Nodes.JsonValue]::Create('cyan')
    $logoColor['2'] = [System.Text.Json.Nodes.JsonValue]::Create('#C19C00')
    $logoColor['3'] = [System.Text.Json.Nodes.JsonValue]::Create('green')
    $logoColor['4'] = [System.Text.Json.Nodes.JsonValue]::Create('red')

    if ($display['color'] -isnot [System.Text.Json.Nodes.JsonObject]) {
      $display['color'] = [System.Text.Json.Nodes.JsonObject]::new()
    }
    $displayColor = [System.Text.Json.Nodes.JsonObject]$display['color']
    $displayColor['title'] = [System.Text.Json.Nodes.JsonValue]::Create('yellow')
    $displayColor['keys'] = [System.Text.Json.Nodes.JsonValue]::Create('cyan')
  }

  $serializationOptions = [System.Text.Json.JsonSerializerOptions]::new()
  $serializationOptions.WriteIndented = $true
  [System.IO.File]::WriteAllText($ConfigFilePath, $config.ToJsonString($serializationOptions))
}

$profileDefault = $PROFILE
$fastfetchDefaultDirectory = Join-Path -Path $HOME -ChildPath '.config/fastfetch'

$profileDestination = Resolve-InstallPath -RequestedPath $ProfilePath -DefaultPath $profileDefault -FileName 'Microsoft.PowerShell_profile.ps1'
$configDestination = Resolve-InstallPath -RequestedPath $FastfetchConfigPath -DefaultPath (Join-Path -Path $fastfetchDefaultDirectory -ChildPath 'config.jsonc') -FileName 'config.jsonc'

$sourceRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\src'
$installFiles = @(
  [PSCustomObject]@{
    Name        = 'PowerShell profile'
    Source      = Join-Path -Path $sourceRoot -ChildPath 'Microsoft.PowerShell_profile.ps1'
    Destination = $profileDestination
  },
  [PSCustomObject]@{
    Name        = 'Fastfetch config'
    Source      = Join-Path -Path $sourceRoot -ChildPath '.config\fastfetch\config.jsonc'
    Destination = $configDestination
  }
)

if ($runningOnWindows) {
  $logoDestination = Resolve-InstallPath -RequestedPath $LogoPath -DefaultPath (Join-Path -Path $fastfetchDefaultDirectory -ChildPath 'logos/windows.txt') -FileName 'windows.txt'
  $installFiles += [PSCustomObject]@{
    Name        = 'Fastfetch logo'
    Source      = Join-Path -Path $sourceRoot -ChildPath '.config\fastfetch\logos\windows.txt'
    Destination = $logoDestination
  }
}

Write-Host ''
Write-Host '  PowerShell' -ForegroundColor Cyan -NoNewline
Write-Host ' Customization' -ForegroundColor DarkMagenta
Write-Host '  ----------' -ForegroundColor Cyan -NoNewline
Write-Host '-' -ForegroundColor White -NoNewline
Write-Host '-------------' -ForegroundColor DarkMagenta
Write-Host 'The following files may be created or changed:' -ForegroundColor White
foreach ($file in $installFiles) {
  $displayPath = ConvertTo-HomeRelativePath -Path $file.Destination
  Write-Host "  • $($file.Name): $displayPath" -ForegroundColor Gray
}
Write-Host ''
Write-Host 'The following packages may be installed:' -ForegroundColor White
Write-Host "  • fastfetch" -ForegroundColor Gray
Write-Host ''

if (-not $Y -and -not (Confirm-Action -Prompt 'Do you want to continue?')) {
  Write-Host 'Installation cancelled; no files were changed.' -ForegroundColor Yellow
  return
}

Install-Fastfetch

$installedFiles = @()
foreach ($file in $installFiles) {
  if (-not (Test-Path -LiteralPath $file.Source -PathType Leaf)) {
    throw "Installation source file was not found: $($file.Source)"
  }

  if (Test-Path -LiteralPath $file.Destination -PathType Container) {
    throw "The destination is a directory, not a file: $($file.Destination)"
  }

  if (Test-Path -LiteralPath $file.Destination -PathType Leaf) {
    $existingContent = [System.IO.File]::ReadAllText($file.Destination)
    if ($existingContent -match '\S' -and -not $Y) {
      $displayPath = ConvertTo-HomeRelativePath -Path $file.Destination
      if (-not (Confirm-Action -Prompt "Overwrite the existing $($file.Name) at '$displayPath'?")) {
        Write-Host "  Skipped $($file.Name)." -ForegroundColor Yellow
        continue
      }
    }
  }

  $parentDirectory = Split-Path -Path $file.Destination -Parent
  if (-not (Test-Path -LiteralPath $parentDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $parentDirectory -Force | Out-Null
  }

  Copy-Item -LiteralPath $file.Source -Destination $file.Destination -Force
  if ($runningOnWindows -and $file.Name -eq 'Fastfetch config') {
    Set-FastfetchLogo -ConfigFilePath $file.Destination -LogoFilePath $logoDestination
  }
  $installedFiles += $file.Name
  Write-Host "  Installed $($file.Name)." -ForegroundColor Green
}

Write-Host ''
if ($installedFiles.Count -eq 0) {
  Write-Host 'No files were installed.' -ForegroundColor Yellow
}
else {
  Write-Host 'Installation complete!' -ForegroundColor Green
  Write-Host 'Manual customization:' -ForegroundColor White
  Write-Host '  • Edit the PowerShell profile to change your prompt and shell behavior:' -ForegroundColor Gray
  Write-Host "    → '$(ConvertTo-HomeRelativePath -Path $profileDestination)'" -ForegroundColor Gray
  Write-Host '  • Edit the Fastfetch config to change modules, colors, and logo settings.' -ForegroundColor Gray
  Write-Host "    → '$(ConvertTo-HomeRelativePath -Path $configDestination)'" -ForegroundColor Gray
  if ($runningOnWindows) {
    Write-Host '  • Edit the installed Fastfetch ASCII Logo.' -ForegroundColor Gray
    Write-Host "    → '$(ConvertTo-HomeRelativePath -Path $logoDestination)'" -ForegroundColor Gray
  }
  if(-not $LoadNow){
    Write-Host "  • `e[4mRestart PowerShell to load profile changes.`e[0m" -ForegroundColor Magenta
  }
  Write-Host 'Fastfetch configuration guide: https://github.com/fastfetch-cli/fastfetch/wiki/Configuration' -ForegroundColor Cyan
  Write-Host 'Further customization guide: https://short.pellesnium.com/powershell-customization' -ForegroundColor Cyan
}

if ($LoadNow -or (-not $Y -and (Confirm-Action -Prompt "Do you want to load the installed PowerShell Profile now?"))) {
  Write-Host ""
  . $profileDestination
  Write-Host "Loaded $(ConvertTo-HomeRelativePath -Path $profileDestination)" -ForegroundColor Green
  return
}
