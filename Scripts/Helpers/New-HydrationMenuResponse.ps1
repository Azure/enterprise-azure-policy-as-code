function New-HydrationMenuResponse {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.OrderedHashtable]
        $OptionHashtable,
        [Parameter(Mandatory = $false)]
        [string]
        $DataRequest = "Please select an option from the list below:"
    )

    $choices = @()
    foreach ($key in $OptionHashtable.Keys) {
        $choices += [System.Management.Automation.Host.ChoiceDescription]::new($( -join ("&", $key)), $OptionHashtable.$key)
    }
    
    $caption = ""
    $message = "`n$DataRequest"
    $result = $host.ui.PromptForChoice($caption, $message, $choices, 0)
    return ($choices[$result].Label | Select-String -Pattern "^&(.+)" -AllMatches).Matches[0].Groups[1].Value
}