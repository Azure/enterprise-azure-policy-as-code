@{
	# Script module or binary module file associated with this manifest
	RootModule        = 'EnterprisePolicyAsCode.psm1'
	
	# Version number of this module.
	ModuleVersion     = ''
	
	# ID used to uniquely identify this module
	GUID              = '197a34e5-115d-4c15-a593-b004228be78b'
	
	# Author of this module
	Author            = 'Microsoft Corporation'
	
	# Company or vendor of this module
	CompanyName       = 'Microsoft'
	
	# Copyright statement for this module
	Copyright         = 'Copyright (c) 2022,2023,2024 Microsoft Corporation'
	
	# Description of the functionality provided by this module
	Description       = 'Enterprise Policy as Code PowerShell Module'
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '7.0'
	
	# Functions to export from this module
	FunctionsToExport = ''
	
	# Cmdlets to export from this module
	CmdletsToExport   = ''
	
	# Variables to export from this module
	VariablesToExport = ''
	
	# Aliases to export from this module
	AliasesToExport   = ''
	
	# List of all files packaged with this module
	FileList          = @()
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData       = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			# Tags = @()

			# Prerelease tag to append
			Prerelease     = ''
			
			# A URL to the license for this module.
			LicenseUri   = 'https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/LICENSE'
			
			# A URL to the main website for this project.
			ProjectUri   = 'https://github.com/Azure/enterprise-azure-policy-as-code'
			
			# A URL to an icon representing this module.
			IconUri      = 'https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/refs/heads/main/Docs/Images/10316-icon-service-Policy.svg'
			
			# ReleaseNotes of this module
			ReleaseNotes = 'https://github.com/Azure/enterprise-azure-policy-as-code/releases'
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}
