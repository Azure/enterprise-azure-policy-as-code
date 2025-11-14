function Export-HydrationObjectToJsonFile {
    <#
    .SYNOPSIS
        Updates the names in a JSON file and saves the updated JSON to a specified output file.

    .DESCRIPTION
        The Export-HydrationObjectToJsonFile function takes a JSON object, and saves the updated JSON to a specified output file. If the output folder does not exist, it will be created.

    .PARAMETER Object
        The JSON object to be updated.

    .PARAMETER OutputFilePath
        The path to the output file where the updated JSON will be saved.

    .EXAMPLE
        $json = Get-Content -Path "input.json" | ConvertFrom-Json
        Export-HydrationObjectToJsonFile -Object $json -OutputFilePath "C:\Output\output.json"

        This example reads the content of "input.json" file, converts it to a JSON object, updates the names in the JSON, and saves the updated JSON to "output.json" file in the "C:\Output" folder.
    .LINK
        https://aka.ms/epac
        https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md

    #>

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        $InputObject, 
        [Parameter(Mandatory = $true)]
        [string]
        $OutputFilePath,
        [switch]
        $Compress
    )
    $outputFolder = Split-Path -Path $OutputFilePath
    if (!(Test-Path -Path $outputFolder)) {
        Write-Debug "Creating directory $outputFolder..."
        $null = New-Item -Path  $outputFolder -ItemType Directory -Force
    }
    $InputObject | ConvertTo-Json -Depth 100 -Compress:$Compress | Set-Content -Path $OutputFilePath
}