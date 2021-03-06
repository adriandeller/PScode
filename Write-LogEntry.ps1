<#
    inspiration and original code from
    https://nakedpowershell.blogspot.com/2016/10/tweaks-to-write-logentry.html
    https://github.com/MSAdministrator/WriteLogEntry
    https://github.com/9to5IT/PSLogging
    https://github.com/platta/PSMultiLog

    related:
    https://lazywinadmin.github.io/2016/08/powershell-composite-formatting.html
#>

#Region Define enum
enum Severity
{
    Information
    Warning
    Error
}

enum Indicator
{
    Neutral
    Success
    Failure
}
#EndRegion


#Region Find the function with the longest name in the current script
#$Global:FunctionNameMaxLength = $MyInvocation.MyCommand.ScriptBlock.Ast.EndBlock.Statements | 
#    Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst]} | 
#    Select-Object -Property Name, @{N = 'Length'; E = {($PSItem.Name).ToString().Length }} | 
#    Sort-Object -Property Length | 
#    Select-Object -Last 1 -ExpandProperty Length
#EndRegion


#Region Find the function with the longest name availbale in 'Function' drive
#$Global:FunctionNameMaxLength = Get-ChildItem Function: | 
#    Select-Object Name, @{N = 'Length'; E = {($PSItem.Name).ToString().Length }} | 
#    Sort-Object -Property Length | 
#    Select-Object -Last 1 -ExpandProperty Length
#EndRegion


#Region Write-LogEntry
function Write-LogEntry
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [string]
        $Message = '',

        [Parameter(Mandatory = $false)]
        [Severity]
        $Severity = 'Information',
        
        [Parameter(Mandatory = $false)]
        [Indicator]
        $Indicator = 'Neutral',

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 3)]
        [int]
        $Indent = 0
    )

    DynamicParam
    {
        # Create an RuntimeDefinedParameterDictionary object
        $ParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        if ($Severity -eq 'Error')
        {
            # Set the dynamic parameters' name
            $ParameterName = 'ErrorRecord'

            # Set the dynamic parameters' type
            $ParameterType = [System.Management.Automation.ErrorRecord]
            
            # Create an Collection object
            $Collection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

            # Create a ParameterAttribute object and define properties
            $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute.Mandatory = $false
            $ParameterAttribute.Position = 0
            $ParameterAttribute.HelpMessage = "Provide an error object like '$Error[0]'"

            # Add the ParameterAttribute object to the Collection object
            $Collection.Add($ParameterAttribute)

            # Create a ValidateNotNullOrEmptyAttribute object
            $ValidateNotNullOrEmptyAttribute = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute

            # Add the ValidateNotNullOrEmptyAttribute object to the Collection object
            $Collection.Add($ValidateNotNullOrEmptyAttribute)

            # Create a RuntimeDefinedParameter object for the new dynamic paramater
            $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, $ParameterType, $Collection)

            # Add the RuntimeDefinedParameter object to the ParameterDictionary object
            $ParameterDictionary.Add($ParameterName, $RuntimeParameter)
        }
        # return the ParameterDictionary object with the new dynamic paramaters
        return $ParameterDictionary
    }

    Begin
    {
        # Create variables for dynamic parameters:
        #  loop through bound parameters, filter out common parameters
        #  if no corresponding variable exists, create one
        $CommonParameters = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        $BoundKeys = $PSBoundParameters.keys | Where-Object { $CommonParameters -notcontains $_}
        foreach ($Param in $BoundKeys)
        {
            if (-not ( Get-Variable -name $param -Scope 0 -ErrorAction SilentlyContinue ) )
            {
                New-Variable -Name $Param -Value $PSBoundParameters.$Param
                Write-Verbose "Adding variable for dynamic parameter '$Param' with value '$($PSBoundParameters.$Param)'"
            }
        }

        # Set custom value for ForegroundColor
        switch ($Severity)
        {
            Information
            {
                #$Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::White
                $PSDefaultParameterValues = @{'Write-Host:ForegroundColor' = [System.ConsoleColor]::White}
            }
            Warning
            {
                #$Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Yellow
                $PSDefaultParameterValues = @{'Write-Host:ForegroundColor' = [System.ConsoleColor]::Yellow}
            }
            Error
            {
                #$Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Red
                $PSDefaultParameterValues = @{'Write-Host:ForegroundColor' = [System.ConsoleColor]::Red}
            }
        }

        switch ($Indicator)
        {
            Success
            {
                #$Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Green
                $PSDefaultParameterValues = @{'Write-Host:ForegroundColor' = [System.ConsoleColor]::Green}
            }
            Failure
            {
                #$Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Red
                $PSDefaultParameterValues = @{'Write-Host:ForegroundColor' = [System.ConsoleColor]::Red}
            }
        }

        # Define look-up table
        $IndicatorSymbols = @{
            Neutral = '*'
            Success = '+'
            Failure = '-'
        }

        # Creating a new mutex object
        $Mutex = New-Object -TypeName 'Threading.Mutex' -ArgumentList $false, 'MyInterprocMutex'
    }
    Process
    {
        #Region Write message to Host
        $Prefix = '[' + $IndicatorSymbols[[string]$Indicator] + ']'
        $Whitespaces = $null

        if ($Indent -gt 0)
        {
            $Whitespaces = ' '.PadRight(4 * $Indent)
        }

        $HostMessage = '{0}{1} {2}' -f $Whitespaces, $Prefix, $Message

        # Skip if message is empty
        if (-not ([string]::IsNullOrEmpty($Message)))
        {    
            Write-Host -Object $HostMessage
        }

        # Add new line for error record
        if ($ErrorRecord)
        {
            $ErrorRecord = $PSBoundParameters.ErrorRecord
            $HostMessage = '{0}{1} {2}' -f $Whitespaces, $Prefix, $ErrorRecord.Exception.Message
            Write-Host -Object $HostMessage
        }
        #EndRegion


        #Region Write message to log file
        $DateString = (Get-Date -Format s)
        $Command = (Get-PSCallStack)[1].Command # FunctionName
        $CommandString = "[$Command]".PadRight($Global:FunctionNameMaxLength + 2)
        $SeverityString = "[$Severity]".PadRight(11 + 2) # 'Information' = 11 characters = longest string
        $LogMessage = "{0} {1} {2} {3}" -f $DateString, $CommandString, $SeverityString, $Message

        # Skip if message is empty
        if (-not ([string]::IsNullOrEmpty($Message)))
        {
            $null = $Mutex.WaitOne()
            Add-Content -Path C:\temp\logfile.log -Value $LogMessage
            $null = $Mutex.ReleaseMutex()
        }
        
        # Add new line for error record
        if ($ErrorRecord)
        {
            $LogMessage = "{0} {1} {2} {3} ({4}: {5}:{6} char:{7})" -f $DateString, $CommandString, $SeverityString,
            $ErrorRecord.Exception.Message,
            $ErrorRecord.FullyQualifiedErrorId,
            $ErrorRecord.InvocationInfo.ScriptName,
            $ErrorRecord.InvocationInfo.ScriptLineNumber,
            $ErrorRecord.InvocationInfo.OffsetInLine

            $null = $Mutex.WaitOne()
            Add-Content -Path C:\temp\logfile.log -Value $LogMessage
            $null = $Mutex.ReleaseMutex()
        }
        #EndRegion
    }
    End
    {
        #$Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Yellow
        $PSDefaultParameterValues.Remove('Write-Host:ForegroundColor')
    }
}
#EndRegion


