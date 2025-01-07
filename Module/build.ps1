New-Item .\Module\EnterprisePolicyAsCode\internal\functions -ItemType Directory -Force
New-Item .\Module\EnterprisePolicyAsCode\functions -ItemType Directory -Force

$tag_name = $env:TAG_NAME -replace "v", ""

if ($tag_name -match "-") {
    Copy-Item -Path .\Module\EnterprisePolicyAsCode.prerelease.psd1 -Destination .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1 -Force
    $isPreRelease = $true
}
else {
    Copy-Item -Path .\Module\EnterprisePolicyAsCode.release.psd1 -Destination .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1 -Force
}

Get-ChildItem -Path .\Scripts\Helpers\*.ps1 -Recurse -File -Exclude Add-HelperScripts.ps1 | Copy-Item -Destination .\Module\EnterprisePolicyAsCode\internal\functions

# Deploy Functions

$functionNames = (Get-ChildItem .\Scripts\Deploy\* -File -Include *.ps1).BaseName

$functionNames | Foreach-Object {
    "function $_ {" | Set-Content ".\Module\EnterprisePolicyAsCode\functions\$_.ps1" -Force
    Get-Content .\Scripts\Deploy\$_.ps1 | Where-Object { $_ -notmatch "^\." -and $_ -notmatch "^#Requires" } | Add-Content ".\Module\EnterprisePolicyAsCode\functions\$_.ps1" -Force
    "}" | Add-Content ".\Module\EnterprisePolicyAsCode\functions\$_.ps1" -Force
}

# Operations

$functionNames = (Get-ChildItem .\Scripts\Operations\* -File -Include *.ps1).BaseName

$functionNames | Foreach-Object {
    "function $_ {" | Set-Content ".\Module\EnterprisePolicyAsCode\functions\$_.ps1" -Force
    Get-Content .\Scripts\Operations\$_.ps1 | Where-Object { $_ -notmatch "^\." -and $_ -notmatch "^#Requires" } | Add-Content ".\Module\EnterprisePolicyAsCode\functions\$_.ps1" -Force
    "}" | Add-Content ".\Module\EnterprisePolicyAsCode\functions\$_.ps1" -Force
}

# Cloud Adoption Framework

$functionNames = (Get-ChildItem .\Scripts\CloudAdoptionFramework\* -File -Include *.ps1).BaseName

$functionNames | Foreach-Object {
    "function $_ {" | Set-Content ".\Module\EnterprisePolicyAsCode\functions\$_.ps1" -Force
    Get-Content .\Scripts\CloudAdoptionFramework\$_.ps1 | Where-Object { $_ -notmatch "^\." -and $_ -notmatch "^#Requires" } | Add-Content ".\Module\EnterprisePolicyAsCode\functions\$_.ps1" -Force
    "}" | Add-Content ".\Module\EnterprisePolicyAsCode\functions\$_.ps1" -Force
}

# Hydration Kit

Get-ChildItem -Path .\Scripts\HydrationKit\*.ps1 -Recurse -File | Copy-Item -Destination .\Module\EnterprisePolicyAsCode\functions

Copy-Item -Path .\Scripts\CloudAdoptionFramework\policyAssignments -Destination .\Module\EnterprisePolicyAsCode -Force -Recurse

(Get-Content -Path .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1) -replace "FunctionsToExport = ''", "FunctionsToExport = @($((Get-ChildItem -Path .\Module\EnterprisePolicyAsCode\functions | Select-Object -ExpandProperty BaseName) | Join-String -Separator "," -DoubleQuote))" | Set-Content .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1

if ($isPreRelease) {
    $version = ($tag_name -split "-")[0]
    $prereleaseString = ($tag_name -split "-")[1]
    (Get-Content -Path .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1) -replace "ModuleVersion     = ''", "ModuleVersion     = '$version'" | Set-Content .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1
    (Get-Content -Path .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1) -replace "Prerelease     = ''", "Prerelease     = '$prereleaseString'" | Set-Content .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1
    Get-Content -Path .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1
}
else {
    (Get-Content -Path .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1) -replace "ModuleVersion     = ''", "ModuleVersion     = '$tag_name'" | Set-Content .\Module\EnterprisePolicyAsCode\EnterprisePolicyAsCode.psd1
}


