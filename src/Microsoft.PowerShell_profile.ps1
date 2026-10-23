#
# Prepare
#

$os = 'unix'
if ($PSVersionTable.Platform -eq 'Win32NT') {
  $os = 'windows'
}

#
# Customization
#

fastfetch
Write-Host "" # Empty Line

# Custom prompt
function prompt {
  $isElevated = $false
  if ($os -eq 'windows') {
    $isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $elevatedSegment = "ADMIN"
  }
  else {
    # Linux / Unix: check if UID is 0 (root) or user belongs to the sudo group
    $isRoot = (id -u) -eq 0
    $isInSudoGroup = (groups) -split '\s+' -contains 'sudo'
    $isElevated = $isRoot -or $isInSudoGroup
    $elevatedSegment = "SUDO"
  }
  $elevatedSegment = if ($isElevated) { "$($Styles.White)$($Styles.BgRed)[$($elevatedSegment)]$($Styles.Reset) " } else { "" }

  $time = Get-Date -Format "HH:mm:ss"
  $userHost = "$([Environment]::UserName)@$([Environment]::MachineName)"
  $cwd = $executionContext.SessionState.Path.CurrentLocation

  return "$($Styles.Reset)$($Styles.BrightBlack)[$($time)]$($Styles.Reset) $($elevatedSegment)$($Styles.Cyan)$($userHost)$($Styles.Reset) 📁 $($Styles.White)$($cwd) $($Styles.Green)`$$($Styles.Reset) "
}

#
# Tools
#

$Styles = [PSCustomObject]@{
  Reset           = "`e[0m"

  # Text Attributes
  Bold            = "`e[1m"
  Dim             = "`e[2m"
  Italic          = "`e[3m"
  Underline       = "`e[4m"
  Blink           = "`e[5m"
  Reverse         = "`e[7m"
  Hidden          = "`e[8m"
  Strikethrough   = "`e[9m"

  # Foreground Colors (Standard)
  Black           = "`e[30m"
  Red             = "`e[31m"
  Green           = "`e[32m"
  Yellow          = "`e[33m"
  Blue            = "`e[34m"
  Magenta         = "`e[35m"
  Cyan            = "`e[36m"
  White           = "`e[37m"

  # Foreground Colors (Bright)
  BrightBlack     = "`e[90m"
  DarkGray        = "`e[90m"
  BrightRed       = "`e[91m"
  BrightGreen     = "`e[92m"
  BrightYellow    = "`e[93m"
  BrightBlue      = "`e[94m"
  BrightMagenta   = "`e[95m"
  BrightCyan      = "`e[96m"
  BrightWhite     = "`e[97m"

  # Background Colors (Standard)
  BgBlack         = "`e[40m"
  BgRed           = "`e[41m"
  BgGreen         = "`e[42m"
  BgYellow        = "`e[43m"
  BgBlue          = "`e[44m"
  BgMagenta       = "`e[45m"
  BgCyan          = "`e[46m"
  BgWhite         = "`e[47m"

  # Background Colors (Bright)
  BgBrightBlack   = "`e[100m"
  BgBrightRed     = "`e[101m"
  BgBrightGreen   = "`e[102m"
  BgBrightYellow  = "`e[103m"
  BgBrightBlue    = "`e[104m"
  BgBrightMagenta = "`e[105m"
  BgBrightCyan    = "`e[106m"
  BgBrightWhite   = "`e[107m"
}

if($os -eq "windows"){
  # Windows specific custom utilities

  function ConvertTo-IdentityName {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
      [object]$Sid
    )
    process {
      try {
        $sidObj = if ($Sid -is [System.Security.Principal.SecurityIdentifier]) {
          $Sid
        }
        else {
          [System.Security.Principal.SecurityIdentifier]::new($Sid.ToString())
        }
        $sidObj.Translate([System.Security.Principal.NTAccount]).Value
      }
      catch {
        if ($Sid -is [System.Security.Principal.SecurityIdentifier]) { $Sid.Value } else { "$Sid" }
      }
    }
  }

  function Get-NamedPipes {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory = $false)]
      [string]$Filter = "*",

      [Parameter(Mandatory = $false)]
      [string]$MachineName = "."
    )

    try {
      $targetPath = if ($MachineName -eq "." -or $MachineName -eq "localhost") {
        "\\.\pipe\"
      }
      else {
        "\\$MachineName\pipe\"
      }

      # Query the named pipe namespace via .NET IO
      $pipePaths = [System.IO.Directory]::GetFiles($targetPath, $Filter)
          
      $pipePaths | ForEach-Object {
        [PSCustomObject]@{
          MachineName = $MachineName
          PipeName    = $_.Replace($targetPath, "")
          FullPath    = $_
        }
      }
    }
    catch {
      Write-Error "Failed to list named pipes on '$MachineName': $_"
    }
  }

  function Get-PipeSecurity {
    param(
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
      [string]$PipeName,

      [Parameter(Mandatory = $false)]
      [string]$MachineName = ".",

      [Parameter(Mandatory = $false)]
      [int]$TimeoutMs = 1000
    )

    try {
      $clientStream = [System.IO.Pipes.NamedPipeClientStream]::new($MachineName, $PipeName, [System.IO.Pipes.PipeDirection]::In)
      $clientStream.Connect($TimeoutMs)
      $pipeSecurity = [System.IO.Pipes.PipesAclExtensions]::GetAccessControl($clientStream)
          
      [PSCustomObject]@{
        MachineName = $MachineName
        PipeName    = $PipeName
        Owner       = $pipeSecurity.GetOwner([System.Security.Principal.SecurityIdentifier])
        Access      = $pipeSecurity.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
      }

      $clientStream.Close()
    }
    catch {
      Write-Error "Failed to connect or read security for pipe '$PipeName' on machine '$MachineName': $_"
    }
  }
}