function LogTester
{
    [CmdletBinding()]
    param
    (
        $Text = 'Lorem ipsum dolor sit amet'
    )

    Begin
    {
    }
    
    Process
    {
        $Command = (Get-PSCallStack)[0].Command
        $TextTitle = "[$Command] $Text"

        Write-LogEntry -Message $TextTitle -Severity Information
        Write-LogEntry -Message $Text -Severity Error -Indent 1
        Write-LogEntry -Message $Text -Severity Warning -Indent 1 -Indicator Success

        $FilePath = "C:\this-does-not-exist.log"
        try
        { 
            Write-LogEntry -Message 'Get content from not existing file $FilePath' -Severity Information -Indent 1
            Get-Content -Path $FilePath -ErrorAction Stop
        }
        catch
        {
            Write-LogEntry -Severity Error -Indent 1 -ErrorRecord $Error[0]
        }
    }
    End
    {

    }
}

function LogTesterLong
{
    [CmdletBinding()]
    Param
    (
        $Text = 'Lorem ipsum dolor sit amet'
    )

    $Command = (Get-PSCallStack)[0].Command
    $TextTitle = "[$Command] $Text"

    Write-LogEntry -Message $TextTitle -Severity Information
    Write-LogEntry -Message $Text -Severity Information -Indent 1
    Write-LogEntry -Message $Text -Severity Information -Indent 2 -Indicator Failure
    Write-LogEntry -Message $Text -Severity Information -Indent 2 -Indicator Success
    Write-LogEntry -Message $Text -Severity Information -Indent 1
    Write-LogEntry -Message $Text -Severity Warning -Indent 1
    Write-LogEntry -Message $Text -Severity Warning -Indent 1 -Indicator Failure
    Write-LogEntry -Message $Text -Severity Error -Indent 2
    Write-LogEntry -Message $TextTitle
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

    try
    { 
        do-something
    }
    catch
    {
        $Text = 'Oooops an error'
        Write-LogEntry -Message $Text -Severity Error -Indicator Failure -Indent 1 -ErrorRecord $Error[0]
    }

}


LogTesterLong
LogTester
LogTesterSuperLong
#Get-Content -Path c:\temp\logfile.log
Invoke-Item c:\temp\logfile.log
