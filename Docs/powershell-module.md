# PowerShell Module

Enterprise Policy as Code is now available as a PowerShell module. To install follow the instructions below.

```ps1
Install-Module EnterprisePolicyAsCode
Import-Module EnterprisePolicyAsCode
```

## Known Issues

Many scripts use parameters for input and output folders. They default to the current directory. We recommend that you do one of the following approaches instead of accepting the default to prevent your files being created in the wrong location:

- Set the environment variables `PAC_DEFINITIONS_FOLDER`, `PAC_OUTPUT_FOLDER`, and `PAC_INPUT_FOLDER`.
- Use the script parameters `-definitionsRootFolder`, `-outputFolder`, and `-inputFolder`.
