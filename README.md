# PScode
PowerShell code snippets

1. install SysInternals from the web on a local machine
--
Execute the following one-liner in an elevated powershell prompt

    iex ((new-object net.webclient).DownloadString("https://raw.githubusercontent.com/adriandeller/PScode/master/Get-SysInternals.ps1"))
