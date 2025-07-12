function Get-HydrationEpacRepo {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $RepoRoot = "./"
    )
    if (Test-Path $RepoRoot) {
        $RepoRoot = Resolve-Path $RepoRoot
        $repoTempPath = Join-Path $RepoRoot "epacRepo"
        $starterKitSourcePath = Join-Path $repoTempPath "StarterKit"
        $starterKitDestinationPath = Join-Path $RepoRoot "StarterKit"
        Write-Host "Downloading HydrationKit from GitHub to $RepoRoot" -ForegroundColor Green
        $url = "https://github.com/Azure/enterprise-azure-policy-as-code.git"
        if (!(Test-Path $repoTempPath)) {
            $null = New-Item -ItemType Directory -Path $repoTempPath -ErrorAction SilentlyContinue
            
        }
        # $null = Remove-Item -Recurse -Force $repoTempPath -ErrorAction SilentlyContinue
        # git clone $url $repoTempPath
        Write-Host "This will create a popup terminal window"
        Start-Process git -ArgumentList "clone $url $repoTempPath" -Wait
        $null = Copy-Item $starterKitSourcePath $starterKitDestinationPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Error "Error: Download failed, destination path $RepoRoot does not exist."
        return
    }
}