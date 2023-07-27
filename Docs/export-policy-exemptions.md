# Exporting Policy Exemptions

The script `Get-AzExemptions.ps1` retrieves Policy Exemptions from an EPAC environment and saves them to files in JSON and CSV format. These files can be used as starting points for creating new exemptions.

<!-- insert paramters as a table -->
## Script Parameters

| Parameter | Description |
| --- | --- |
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'`. |
| `OutputFolder` | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'`. |
| `Interactive` | Set to false if used non-interactive |
| `FileExtension` | File extension type for the output files. Valid values are json and jsonc. Defaults to json. |

## Examples

```ps1
.\Get-AzExemptions.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -OutputFolder "C:\Src\Outputs" -Interactive $true -FileExtension "jsonc"
```

```ps1
.\Get-AzExemptions.ps1 -Interactive $true
```

```ps1
.\Get-AzExemptions.ps1 -Interactive $true -FileExtension "jsonc"
```

```ps1
.\Get-AzExemptions.ps1 -Interactive $true -FileExtension "json"
```

```ps1
.\Get-AzExemptions.ps1 -Interactive $true -FileExtension "csv"
```

```ps1
.\Get-AzExemptions.ps1 -Interactive $true -FileExtension "csv" -OutputFolder "C:\Src\Outputs"
```

## Links

- [Policy Exemptions](https://azure.github.io/enterprise-azure-policy-as-code/policy-exemptions/)

