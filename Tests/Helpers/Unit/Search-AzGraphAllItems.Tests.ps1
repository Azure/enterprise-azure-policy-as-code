BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Search-AzGraphAllItems.ps1')

    function Write-ModernStatus { param($Message, $Status, $Indent) }
}

Describe 'Search-AzGraphAllItems retries' {
    BeforeEach {
        $script:requestCount = 0
        Mock Write-ModernStatus
    }

    It 'stops after five HTTP errors without error details' {
        Mock Invoke-AzRestMethod {
            $script:requestCount++
            [pscustomobject]@{
                StatusCode = 403
                Content    = '{"error":{"code":"Forbidden","message":"Test error without details"}}'
            }
        }

        $errorRecord = $null
        try {
            Search-AzGraphAllItems -Query 'resources' -ProgressItemName 'test items'
        }
        catch {
            $errorRecord = $_
        }

        $script:requestCount | Should -Be 5
        $errorRecord.Exception.Message | Should -Match 'Forbidden'
    }

    It 'does not increment the retry counter twice when the response cannot be parsed' {
        Mock Invoke-AzRestMethod {
            $script:requestCount++
            [pscustomobject]@{
                StatusCode = 403
                Content    = 'not JSON'
            }
        }

        { Search-AzGraphAllItems -Query 'resources' -ProgressItemName 'test items' } |
            Should -Throw '*Search-AzGraph REST error*'

        $script:requestCount | Should -Be 5
    }
}
