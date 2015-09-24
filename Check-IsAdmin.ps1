<#
.Synopsis
   Tests if the user is an administrator
.DESCRIPTION
   Returns true if a user is an administrator, false if the user is not an administrator
.EXAMPLE
   Test-IsAdministrator
#>
function Test-IsAdministrator
{
    $WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $WindowsPrincipal = [Security.Principal.WindowsPrincipal] $WindowsIdentity
    $WindowsPrincipal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
