<#
 # from https://learn-powershell.net/2016/02/01/quickly-create-a-powershell-snippet-in-the-ise-using-an-add-on/
#>

[void]$psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("Save selection as Snippet",{
    $Text = $psISE.CurrentFile.Editor.SelectedText
    If (($Text -notmatch '^\s+$' -AND $Text.length -gt 0)) {
        Try {
            [void][Microsoft.VisualBasic.Interaction]
        } Catch {
            Add-Type –assemblyName Microsoft.VisualBasic
        }
        $Name = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Snippet Name", "Snippet Name")
        $Description = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Snippet Description", "Snippet Description")
        If ($Name -and $Description) {
            New-IseSnippet -Description $Description -Title $Name -Text $Text –Force
            Write-Host "New Snippet created!" -ForegroundColor Yellow -BackgroundColor Black
        }
    }
},"Alt+F8")


[void]$psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("Save whole script as Snippet",{
    $Text = $psISE.CurrentFile.Editor.Text
    If (($Text -notmatch '^\s+$' -AND $Text.length -gt 0)) {
        Try {
            [void][Microsoft.VisualBasic.Interaction]
        } Catch {
            Add-Type –assemblyName Microsoft.VisualBasic
        }
        $Name = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Snippet Name", "Snippet Name")
        $Description = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Snippet Description", "Snippet Description")
        If ($Name -and $Description -AND ($Text -notmatch '^\s+$' -AND $Text.length -gt 0)) {
            New-IseSnippet -Description $Description -Title $Name -Text $Text –Force
            Write-Host "New Snippet created!" -ForegroundColor Yellow -BackgroundColor Black
        }
    }
},"Alt+F5")