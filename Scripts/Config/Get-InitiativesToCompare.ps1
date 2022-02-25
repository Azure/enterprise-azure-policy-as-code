$initiativeSetsToCompare = @{
    NIST = @(
        "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8", # Azure Security Benchmark
        "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f", # NIST SP 800-53 Rev. 5
        "/providers/Microsoft.Authorization/policySetDefinitions/03055927-78bd-4236-86c0-f36125a10dc9"  # NIST SP 800-171 Rev. 2
    )
    ASB     = @(
        "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"  # Azure Security Benchmark v3
    )
}
return $initiativeSetsToCompare