<#
    inspiration and original code from
    https://nakedpowershell.blogspot.com/2016/10/tweaks-to-write-logentry.html
    https://github.com/MSAdministrator/WriteLogEntry

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
        [Parameter(Mandatory = $true)]
        [string]
        $Message,

        [Parameter(Mandatory = $false)]
        [Severity]
        $Severity = 'Information',
        
        [Parameter(Mandatory = $false)]
        [StateIndicator]
        $Indicator = 'Neutral',

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 3)]
        [int]
        $Indent = 0
    )

    DynamicParam
    {
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        if ($Severity -eq 'Error')
        {
            # Set the dynamic parameters' name
            $ParameterName = 'ErrorRecord'

            # Set the dynamic parameters' type
            $ParameterType = [System.Management.Automation.ErrorRecord]
            
            # Create an AttributeCollection object
            $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

            # Create a ParameterAttribute object
            $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute.Mandatory = $false
            $ParameterAttribute.Position = 0
            $ParameterAttribute.HelpMessage = "Provide an error object like '$Error[0]'"

            # Add the new ParameterAttribute object to the AttributeCollection object
            $AttributeCollection.Add($ParameterAttribute)

            # Create an ValidateNotNullOrEmptyAttribute object
            $ValidateNotNullOrEmptyAttribute = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute

            # Add the ValidateNotNullOrEmptyAttribute to the attributes collection
            $AttributeCollection.Add($ValidateNotNullOrEmptyAttribute)

            # Create and add the new dynamic paramater to collection
            $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, $ParameterType, $AttributeCollection)
            $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        }
        # return the collection with the dynamic paramaters
        return $RuntimeParameterDictionary
    }

    Begin
    {
        #
        if ($PSBoundParameters.ContainsKey('ErrorRecord'))
        {
            $ErrorRecord = $PSBoundParameters.ErrorRecord
        }
        #
        #This standard block of code loops through bound parameters...
        #If no corresponding variable exists, one is created
        #Get common parameters, pick out bound parameters not in that set
        <#
        function _temp { [CmdletBinding()] param() }
        $BoundKeys = $PSBoundParameters.keys | Where-Object { (Get-Command _temp | Select-Object -ExpandProperty Parameters).Keys -notcontains $_}
        foreach ($param in $BoundKeys)
        {
            if (-not ( Get-Variable -name $param -scope 0 -ErrorAction SilentlyContinue ) )
            {
                New-Variable -Name $Param -Value $PSBoundParameters.$param
                Write-Verbose "Adding variable for dynamic parameter '$param' with value '$($PSBoundParameters.$param)'"
            }
        }
        #>
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
            #$Whitespaces = ' ' * 4 * $Indent
            $Whitespaces = ' '.PadRight(4 * $Indent)
        }

        #$Message = $Message + " ($Severity | $Indicator)"
        $HostMessage = '{0}{1} {2}' -f $Whitespaces, $Prefix, $Message
        Write-Host -Object $HostMessage

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
        $FunctionName = (Get-PSCallStack)[1].FunctionName
        $FunctionNameString = "[$FunctionName]".PadRight($Global:FunctionNameMaxLength + 2)
        $SeverityString = "[$Severity]".PadRight(11 + 2) # 'Information' = 11 characters = longest string
        $MessageString = $Message
                
        #$FunctionNameStringPaddingRight = $Global:FunctionNameMaxLength + 2
        #$LogMessage = "{0,-19} {1,-$FunctionNameStringPaddingRight} {2,-13} {3}" -f $DateString, $FunctionNameString, $SeverityString, $MessageString
        $LogMessage = "{0} {1} {2} {3}" -f $DateString, $FunctionNameString, $SeverityString, $MessageString
        Add-Content -Path C:\temp\logfile.log -Value $LogMessage

        # Add new line for error record
        if ($PSBoundParameters.ContainsKey('ErrorRecord'))
        {
            #$LogMessage = "{0,-19} {1,-$FunctionNameStringPaddingRight} {2,-13} {3} ({4}: {5}:{6} char:{7})" -f $DateString, $FunctionNameString, $SeverityString,
            $LogMessage = "{0} {1} {2} {3} ({4}: {5}:{6} char:{7})" -f $DateString, $FunctionNameString, $SeverityString,
            $ErrorRecord.Exception.Message,
            $ErrorRecord.FullyQualifiedErrorId,
            $ErrorRecord.InvocationInfo.ScriptName,
            $ErrorRecord.InvocationInfo.ScriptLineNumber,
            $ErrorRecord.InvocationInfo.OffsetInLine
            Add-Content -Path C:\temp\logfile.log -Value $LogMessage
        }
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

#LogTester
LogTesterLong
LogTesterSuperLong
#Get-Content -Path c:\temp\logfile.log
Invoke-Item c:\temp\logfile.log
