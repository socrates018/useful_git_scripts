
# Set your repository URL here
$RepoUrl = ""  # <-- EDIT THIS LINE

# Check for git-filter-repo and install if missing
$filterRepoInstalled = $false
try {
    git filter-repo --help > $null 2>&1
    $filterRepoInstalled = $true
} catch {}
if (-not $filterRepoInstalled) {
    Write-Host "git-filter-repo not found. Attempting to install via pip..."
    try {
        pip install git-filter-repo
        Write-Host "git-filter-repo installed."
    } catch {
        Write-Host "Failed to install git-filter-repo. Please install it manually using 'pip install git-filter-repo' and ensure it is in your PATH."
        exit 1
    }
}

# Helper: Find git-filter-repo in common locations if not in PATH
function Get-GitFilterRepoPath {
    $possibleNames = @('git-filter-repo', 'git-filter-repo.exe')
    $paths = $env:PATH -split ';'
    $userScripts = Join-Path $env:USERPROFILE 'AppData\Roaming\Python\Python311\Scripts'
    $paths += $userScripts
    foreach ($dir in $paths | Where-Object { $_ -and (Test-Path $_) }) {
        foreach ($name in $possibleNames) {
            $full = Join-Path $dir $name
            if (Test-Path $full) { return $full }
        }
    }
    return $null
}

$gitFilterRepo = Get-GitFilterRepoPath
if (-not $gitFilterRepo) {
    Write-Host "git-filter-repo not found in PATH or common locations. Please ensure it is installed and in your PATH."
    exit 1
}

# Generate a temp directory for the repo clone
$TempDir = Join-Path $env:TEMP ("repo-to-clean-" + [guid]::NewGuid().ToString())
Write-Host "Cloning repository to $TempDir ..."
git clone --mirror $RepoUrl $TempDir

# Navigate to repo
Set-Location $TempDir

# Find all unique contributors
$contributors = git log --pretty="%an <%ae>" | Sort-Object -Unique
Write-Host "`nContributors found:"
$contributors | ForEach-Object { Write-Host $_ }

# Ask user which contributor(s) to remove
Write-Host "`nEnter the number(s) of the contributor(s) to remove, separated by commas:"
for ($i = 0; $i -lt $contributors.Count; $i++) {
    Write-Host ("{0}: {1}" -f $i, $contributors[$i])
}
$inputIdx = Read-Host "Selection"
$idxArr = $inputIdx -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
$toRemove = $idxArr | ForEach-Object { $contributors[$_] }

if (-not $toRemove -or $toRemove.Count -eq 0) {
    Write-Host "No contributors selected. Exiting."
    exit
}

Write-Host "`nYou selected to remove:"
$toRemove | ForEach-Object { Write-Host $_ }

# Backup the repo (critical!)
$BACKUP_DIR = "$TempDir-BACKUP-$(Get-Date -Format 'yyyyMMdd')"
if (-not (Test-Path $BACKUP_DIR)) {
    Write-Host "Creating backup at $BACKUP_DIR..."
    git clone --mirror $TempDir $BACKUP_DIR
}

# Build filter-repo author matchers (Python code as a single line)
$authorMatchList = @()
foreach ($item in $toRemove) {
    $name, $email = $item -replace '>$','' -split ' <'
    $authorMatchList += "(commit.author_name == b'${name}' and commit.author_email == b'${email}')"
}
$authorMatch = [string]::Join(' or ', $authorMatchList)

if (-not $authorMatch) {
    Write-Host "No valid author matchers. Exiting."
    exit
}

# Prepare Python callback as a single line for compatibility
$pyCallback = "if " + $authorMatch + ": commit.skip()"

# Preview changes (dry run)
Write-Host "`n==== PREVIEW CHANGES ====`n" -ForegroundColor Yellow
& $gitFilterRepo --dry-run --commit-callback "$pyCallback"

# Show a brief summary of what would change
Write-Host "`nShowing a brief summary of changes (commits to be removed):`n"
foreach ($item in $toRemove) {
    $name, $email = $item -replace '>$','' -split ' <'
    git log --pretty="%h %an <%ae> %s" | Select-String "$name" | ForEach-Object { Write-Host $_ }
    git log --pretty="%h %an <%ae> %s" | Select-String "$email" | ForEach-Object { Write-Host $_ }
}

# Ask for confirmation
$choice = Read-Host "`nContinue with rewrite? (y/n)"
if ($choice -ne 'y') { exit }

# Apply changes
Write-Host "`n==== REWRITING HISTORY ====" -ForegroundColor Red
& $gitFilterRepo --force --commit-callback "$pyCallback"

# Verify
Write-Host "`n==== VERIFY CHANGES ====" -ForegroundColor Green
git log --oneline -n 10

# Push changes (if confirmed)
$choice = Read-Host "`nPush changes to remote? (THIS CANNOT BE UNDONE) (y/n)"
if ($choice -eq 'y') {
    git push origin --force --all
    git push origin --force --tags
    Write-Host "`nHistory rewritten. All collaborators must reclone." -ForegroundColor Cyan
} else {
    Write-Host "`nChanges NOT pushed. Run 'git push --force' manually when ready." -ForegroundColor Yellow
}

# Cleanup
Set-Location $PSScriptRoot
Write-Host "Temporary repo is at $TempDir. Remove manually if desired."