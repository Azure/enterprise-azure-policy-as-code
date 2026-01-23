function Get-HydrationEpacRepo {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $RepoRoot = "./"
    )
    if (Test-Path $RepoRoot) {
        $RepoRoot = Resolve-Path $RepoRoot
        $repoTempPath = Join-Path $RepoRoot "epacRepoTemp"
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
        try{
            Start-Process git -ArgumentList "clone $url $repoTempPath" -Wait -ErrorAction Stop
        }
        catch{
            Write-Message "Git does not appear to be installed or is not available in the system PATH. Checking to see if this is running from the root of the EPAC repo." -ForegroundColor Red
            if (Test-Path (Join-Path $RepoRoot "Scripts" "HydrationKit") -and Test-Path (Join-Path $RepoRoot "StarterKit" "Helpers") -and Test-Path $starterKitSourcePath) {
                Write-Host "EPAC repo appears to be present. Continuing without download, copying to temp folder to support code execution." -ForegroundColor Green
                $null = Copy-Item $RepoRoot $repoTempPath -Recurse -Force -Exclude "epacRepoTemp" -ErrorAction SilentlyContinue
                return
            }
            else {
                Write-Error "Git is not installed or not available in the system PATH, and the EPAC repo does not appear to be present at $RepoRoot. Manually download and extract the repo at https://github.com/Azure/enterprise-azure-policy-as-code. Cannot continue."
                return
            }
        }
        $null = Copy-Item $starterKitSourcePath $starterKitDestinationPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Error "Error: Download failed, destination path $RepoRoot does not exist."
        return
    }
}