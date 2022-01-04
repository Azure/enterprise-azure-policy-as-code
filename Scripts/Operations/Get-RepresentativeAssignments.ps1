$repAssignments = @{
    SANDBOX = @(
        "/providers/Microsoft.Management/managementGroups/NBA-IT-Sandbox-Env/providers/Microsoft.Authorization/policyAssignments/Azure Security Benchmark",
        "/providers/Microsoft.Management/managementGroups/NBA-IT-Sandbox-Env/providers/Microsoft.Authorization/policyAssignments/Org Delta - Sandbox"
    )
    DEV     = @(
        "/providers/Microsoft.Management/managementGroups/NBA-IT-Non-Prod-Env/providers/Microsoft.Authorization/policyAssignments/Azure Security Benchmark",
        "/providers/Microsoft.Management/managementGroups/NBA-IT-Non-Prod-Env/providers/Microsoft.Authorization/policyAssignments/Org Delta - NonProd"
    )
    NONPROD = @(
        "/providers/Microsoft.Management/managementGroups/NBA-IT-Non-Prod-Env/providers/Microsoft.Authorization/policyAssignments/Azure Security Benchmark",
        "/providers/Microsoft.Management/managementGroups/NBA-IT-Non-Prod-Env/providers/Microsoft.Authorization/policyAssignments/Org Delta - NonProd"
    )
    PROD    = @(
        "/providers/Microsoft.Management/managementGroups/NBA-IT-Prod-Env/providers/Microsoft.Authorization/policyAssignments/Azure Security Benchmark",
        "/providers/Microsoft.Management/managementGroups/NBA-IT-Prod-Env/providers/Microsoft.Authorization/policyAssignments/Org Delta - Prod"
    )
}
$rootScope = "/providers/Microsoft.Management/managementGroups/e898ff4a-4b69-45ee-a3ae-1cd6f239feb2"
$envTagList = @( "SANDBOX", "DEV", "NONPROD", "PROD") # Hashtables to not preserve order. This orders the columns

$envTagList, $repAssignments, $rootScope