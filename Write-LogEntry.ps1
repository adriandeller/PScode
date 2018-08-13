
# inspiration and original code from https://nakedpowershell.blogspot.com/2016/10/tweaks-to-write-logentry.html
# related https://lazywinadmin.github.io/2016/08/powershell-composite-formatting.html


#Region Define enum
enum Severity
{
    Information
    Warning
    Error
}

enum StateIndicator
{
    Neutral
    Success
    Failure
}
#EndRegion


#Region Find the function with the longest name
$Functions = @()
$Functions = $MyInvocation.MyCommand.ScriptBlock.Ast.EndBlock.Statements.Where( {$_ -is [Management.Automation.Language.FunctionDefinitionAst]})
$Functions = $Functions | Select-Object Name, @{N = 'Lengt'; E = {($PSItem.Name | Measure-Object -Character).Characters}}
$Global:FunctionNameMaxLength = $Functions.Lengt | Sort-Object -Descending | Select-Object -First 1
#EndRegion


function Write-LogEntry
{
    [CmdletBinding()]
    param
    (
        [string]
        $Message,

        [Severity]
        $Severity = [Severity]::Information,
        
        [StateIndicator]
        $Indicator = [StateIndicator]::Neutral,

        [ValidateRange(0, 3)]
        [int]
        $Indent = 0
    )
    Begin
    {
    }
    Process
    {
        switch ($Severity)
        {
            Information
            {
                $Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::White #Cyan
            }
            Warning
            {
                $Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Yellow
                $PSDefaultParameterValues = @{'Write-Host:ForegroundColor' = [System.ConsoleColor]::Yellow}
            }
            Error
            {
                $Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Red
                $PSDefaultParameterValues = @{'Write-Host:ForegroundColor' = [System.ConsoleColor]::Red}
            }
        }

        switch ($Indicator)
        {
            Neutral { $IndicatorSymbol = '*' }
            Success
            {
                $IndicatorSymbol = '+' 
                $Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Green
                $PSDefaultParameterValues = @{'Write-Host:ForegroundColor' = [System.ConsoleColor]::Green}
            }
            Failure
            {
                $IndicatorSymbol = '-' 
                $Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Red
                $PSDefaultParameterValues = @{'Write-Host:ForegroundColor' = [System.ConsoleColor]::Red}
            }
        }

        #Region Write message to Host
        $Prefix = "[$IndicatorSymbol]"
        $Whitespaces = $null

        if ($Indent -gt 0)
        {
            $Whitespaces = ' ' * 4 * $Indent
        }

        $Message = $Message + " ($Severity | $Indicator)"
        $HostMessage = '{0}{1} {2}' -f $Whitespaces, $Prefix, $Message
        #Write-Verbose -Message $HostMessage -Verbose:$true
        Write-Host -Object $HostMessage
        #EndRegion


        #Region Write message to log file
        $DateString = (Get-Date -Format s)
        $FunctionName = (Get-PSCallStack)[1].FunctionName
        $FunctionNameString = '[' + $FunctionName + ']'
        $SeverityString = '[' + $Severity + ']'
        $MessageString = $Message
                
        $FunctionNameStringPaddingRight = $Global:FunctionNameMaxLength + 2
        $LogMessage = "{0,-19} {1,-$FunctionNameStringPaddingRight} {2,-13} {3}" -f $DateString, $FunctionNameString, $SeverityString, $MessageString
        #$LogMessage
        Add-Content -Path C:\temp\logfile.log -Value $LogMessage
        #EndRegion
    }
    End
    {
        $Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Yellow
        $PSDefaultParameterValues.Remove('Write-Host:ForegroundColor')
    }
}

function LogTester
{
    [CmdletBinding()]
    param
    (
        
    )
    Write-LogEntry -Message "Test as information" -Severity Information
    Write-LogEntry -Message "Test as warning" -Severity Warning
    Write-LogEntry -Message "Test as error" -Severity Error
}

function LogTesterLong
{
    [CmdletBinding()]
    Param
    (
        $Text = 'Lorem ipsum dolor sit amet'
    )
    Write-LogEntry -Message $Text -Severity Information
    Write-LogEntry -Message $Text -Severity Information -Indent 1
    Write-LogEntry -Message $Text -Severity Information -Indent 2 -Indicator Failure
    Write-LogEntry -Message $Text -Severity Information -Indent 2 -Indicator Success
    Write-LogEntry -Message $Text -Severity Information -Indent 1
    Write-LogEntry -Message $Text -Severity Warning -Indent 1
    Write-LogEntry -Message $Text -Severity Warning -Indent 1 -Indicator Failure
    Write-LogEntry -Message $Text -Severity Error -Indent 2
    Write-LogEntry -Message $Text
}

function LogTesterSuperLong
{
    [CmdletBinding()]
    Param
    (
        $Text = 'Lorem ipsum dolor sit amet'
    )
    Write-LogEntry -Message $Text -Severity Information
    Write-LogEntry -Message $Text -Severity Information -Indent 1
    Write-LogEntry -Message $Text -Severity Information -Indent 2 -Indicator Failure
    Write-LogEntry -Message $Text -Severity Information -Indent 2 -Indicator Success
    Write-LogEntry -Message $Text -Severity Information -Indent 0
    Write-LogEntry -Message $Text -Severity Warning -Indent 1
    Write-LogEntry -Message $Text -Severity Warning -Indent 1 -Indicator Success
    Write-LogEntry -Message $Text -Severity Warning -Indent 1 -Indicator Failure
    Write-LogEntry -Message $Text -Severity Error -Indent 2
    Write-LogEntry -Message $Text -Indicator Success
}

#LogTester
#LogTesterLong
LogTesterSuperLong
#Get-Content -Path c:\temp\logfile.log
