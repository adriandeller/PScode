#Region Get Pester Results
Import-Module "C:\Users\Adrian\Documents\Dev\ADGroupConfiguration\ADGroupConfiguration\ADGroupConfiguration.psd1"

$GroupCode = 'RG-JG01'
$DepartmentPrefix = 'DPW'

#Region Start Pester Tests
$PesterResults = Invoke-ADGroupConfigTest -GroupCode $GroupCode -DepartmentPrefix $DepartmentPrefix -PassThru -Show None

if ($PesterResults.FailedCount -gt 0)
{
    $TestResultErrors = $PesterResults.TestResult | Where-Object { $_.Result -ne 'Passed' } | Group-Object -Property Describe -AsHashTable
}
else
{
    Write-Host 'No errors found in AD group configuration.'
    break
}
#EndRegion


#Region 
Import-Module PSTeams
$TeamConfig = (Get-Content -Path "C:\Users\Adrian\Documents\Dev\MyConfig\config.json") | ConvertFrom-Json

$TeamsMessageColor = [System.Drawing.Color]::Cyan

if ($TestResultErrors)
{
    $TeamsSections = @()

    # Summary section
    $ActivityDetailsSummary = @()
    $ActivityDetailsSummary += New-TeamsFact -Name "Tests Passed" -Value ">$($PesterResults.PassedCount)"
    $ActivityDetailsSummary += New-TeamsFact -Name "Tests Failed" -Value ">$($PesterResults.FailedCount)"

    $TeamsSectionSummary = @{
        ActivityTitle   = "**Summary**" 
        ActivityText    = 'Errors in AD group configuration have been detected.' 
        ActivityDetails = $ActivityDetailsSummary
    }
    $TeamsSections += New-TeamsSection @TeamsSectionSummary

    # Create a Section for each Describe
    $TeamsSections += $TestResultErrors.GetEnumerator() | ForEach-Object {
        $SectionName = $PSItem.Name
        $SectionValue = $PSItem.Value
        $ActivityDetails = @()
        $ActivityDetails = foreach ($Activity in $SectionValue)
        {
            New-TeamsFact -Name "$($Activity.Result)" -Value ">$($Activity.Name)"
        }

        $TeamsSection = @{
            ActivityTitle   = "**$SectionName**" 
            #ActivitySubtitle    = "@przemyslawklys - 9/12/2016 at 5:33pm"
            #ActivityImageLink   = "https://pbs.twimg.com/profile_images/1017741651584970753/hGsbJo-o_400x400.jpg"
            #ActivityText    = 'Errors in AD group configuration has been detected' 
            ActivityDetails = $ActivityDetails
        }
        New-TeamsSection @TeamsSection
    }

    $TeamsMessage = @{
        URI          = $TeamConfig.Channel
        MessageTitle = '[INFO] AD group configuration check'
        #MessageText  = 'Change in AD group membership has been detected' 
        Color        = $TeamsMessageColor
        Sections     = $TeamsSections
    }

    Send-TeamsMessage @TeamsMessage 
}