param (
    [Parameter(Mandatory=$true)][string]$defRootFolder
)

$policyDefRootFolder = $defRootFolder + "\Policies"

Write-Host "##[debug] gettine file sturcture for: $policyDefRootFolder"

$root = Get-ChildItem $policyDefRootFolder

$policies = @()

foreach ($dir in $root) {

    Write-Host "##[debug] processing directory: $($dir.Name)"

    $content = Get-ChildItem ($policyDefRootFolder + "\" + $($dir.Name))

    foreach ($item in $content) {

        Write-Host "    ##[debug] processing: $item"

        if ($item.Attributes -eq "Directory") {

            Write-Host "        ##[debug] Object is a dir, getting contents"

            $content1 = Get-ChildItem ($policyDefRootFolder + "\" + $($dir.Name) + "\" + $($item.Name))

            $policies += $content1.DirectoryName
        }
        else {


            Write-Host "        ##[debug] Object is a policy, adding to list"

            $policies += $item.DirectoryName
        }
    }
}

$policies = $policies | Sort-Object -Unique

$allPolicies = @()

foreach ($policy in $policies) {

    $allPolicies += ($policy.TrimStart($defRootFolder)) + "\"
}

$allPolicies = ($allPolicies | ConvertTo-Json -Compress).Trim("[","]")

Write-Output "Unique Policies: $allPolicies"

Write-Output "##vso[task.setvariable variable=allPolicies]$allPolicies"