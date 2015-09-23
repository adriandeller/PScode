function Get-IsAdministrator
{
    $WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $WindowsPrincipal = [Security.Principal.WindowsPrincipal] $WindowsIdentity
    if ($WindowsPrincipal.IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
        $true
    }
    else {
        $false
    }
}
