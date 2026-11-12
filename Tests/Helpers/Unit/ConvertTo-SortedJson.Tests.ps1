BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/ConvertTo-SortedJson.ps1')
}

Describe 'ConvertTo-SortedJson' {
    It 'sorts keys at every level' {
        $value = [ordered]@{
            z = [ordered]@{ max = -1; min = 1 }
            a = @([ordered]@{ y = 2; b = 1 })
        }

        ConvertTo-SortedJson $value | Should -Be '{"a":[{"b":1,"y":2}],"z":{"max":-1,"min":1}}'
    }

    It 'keeps the order of array items and keeps arrays of one or no items' {
        ConvertTo-SortedJson @('b', 'a') | Should -Be '["b","a"]'
        ConvertTo-SortedJson @{ list = @('only') } | Should -Be '{"list":["only"]}'
        ConvertTo-SortedJson @{ list = @() } | Should -Be '{"list":[]}'
    }

    It 'writes scalars like ConvertTo-Json' {
        ConvertTo-SortedJson 'text' | Should -Be '"text"'
        ConvertTo-SortedJson 42 | Should -Be '42'
        ConvertTo-SortedJson $true | Should -Be 'true'
    }
}
