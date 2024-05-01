<#
.SYNOPSIS
    This function updates the assignment scope of the Hydration Starter Kit.

.DESCRIPTION
    The Update-HydrationStarterKitAssignmentScope function updates the assignment scope of the Hydration Starter Kit based on the provided parameters.

.PARAMETER Json
    The path to the JSON file from the StarterKit that will be modified.

.PARAMETER Csv
    The path to the CSV file from the StarterKit that will be modified.

.PARAMETER outputCsv
    The path where the output CSV file will be created.

.PARAMETER outputJson
    The path where the output JSON file will be created.

.PARAMETER Assignment
    The assignment object that will be used as .

.PARAMETER CsvData
    The CSV data object.

.PARAMETER answers
    The answers hashtable.

.EXAMPLE
    Update-HydrationStarterKitAssignmentScope -Json "./input.json" -Csv "./input.csv" -outputCsv "./output.csv" -outputJson "./output.json" -Assignment $assignment -CsvData $csvData -answers $answers

    This example updates the assignment scope of the Hydration Starter Kit using the provided parameters.

.NOTES
    The function creates a new directory if the directory of the output CSV file does not exist. It then iterates over the environments in the answers. If the branching flow is "github", it removes the non-production columns from the CSV data and the non-production block from the assignment. Otherwise, it keeps all the columns and blocks. It then updates the scope of each child in the assignment.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>
function Update-HydrationStarterKitAssignmentScope {

    param (
        [string]$outputCsv,
        [string]$outputJson,
        [PSCustomObject]$Assignment,
        [PSCustomObject]$CsvData,
        [System.Management.Automation.OrderedHashtable]$answers
    )
    # TODO: Add another set that replaces answers with branchflow and environments var as a second set of inputs instead of answers
    $InformationPreference = "Continue"
    if (!(Test-Path (Split-Path $outputCsv))) {
        New-Item -ItemType Directory -Path (Split-Path $outputCsv) -Force | Out-Null
    }
    foreach ($env in $answers.environments) {
        if ($answers.branchingFlow -eq "github") {
            # Remove Non-Prod columns
            Write-Information "Creating $outputCsv"
            $CsvData | Select-Object -ExcludeProperty nonprod*  | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding ascii -Force
            # Remove Non-Prod Block
            $newAssignmentChildren = $Assignment.children | Where-Object { $_.parameterSelector -eq "prod" }
        }
        else {
            Write-Information "Creating $outputCsv"
            $CsvData | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding ascii -Force
            # Remove Non-Prod Block
            $newAssignmentChildren = $Assignment.children 
        }
        foreach ($child in $newAssignmentChildren) {
            $child.scope = [ordered]@{}
            foreach ($scope in $answers.environments.keys) {
                $child.scope.add($answers.environments.$scope.pacSelector, $( -join ("/providers/Microsoft.Management/managementGroups/", $answers.environments.$scope.initialPolicyScope)))
            }
        }
        $Assignment.children = @($newAssignmentChildren)
    }
    Write-Information "Creating $outputJson"
    $Assignment | ConvertTo-Json -Depth 20 | Out-File -FilePath $outputJson -Encoding ascii -Force
}