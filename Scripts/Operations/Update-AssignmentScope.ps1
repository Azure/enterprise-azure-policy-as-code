<#
.SYNOPSIS
    Append, Set, or Delete a scope/notScopes selector inside one or more EPAC
    policy assignment definition files.

.DESCRIPTION
    Edits the "scope" (default) or "notScopes" block of every node in an EPAC
    assignment file (root and any nested entries under "children[]") that matches
    the optional NodeName / AssignmentName filters.

    Actions:
      Append  - Add Values to the selector's array (dedupes). Creates the
                selector if it doesn't exist.
      Set     - Overwrite the selector's array with Values. Creates the selector
                if it doesn't exist.
      Delete  - Remove the entire selector key from the block.

    JSONC notes:
      - Input is parsed leniently (// and /* */ comments, trailing commas allowed).
      - Output is re-serialized as standard JSON. If the file contains comments
        they will be lost on save and the script warns before writing.

.PARAMETER Path
    Optional. File or folder. When omitted, defaults to
    "<repo>/Definitions/policyAssignments" relative to this script and recurses
    automatically. When a folder is supplied, pass -Recurse to descend into
    subfolders.

.PARAMETER Scope
    Selector name inside the assignment file's "scope" block (e.g.
    TenantRootGroup, NonProd, EPAC-Prod). Mutually exclusive with -NotScopes.

.PARAMETER NotScopes
    Selector name inside the assignment file's "notScopes" block. Mutually
    exclusive with -Scope.

.PARAMETER Action
    Append | Set | Delete

.PARAMETER Values
    Required for Append and Set. The full resource path(s), e.g.
    "/providers/Microsoft.Management/managementGroups/<id>".

.PARAMETER NodeName
    Optional. Only edit nodes whose "nodeName" property equals this value.

.PARAMETER AssignmentName
    Optional. Only edit nodes whose "assignment.name" property equals this value.

.PARAMETER Recurse
    When Path is a folder, descend into subfolders.

.PARAMETER Backup
    Write a *.bak copy beside each modified file before saving.

.EXAMPLE
    # Add a new selector "NonProd" with one MG path on every node
    .\Update-AssignmentScope.ps1 `
        -Path .\Definitions\policyAssignments\RestrictPublicAccess-Assignment-20260423.jsonc `
        -Scope NonProd -Action Append `
        -Values "/providers/Microsoft.Management/managementGroups/00000000-0000-0000-0000-000000000000"

.EXAMPLE
    # Overwrite the TenantRootGroup selector on a specific node
    .\Update-AssignmentScope.ps1 -Path .\Definitions\policyAssignments\file.jsonc `
        -NodeName "TenantRootGroup/" -Scope TenantRootGroup -Action Set `
        -Values "/providers/Microsoft.Management/managementGroups/abc"

.EXAMPLE
    # Remove the NonProd selector from every node in every file under the folder
    .\Update-AssignmentScope.ps1 -Path .\Definitions\policyAssignments -Recurse `
        -Scope NonProd -Action Delete -Backup

.EXAMPLE
    # Append a path to the TenantRootGroup selector inside the notScopes block
    .\Update-AssignmentScope.ps1 `
        -NotScopes TenantRootGroup -Action Append `
        -Values "/subscriptions/00000000-0000-0000-0000-000000000000"
