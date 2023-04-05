function Confirm-PolicyDefinitionsMatch {
    [CmdletBinding()]
    param (
        $object1,
        $object2
    )

    if ($null -eq $object1) {
        # $object2 is not $null (always true); swap object 1 and object2, so that $object1 is always not $null
        $tempObject = $object2
        $object2 = $object1
        $object1 = $tempObject
    }
    $type1 = $object1.GetType()
    $typeName1 = $type1.Name
    $type2 = $null
    $typeName2 = "null"
    if ($null -ne $object2) {
        $type2 = $object2.GetType()
        $typeName2 = $type2.Name
    }
    if ($typeName1 -in @( "Object[]", "ArrayList") -or $typeName2 -in @( "Object[]", "ArrayList")) {
        if ($null -eq $object2) {
            return $object1.Count -eq 0
        }
        else {
            if ($typeName1 -notin @( "Object[]", "ArrayList")) {
                # convert single element $object1 into an array
                $object1 = @( $object1 )
            }
            if ($typeName2 -notin @( "Object[]", "ArrayList")) {
                # convert single element $object2 into an array
                $object2 = @( $object2 )
            }
            # both objects are now of type array or ArrayList
            if ($object1.Count -ne $object2.Count) {
                return $false
            }
            else {
                # iterate and recurse
                $object2List = [System.Collections.ArrayList]::new($object2)
                foreach ($item1 in $object1) {
                    $foundMatch = $false
                    for ($i = 0; $i -lt $object2List.Count; $i++) {
                        $item2 = $object2List[$i]
                        if ($item1 -eq $item2) {
                            $foundMatch = $true
                            $null = $object2List.RemoveAt($i)
                            break
                        }
                        else {
                            $policyDefinitionReferenceIdMatches = $item1.policyDefinitionReferenceId -eq $item2.policyDefinitionReferenceId
                            $policyDefinitionIdMatches = $item1.policyDefinitionId -eq $item2.policyDefinitionId
                            $parametersMatch = Confirm-ObjectValueEqualityDeep $item1.parameters $item2.parameters
                            $groupNamesMatch = Confirm-ObjectValueEqualityDeep $item1.groupNames $item2.groupNames
                            $foundMatch = $policyDefinitionReferenceIdMatches -and $policyDefinitionIdMatches -and $parametersMatch -and $groupNamesMatch
                            if ($foundMatch) {
                                $foundMatch = $true
                                $object2List.RemoveAt($i)
                                break
                            }
                        }
                        if (!$foundMatch) {
                            return $false
                        }
                    }
                }
                return $true
            }
        }
    }
}