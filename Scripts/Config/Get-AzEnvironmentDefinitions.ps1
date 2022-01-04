# conatins settings for testing different environments

function Get-AzEnvironmentDefinitions {
    $tenantId = "tenant-id-guid"
    $environemts = @{
        prod = @{
            tenantId           = $tenantId
            rootScope          = "/providers/Microsoft.Management/managementGroups/tenant-id-guid"
            scopeParam         = @{ ManagementGroupName = "tenant-id-guid" }
            assignmentSelector = "PAC-PROD"
            planFile           = "./Output/Plans/prod.json" 
        }
        qa   = @{
            tenantId           = $tenantId
            rootScope          = "/subscriptions/qa-subscription-guid"
            scopeParam         = @{ SubscriptionId = "qa-subscription-guid" }
            assignmentSelector = "PAC-QA"
            planFile           = "./Output/Plans/qa.json" 
        } 
        dev2 = @{
            tenantId           = $tenantId
            rootScope          = "/subscriptions/dev2-subscription-guid"
            scopeParam         = @{ SubscriptionId = "dev2-subscription-guid" }
            assignmentSelector = "PAC-DEV-002"
            planFile           = "./Output/Plans/dev001.json" 
        } 
        dev1 = @{
            tenantId           = $tenantId
            rootScope          = "/subscriptions/dev1-subscription-guid"
            scopeParam         = @{ SubscriptionId = "dev1-subscription-guid" }
            assignmentSelector = "PAC-DEV-001"
            planFile           = "./Output/Plans/dev001.json" 
        }
    }

    # Put the hashtable into the pipeline
    $environemts
}