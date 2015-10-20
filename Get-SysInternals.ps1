<# 
.SYNOPSIS
    Get the SysInternals tools from web
.DESCRIPTION 
    Download SysInternals tools from web to a local folder.
.NOTES
    File Name : Get-SysInternals.ps1 
    Author    : Adrian Deller - adrian.deller@unibas.ch
    Requires  : PowerShell v3
    Version   : 1.0
    Updated   : 20.10.2015
#> 

#Requires -Version 3.0

[cmdletbinding(SupportsShouldProcess)]

Param(
    [Parameter(Mandatory=$false,
                ValueFromPipelineByPropertyName=$true,
                Position=0)]
    [Alias("Path")] 
    [string]
    $Destination = (Join-Path ${env:ProgramFiles(x86)} "\SysInternals")
)

Begin
{
    #start the WebClient service if it is not running
    if ((Get-Service WebClient).Status -eq 'Stopped') {
         Write-Verbose "Starting WebClient"
         #always start the webclient service even if using -Whatif
         Start-Service WebClient -WhatIf:$false
         $Stopped = $True
    }
    else {
        <#
         Define a variable to indicate service was already running
         so that we don't stop it. Making an assumption that the
         service is already running for a reason.
        #>
        $Stopped = $False
    }

    if(!(Test-Path $Destination)) {
        New-Item -ItemType directory -Path $Destination -Force | Out-Null
        Write-Verbose "Created new folder $Destination"
    }
    else {
        Write-Verbose "Destination $Destination already exists."
    }

    <#
     # function to modify Env:Path in the registry
     # provide a path with the parameter to append to the Env:Path
    #>
    function Add-Path {
        Param (
            [Parameter(Mandatory=$true,
                        Position=0)]
            [string]
            $Path
        )
        Process {
            if ($env:Path | Select-String -SimpleMatch $Path) {
                Write-Host "Folder already within $ENV:PATH"
            }

            $Reg = "Registry::HKLM\System\CurrentControlSet\Control\Session Manager\Environment"
            $OldPath = (Get-ItemProperty -Path "$Reg" -Name PATH).Path
            $NewPath = $OldPath + ";" + $Path
            Set-ItemProperty -Path "$Reg" -Name PATH –Value $NewPath -Confirm:$false
        }
    }
}
Process
{
    Write-Host "Updating SysInternals tools from \\live.sysinternals.com\tools to $destination" -ForegroundColor Cyan

    <#
    #get current files in destination
    $current = dir -Path $Destination -File

    foreach ($file in $current) {
      #construct a path to the live web version and compare dates
      $online = Join-Path -path \\live.sysinternals.com\tools -ChildPath $file.name
      Write-Verbose "Testing $online"
      if ((Get-Item -Path $online).LastWriteTime.Date -ge $file.LastWriteTime.Date) {
        Copy-Item $online -Destination $Destination -PassThru
      }
    }

    Write-Host "Testing for online files not in $destination" -ForegroundColor Green

    #test for files online but not in the destination and copy them
    dir -path \\live.sysinternals.com\tools -file | 
    Where {$current.name -notcontains $_.name} |
    Copy-Item -Destination $Destination -PassThru
    #>

    # alternative but this might still copy files that haven't really changed
    robocopy \\live.sysinternals.com\tools $destination /MIR /W:1 /R:1
    #
}
End
{
    if ($Stopped) {
        Write-Verbose "Stopping web client"
        #always stop the service even if using -Whatif
        Stop-Service WebClient -WhatIf:$False
    }

    Write-Host "SysInternals update complete." -ForegroundColor Cyan 
    #end of script

    Add-Path -Path $Destination
}
