<#
.SYNOPSIS
    This function filters exemptions from a CSV file based on relevant policy assignments and outputs the filtered exemptions to a new CSV file.
.DESCRIPTION
    The New-FilteredExceptionFile function takes a CSV file of exemptions and filters it based on relevant policy assignments found in the Definitions folder. 
    The filtered exemptions are then output to a new CSV file in the specified Output folder.
.PARAMETER ExemptionsCsv
    The path to the CSV file containing the exemptions.
.PARAMETER OutputFolder
    The path to the Output directory. Defaults to './Output'.
.PARAMETER DefinitionsFolder
    The path to the Definitions directory. Defaults to './Definitions'.
.EXAMPLE
    New-FilteredExceptionFile -ExemptionsCsv "C:\path\to\exemptions.csv"
    This example filters the exemptions from the specified CSV file and outputs the filtered exemptions to the default Output folder.
#>
function New-FilteredExceptionFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The path to the CSV file containing the exemptions.")]
        [string]
        $ExemptionsCsv,
        [Parameter(Mandatory = $false, HelpMessage = "The path to the Output directory. Defaults to './Output'.")]
        [string]
        $OutputFolder = './Output',
        [Parameter(Mandatory = $false, HelpMessage = "The path to the Definitions directory. Defaults to './Definitions'.")]
        [string]
        $DefinitionsFolder = './Definitions'
    )

    $environment = Split-Path (Split-Path (Resolve-Path $ExemptionsCsv).path ) -Leaf
    $outputCsv = Join-Path $OutputFolder 'UpdatedExemptions' $environment 'active-exemptions.csv'
    $Definitions = $DefinitionsFolder
    if(!(Test-Path $(Split-Path $outputCsv))){
        New-Item -ItemType Directory -Path $(Split-Path $outputCsv) -Force
    }
    $relevantExemptionList = @()
    $activeExemptionsList = Get-Content  $ExemptionsCsv | ConvertFrom-Csv 
    $assignmentList = Get-ChildItem `
        -Path $(Join-Path (Resolve-Path $Definitions) 'policyAssignments') `
        -Include '*.json', '*.jsonc' `
        -Recurse

    $policyAssignmentContent = [ordered]@{}
    foreach($assignment in $assignmentList){
        $policyAssignmentContent.Add($assignment.FullName, `
            $(Get-Content $assignment.FullName `
            | ConvertFrom-Json -AsHashtable -Depth 100)) 
    }

    foreach($exemption in $activeExemptionsList){
        try{
            $exemptionAssignment = Split-Path $exemption.policyAssignmentId -Leaf
        }
        catch{
            Write-Error "Error: $($_.Exception.Message)"
        }
        if($policyAssignmentContent.values.assignment.name -contains $exemptionAssignment){
            write-host "    $($exemption.name) is relevant, importing"
            $relevantExemptionList += $exemption
        }
    }
    $relevantExemptionList | Export-Csv -Path $outputCsv -NoTypeInformation
    return "Processed $outputCsv"
}