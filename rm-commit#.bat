@echo off
setlocal enabledelayedexpansion

:: === CONFIGURATION ===
REM Set your repository URL below (e.g., https://github.com/your-username/your-repo.git)
set "REPO_URL=ENTER_YOUR_REPO_URL_HERE"
REM Set the commit hash to remove (e.g., abcdef1234567890)
set COMMIT_HASH=ENTER_COMMIT_HASH_TO_REMOVE
REM Set the git filter-repo command (leave as is unless you use a custom path)
set GIT_FILTER_REPO=git filter-repo

:: === Check Git installed ===
where git >nul 2>&1 || (
    echo ERROR: Git is not installed or not in PATH.
    pause
    exit /b
)

:: === Clone the repo as a mirror ===
echo Cloning %REPO_URL% as a mirror...
git clone --mirror %REPO_URL%
if errorlevel 1 (
    echo ERROR: Failed to clone the repo.
    pause
    exit /b
)

:: Extract repo name from URL (remove .git if present)
for %%a in ("%REPO_URL%") do (
    set "REPO_NAME=%%~na"
)
set "REPO_NAME=!REPO_NAME:.git=!"

cd "!REPO_NAME!.git" || (
    echo ERROR: Could not find !REPO_NAME!.git
    pause
    exit /b
)

:: === Remove the specified commit ===
echo Running git filter-repo to remove commit %COMMIT_HASH%...
%GIT_FILTER_REPO% --commit-callback "if commit.original_id == b\"%COMMIT_HASH%\": commit.skip()"
if errorlevel 1 (
    echo ERROR: git-filter-repo failed.
    pause
    exit /b
)

git remote remove origin >nul 2>&1
git remote add origin %REPO_URL%


:: === Force push cleaned repo ===
echo Force pushing cleaned history to origin...
git push --force --all
git push --force --tags

echo === DONE: Commit %COMMIT_HASH% removed ===
pause
