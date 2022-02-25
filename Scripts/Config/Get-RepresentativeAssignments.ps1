$repAssignments = @{
    SANDBOX = @(
        "/providers/Microsoft.Management/managementGroups/mmmmmmm/providers/Microsoft.Authorization/policyAssignments/Azure Security Benchmark",
        "/providers/Microsoft.Management/managementGroups/mmmmmmm/providers/Microsoft.Authorization/policyAssignments/Org Delta - Sandbox"
    )
    DEV     = @(
        "/providers/Microsoft.Management/managementGroups/mmmmmmm/providers/Microsoft.Authorization/policyAssignments/Azure Security Benchmark",
        "/providers/Microsoft.Management/managementGroups/mmmmmmm/providers/Microsoft.Authorization/policyAssignments/Org Delta - NonProd"
    )
    NONPROD = @(
        "/providers/Microsoft.Management/managementGroups/mmmmmmm/providers/Microsoft.Authorization/policyAssignments/Azure Security Benchmark",
        "/providers/Microsoft.Management/managementGroups/mmmmmmm/providers/Microsoft.Authorization/policyAssignments/Org Delta - NonProd"
    )
    PROD    = @(
        "/providers/Microsoft.Management/managementGroups/mmmmmmm/providers/Microsoft.Authorization/policyAssignments/Azure Security Benchmark",
        "/providers/Microsoft.Management/managementGroups/mmmmmmm/providers/Microsoft.Authorization/policyAssignments/Org Delta - Prod"
    )
}
$rootScope = "/providers/Microsoft.Management/managementGroups/<guid>"
$envTagList = @( "SANDBOX", "DEV", "NONPROD", "PROD") # Hashtables to not preserve order. This orders the columns

$envTagList, $repAssignments, $rootScope