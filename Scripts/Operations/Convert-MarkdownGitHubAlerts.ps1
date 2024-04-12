[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [string]
    $InputFolder = "",

    [Parameter(Mandatory = $false, Position = 1)]
    [string]
    $OutputFolder = "",

    [Parameter(Mandatory = $false)]
    [switch] $ToGitHubAlerts
)

if ($InputFolder -eq "") {
    if ($null -eq $env:PAC_INPUT_FOLDER) {
        $InputFolder = "Docs"
    }
    else {
        $InputFolder = $env:PAC_INPUT_FOLDER
    }
}

if ($OutputFolder -eq "") {
    if ($null -eq $env:PAC_OUTPUT_FOLDER) {
        $OutputFolder = "Output"
    }
    else {
        $OutputFolder = $env:PAC_OUTPUT_FOLDER
    }
}

# Get all .md files recursively from the source folder
$inputFolderResolved = Resolve-Path -Path "$InputFolder/"
$mdFiles = Get-ChildItem -Path $InputFolder -Filter "*.md" -Recurse

# Process each .md file (preserving subfolder structure)
foreach ($file in $mdFiles) {
    # Construct the new subfolder path within the destination folder
    $inputFileFullName = $file.FullName
    $relativePath = $inputFileFullName.Replace($inputFolderResolved, "")
    $newPath = Join-Path -Path $OutputFolder -ChildPath $relativePath
    $newFolder = Split-Path -Path $newPath -Parent

    # Create the subfolder if it doesn't exist
    if (-not (Test-Path -Path $newFolder)) {
        New-Item -ItemType Directory -Path $newFolder | Out-Null
    }

    $inAlert = $false
    $typeString = "---"
    $toGitHubAlertsLocal = $ToGitHubAlerts
    # $toGitHubAlertsLocal = $true
    if ($toGitHubAlertsLocal) {
        $alertLines = 0
        Get-Content -Path $inputFileFullName | ForEach-Object {
            if ($_.StartsWith("!!! ")) {
                $subString = $_.Substring(4)
                $typeString = $subString.Trim()
                $inAlert = $true
                $alertlines = 0
                switch ($typeString) {
                    "note" {
                        "> [!NOTE]"
                    }
                    "abstract" {
                        "> [!NOTE]"
                    }
                    "info" {
                        "> [!NOTE]"
                    }
                    "success" {
                        "> [!NOTE]"
                    }
                    "question" {
                        "> [!NOTE]"
                    }
                    "example" {
                        "> [!NOTE]"
                    }
                    "tip" {
                        "> [!TIP]"
                    }
                    "success `"Important`"" {
                        "> [!IMPORTANT]"
                    }
                    "tip `"Important`"" {
                        "> [!IMPORTANT]"
                    }
                    "warning" {
                        "> [!WARNING]"
                    }
                    "danger `"Caution`"" {
                        "> [!CAUTION]"
                    }
                    "danger" {
                        "> [!CAUTION]"
                    }
                    "failure" {
                        "> [!CAUTION]"
                    }
                    "bug" {
                        "> [!CAUTION]"
                    }
                    default {
                        throw "Unsupported admonition type: $typeString"
                    }
                }
            }
            elseif ($inAlert) {
                if ($alertLines -eq 1) {
                    if ($_.StartsWith("    ") -and $_.Length -gt 4) {
                        $lineOut = "> $($_.Substring(4))"
                        $lineOut
                        $inAlert = $false
                    }
                    else {
                        throw "Invalid admonition format; admonition text must be indented by 4 spaces and not empty"
                    }
                }
                else {
                    $alertLines++
                    if (($alertLines -gt 1) -or (-not [string]::IsNullOrWhiteSpace($_))) {
                        throw "Invalid admonition format; exactly empty line is required between admonition type and text"
                    }
                }
            }
            else {
                $_
            }
        } | Out-File -FilePath $newPath -Force
    }
    else {
        Get-Content -Path $inputFileFullName | ForEach-Object {
            if ($_.StartsWith("> [!")) {
                $typeString = $_.Trim()
                $inAlert = $true
                switch ($typeString) {
                    "> [!NOTE]" {
                        "!!! note"
                    }
                    "> [!TIP]" {
                        "!!! tip"
                    }
                    "> [!IMPORTANT]" {
                        "!!! tip `"Important`""
                    }
                    "> [!WARNING]" {
                        "!!! warning"
                    }
                    "> [!CAUTION]" {
                        "!!! danger `"Caution`""
                    }
                    default {
                        throw "Unsupported admonition type: $typeString"
                    }
                }
                ""
            }
            elseif ($inAlert) {
                if ($_.StartsWith("> ")) {
                    "    $($_.Substring(2))"
                    $inAlert = $false
                }
                else {
                    throw "Invalid alerts format; alerts text must start with '> '"
                }
            }
            else {
                $_
            }
        } | Out-File -FilePath $newPath -Force
    }
}