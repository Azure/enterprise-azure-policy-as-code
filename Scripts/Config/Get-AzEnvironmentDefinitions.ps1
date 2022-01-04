# conatins settings for testing different environments

function Get-AzEnvironmentDefinitions {
    $tenantId = "e898ff4a-4b69-45ee-a3ae-1cd6f239feb2"
    $environemts = @{
        prod = @{
            tenantId           = $tenantId
            rootScope          = "/providers/Microsoft.Management/managementGroups/e898ff4a-4b69-45ee-a3ae-1cd6f239feb2"
            scopeParam         = @{ ManagementGroupName = "e898ff4a-4b69-45ee-a3ae-1cd6f239feb2" }
            assignmentSelector = "PAC-PROD"
            planFile           = "./Output/Plans/prod.json" 
        }
        qa   = @{
            tenantId           = $tenantId
            rootScope          = "/subscriptions/63ef1972-b1be-4a4b-a846-17fdd7105daa"
            scopeParam         = @{ SubscriptionId = "63ef1972-b1be-4a4b-a846-17fdd7105daa" }
            assignmentSelector = "PAC-QA"
            planFile           = "./Output/Plans/qa.json" 
        } 
        dev2 = @{
            tenantId           = $tenantId
            rootScope          = "/subscriptions/c5215db3-a5b6-43e7-8ddb-02da410ec716"
            scopeParam         = @{ SubscriptionId = "c5215db3-a5b6-43e7-8ddb-02da410ec716" }
            assignmentSelector = "PAC-DEV-002"
            planFile           = "./Output/Plans/dev001.json" 
        } 
        dev1 = @{
            tenantId           = $tenantId
            rootScope          = "/subscriptions/450de7ac-f65b-4324-a96a-6e74b13b8d7d"
            scopeParam         = @{ SubscriptionId = "450de7ac-f65b-4324-a96a-6e74b13b8d7d" }
            assignmentSelector = "PAC-DEV-001"
            planFile           = "./Output/Plans/dev001.json" 
        }
    }

    # Put the hashtable into the pipeline
    $environemts
}