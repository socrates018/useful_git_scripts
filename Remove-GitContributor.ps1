# Simple Remove-GitContributor.ps1
# Set your repository URL here
$RepoUrl = ""  # <-- EDIT THIS LINE

# Try to find git-filter-repo
$gitFilterRepo = Get-Command git-filter-repo -ErrorAction SilentlyContinue
if (-not $gitFilterRepo) {
    $userScripts = Join-Path $env:USERPROFILE 'AppData\Roaming\Python\Python311\Scripts'
    $exe = Join-Path $userScripts 'git-filter-repo.exe'
    if (Test-Path $exe) { $gitFilterRepo = $exe }
}
if (-not $gitFilterRepo) {
    Write-Host "git-filter-repo not found. Please install it with 'pip install git-filter-repo' and ensure it's in your PATH." -ForegroundColor Red
    Read-Host 'Press Enter to exit...'
    exit 1
}

# Clone repo to temp
$TempDir = Join-Path $env:TEMP ("repo-to-clean-" + [guid]::NewGuid().ToString())
Write-Host "Cloning repository to $TempDir ..."
git clone --mirror $RepoUrl $TempDir
Set-Location $TempDir

# List contributors
$contributors = git log --pretty="%an <%ae>" | Sort-Object -Unique
Write-Host "`nContributors found:"
for ($i = 0; $i -lt $contributors.Count; $i++) {
    Write-Host ("{0}: {1}" -f $i, $contributors[$i])
}
$inputIdx = Read-Host "`nEnter the number(s) of the contributor(s) to remove, separated by commas:"
$idxArr = $inputIdx -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
$toRemove = $idxArr | ForEach-Object { $contributors[$_] }
if (-not $toRemove -or $toRemove.Count -eq 0) {
    Write-Host "No contributors selected. Exiting."
    Read-Host 'Press Enter to exit...'
    exit
}

# Build author match string
$authorMatchList = @()
foreach ($item in $toRemove) {
    $name, $email = $item -replace '>$','' -split ' <'
    $authorMatchList += "(commit.author_name == b'${name}' and commit.author_email == b'${email}')"
}
$authorMatch = [string]::Join(' or ', $authorMatchList)
$pyCallback = "if " + $authorMatch + ": commit.skip()"

# Preview changes
Write-Host "`n==== PREVIEW CHANGES ====`n" -ForegroundColor Yellow
& $gitFilterRepo --dry-run --commit-callback "$pyCallback"
Write-Host "`nCommits to be removed:`n"
foreach ($item in $toRemove) {
    $name, $email = $item -replace '>$','' -split ' <'
    git log --pretty="%h %an <%ae> %s" | Select-String "$name" | ForEach-Object { Write-Host $_ }
    git log --pretty="%h %an <%ae> %s" | Select-String "$email" | ForEach-Object { Write-Host $_ }
}

$choice = Read-Host "`nContinue with rewrite? (y/n)"
if ($choice -ne 'y') { Write-Host 'Aborted.'; Read-Host 'Press Enter to exit...'; exit }

Write-Host "`n==== REWRITING HISTORY ====" -ForegroundColor Red
& $gitFilterRepo --force --commit-callback "$pyCallback"

# After rewriting history, clean up tags and refs, and run garbage collection
Write-Host "`nCleaning up tags and refs..."
# Delete all tags
$tags = git tag
foreach ($tag in $tags) {
    if ($tag) { git tag -d $tag }
}
# Delete all refs in refs/original (left by filter-repo)
$refs = git for-each-ref --format='%(refname)' refs/original/
foreach ($ref in $refs) {
    if ($ref) { git update-ref -d $ref }
}
# Run garbage collection
Write-Host "Running git gc..."
git gc --prune=now --aggressive

Write-Host "`n==== VERIFY CHANGES ====" -ForegroundColor Green
git log --oneline -n 10

$choice = Read-Host "`nPush changes to remote? (THIS CANNOT BE UNDONE) (y/n)"
if ($choice -eq 'y') {
    # Re-add origin remote if missing
    $remotes = git remote
    if ($remotes -notcontains 'origin') {
        git remote add origin $RepoUrl
        Write-Host "Re-added 'origin' remote: $RepoUrl"
    }
    git push origin --force --all
    git push origin --force --tags
    Write-Host "`nHistory rewritten. All collaborators must reclone." -ForegroundColor Cyan
} else {
    Write-Host "`nChanges NOT pushed. Run 'git push --force' manually when ready." -ForegroundColor Yellow
}

Write-Host "`nTemporary repo is at $TempDir. Remove manually if desired."
Read-Host 'Press Enter to close...'