#>
[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Scope')]
param(
    [Parameter(Mandatory = $false)]
    [string] $Path,

    # Selector name inside the assignment file's "scope" block (e.g. TenantRootGroup, NonProd).
    [Parameter(Mandatory = $true, ParameterSetName = 'Scope')]
    [string] $Scope,

    # Selector name inside the assignment file's "notScopes" block. Mutually exclusive with -Scope.
    [Parameter(Mandatory = $true, ParameterSetName = 'NotScopes')]
    [string] $NotScopes,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Append', 'Set', 'Delete')]
    [string] $Action,

    [string[]] $Values,

    [string] $NodeName,

    [string] $AssignmentName,

    [switch] $Recurse,

    [switch] $Backup
)

# Resolve which block ("scope" vs "notScopes") and selector name we're targeting
$blockKey = if ($PSCmdlet.ParameterSetName -eq 'NotScopes') { 'notScopes' } else { 'scope' }
$selector = if ($PSCmdlet.ParameterSetName -eq 'NotScopes') { $NotScopes } else { $Scope }

#region helpers
function ConvertFrom-JsoncText {
    param([string] $Text)

    # Strip block comments
    $stripped = [regex]::Replace($Text, '/\*[\s\S]*?\*/', '')

    # Strip line comments (skip // inside strings)
    $sb = [System.Text.StringBuilder]::new($stripped.Length)
    $inString = $false
    $escape = $false
    $i = 0
    while ($i -lt $stripped.Length) {
        $c = $stripped[$i]
        if ($escape) { [void]$sb.Append($c); $escape = $false; $i++; continue }
        if ($c -eq '\') { [void]$sb.Append($c); $escape = $true; $i++; continue }
        if ($c -eq '"') { $inString = -not $inString; [void]$sb.Append($c); $i++; continue }
        if (-not $inString -and $c -eq '/' -and ($i + 1) -lt $stripped.Length -and $stripped[$i + 1] -eq '/') {
            while ($i -lt $stripped.Length -and $stripped[$i] -ne "`n") { $i++ }
            continue
        }
        [void]$sb.Append($c); $i++
    }
    $clean = $sb.ToString()

    # Strip trailing commas before } or ]
    $clean = [regex]::Replace($clean, ',(\s*[}\]])', '$1')

    return ($clean | ConvertFrom-Json -AsHashtable -Depth 100)
}

function Test-HasComments {
    param([string] $Text)
    # Simple/cheap heuristic — false positives possible if // or /* appear in strings.
    return ($Text -match '(^|[^:])//' -or $Text -match '/\*')
}

function Update-ScopeBlock {
    <#
        Mutates a single node's scope (or notScopes) hashtable in place.
        Returns $true if the node was modified, $false otherwise.
    #>
    param(
        [hashtable] $Node,
        [string]    $BlockKey,    # 'scope' or 'notScopes'
        [string]    $Selector,
        [string]    $Action,
        [string[]]  $Values
    )

    # Ensure block exists for Append/Set; nothing to do for Delete on a missing block
    if (-not $Node.ContainsKey($BlockKey)) {
        if ($Action -eq 'Delete') { return $false }
        $Node[$BlockKey] = [ordered]@{}
    }

    $block = $Node[$BlockKey]
    # Coerce non-hashtable (e.g. PSCustomObject after rehydration) into hashtable
    if ($block -isnot [System.Collections.IDictionary]) {
        $coerced = [ordered]@{}
        foreach ($prop in $block.PSObject.Properties) { $coerced[$prop.Name] = $prop.Value }
        $block = $coerced
        $Node[$BlockKey] = $block
    }

    switch ($Action) {
        'Delete' {
            if ($block.Contains($Selector)) {
                $null = $block.Remove($Selector)
                return $true
            }
            return $false
        }
        'Set' {
            $block[$Selector] = @($Values)
            return $true
        }
        'Append' {
            $existing = @()
            if ($block.Contains($Selector) -and $null -ne $block[$Selector]) {
                $existing = @($block[$Selector])
            }
            $merged = [System.Collections.Generic.List[string]]::new()
            foreach ($v in $existing) { if ($v -and -not $merged.Contains($v)) { $merged.Add($v) } }
            $changed = $false
            foreach ($v in $Values) {
                if ($v -and -not $merged.Contains($v)) { $merged.Add($v); $changed = $true }
            }
            $block[$Selector] = $merged.ToArray()
            return $changed
        }
    }
}

function Invoke-NodeWalk {
    <#
        Recursively walks a node and its children[]. For each node that matches
        the filters, applies the mutation. Returns the count of modified nodes.
    #>
    param(
        [hashtable] $Node,
        [string]    $BlockKey,
        [string]    $Selector,
        [string]    $Action,
        [string[]]  $Values,
        [string]    $NodeNameFilter,
        [string]    $AssignmentNameFilter
    )

    $modified = 0

    $matchesNodeName = (-not $NodeNameFilter) -or ($Node.nodeName -eq $NodeNameFilter)
    $assignmentName  = if ($Node.ContainsKey('assignment') -and $Node.assignment) { $Node.assignment.name } else { $null }
    $matchesAssign   = (-not $AssignmentNameFilter) -or ($assignmentName -eq $AssignmentNameFilter)

    if ($matchesNodeName -and $matchesAssign) {
        # Only consider this node a candidate if it carries the relevant block
        # (or we're going to create one for Append/Set). To avoid touching the
        # purely-organizational root in files where edits aren't intended there,
        # we skip nodes that have neither scope nor notScopes nor any
        # assignment/parameter context — basically the bare root passthrough.
        $isRealNode = $Node.ContainsKey('scope') -or $Node.ContainsKey('notScopes') `
            -or $Node.ContainsKey('assignment') -or $Node.ContainsKey('parameters') `
            -or $Node.ContainsKey('enforcementMode')

        if ($isRealNode) {
            if (Update-ScopeBlock -Node $Node -BlockKey $BlockKey -Selector $Selector -Action $Action -Values $Values) {
                $modified++
            }
        }
    }

    if ($Node.ContainsKey('children') -and $Node.children) {
        foreach ($child in $Node.children) {
            if ($child -is [System.Collections.IDictionary]) {
                $modified += Invoke-NodeWalk -Node $child -BlockKey $BlockKey -Selector $Selector `
                    -Action $Action -Values $Values `
                    -NodeNameFilter $NodeNameFilter -AssignmentNameFilter $AssignmentNameFilter
            }
        }
    }

    return $modified
}
#endregion helpers

# Validate parameter combinations
if ($Action -in @('Append', 'Set') -and (-not $Values -or $Values.Count -eq 0)) {
    Write-Error "Action '$Action' requires -Values."
    exit 1
}
if ($Action -eq 'Delete' -and $Values) {
    Write-Warning "Values are ignored when Action=Delete."
}

# Resolve target files
$defaultFolderUsed = $false
if (-not $Path) {
    # Default resolution order (matches EPAC convention used by Build-DeploymentPlans):
    #   1. $env:PAC_DEFINITIONS_FOLDER  (+ /policyAssignments)
    #   2. <cwd>/Definitions/policyAssignments
    # Note: $PSScriptRoot is intentionally NOT used here. When this script is
    # exposed via the EnterprisePolicyAsCode module, $PSScriptRoot points at
    # the installed module path, not the user's EPAC repo.
    $definitionsRoot = if ($env:PAC_DEFINITIONS_FOLDER) {
        $env:PAC_DEFINITIONS_FOLDER
    }
    else {
        Join-Path (Get-Location).Path 'Definitions'
    }
    $Path = Join-Path $definitionsRoot 'policyAssignments'
    $defaultFolderUsed = $true
    Write-Host "No -Path supplied; defaulting to '$Path' (recursive)."
}

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "Path not found: $Path"
    exit 1
}
$resolved = Get-Item -LiteralPath $Path
$files = if ($resolved.PSIsContainer) {
    $recurseFolder = $Recurse -or $defaultFolderUsed
    Get-ChildItem -LiteralPath $resolved.FullName -Filter *.jsonc -File -Recurse:$recurseFolder
}
else {
    , $resolved
}

if (-not $files -or $files.Count -eq 0) {
    Write-Warning "No .jsonc files found at: $Path"
    exit 0
}

$totalFiles = 0
$totalNodes = 0

foreach ($file in $files) {
    $raw = Get-Content -LiteralPath $file.FullName -Raw
    if (-not $raw) { continue }

    try {
        $obj = ConvertFrom-JsoncText -Text $raw
    }
    catch {
        Write-Warning "Skipping $($file.FullName): JSON parse error — $($_.Exception.Message)"
        continue
    }

    if ($obj -isnot [System.Collections.IDictionary]) {
        Write-Warning "Skipping $($file.FullName): root is not an object."
        continue
    }

    $modified = Invoke-NodeWalk -Node $obj -BlockKey $blockKey -Selector $selector `
        -Action $Action -Values $Values `
        -NodeNameFilter $NodeName -AssignmentNameFilter $AssignmentName

    if ($modified -eq 0) {
        Write-Verbose "No changes for $($file.FullName)"
        continue
    }

    if (Test-HasComments -Text $raw) {
        Write-Warning "$($file.Name): file contains JSONC comments — they will be lost on save."
    }

    $newJson = $obj | ConvertTo-Json -Depth 100

    if ($PSCmdlet.ShouldProcess($file.FullName, "Update $modified node(s) — $blockKey/$selector/$Action")) {
        if ($Backup) {
            Copy-Item -LiteralPath $file.FullName -Destination "$($file.FullName).bak" -Force
        }
        Set-Content -LiteralPath $file.FullName -Value $newJson -Encoding utf8NoBOM
        Write-Host "Updated $modified node(s) in $($file.Name)"
        $totalFiles++
        $totalNodes += $modified
    }
}

Write-Host ""
Write-Host "Done. Modified $totalNodes node(s) across $totalFiles file(s)."
