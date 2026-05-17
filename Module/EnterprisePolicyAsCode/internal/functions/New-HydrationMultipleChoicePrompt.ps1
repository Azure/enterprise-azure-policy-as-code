function New-HydrationMultipleChoicePrompt {
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Management.Automation.OrderedHashtable]
        $List # = [ordered]@{}
    )
    # TODO: Move to file, test block
    # $List = [ordered]@{
    #     "Option1" = @{
    #         title       = "First Title"
    #         returnData  = "returnValue1"
    #         description = "This is the first option"
    #     }
    #     "Option2" = @{
    #         title       = "Second Title"
    #         returnData  = "returnValue2"
    #         description = "This is the second option"
    #     }
    #     "Option3" = @{
    #         title       = "Third Title"
    #         returnData  = "returnValue3"
    #         description = "This is the third option"
    #     }
    # }
    $scriptReturn = $null
    # Build the question prompt
    $choiceList = [ordered]@{}
    $keyString = ""
    foreach ($item in $List.keys) {
        # Write-Host $item
        # $List.$item.title
        New-Variable -Name $item -Value $(New-Object System.Management.Automation.Host.ChoiceDescription `
                "`&$($List.$item.title)", 
            "$($List.$item.description)")
        $choiceList.add($item, $(Get-Variable $item -ValueOnly))
        if ($keyString -eq "") {
            $keyString = "`$$item"
        }
        else {
            $keyString = -join ($keyString, ", `$", $item)
        }
        Write-Host "TODO: DEBUG:"
        # $questionPrompt = $questionPrompt + "`n$($item.Key): $($item.Value.description)"
    }
    $multipleChoiceOptions = [System.Management.Automation.Host.ChoiceDescription[]]($choiceList.values)
    $multipleChoiceMessage = "The current user does not have the necessary rights to create or read Management Groups. This will prevent much of the guidance provided as part of this deployment tool, as well as leave management group creation to manual operations. For these reasons, continuing is not recommended."
    $multipleChoiceTitle = "Consider whether or not you wish to proceed (not recommended)..."
    
    # Ask the question
    $scriptResponse = $host.ui.PromptForChoice($multipleChoiceTitle, $multipleChoiceMessage, $multipleChoiceOptions, 0)
    
    # Dynamically build the switch cases based on the number of items in $List so that we can evaluate the choice made
    $index = 0
    $switchCases = $List.GetEnumerator() | ForEach-Object {
        "`"$index`" { `$scriptReturn = `"$($_.Value.returnData)`" }"
        $index++
    }
    # Removing this as it won't be useful anywhwere else, and we don't want anyone to think otherwise.
    Remove-Variable index
    # Combine the switch cases into a single script block
    # $scriptBlock = [scriptblock]::Create("switch -Regex (`"^" + (1..$foo.Count -join "|") + "`$") { $($switchCases -join "`n") default { `$scriptReturn = 'Not found' } }")
    # Corrected what appeared to be a typo, if this errors, go ahead and set it back
    Write-Host "TODO: Do a log entry."
    $scriptBlock = [scriptblock]::Create("switch (`$scriptResponse) { $($switchCases -join "`n") default { `$scriptReturn = 'Error: Not found' } }")
    # Execute the script block to evaluate the response
    . $scriptBlock
    # Return the result
    # TODO: Change line below to log entry
    Write-Host "$scriptReturn"
    return $scriptReturn
}
