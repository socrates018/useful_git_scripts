@echo off
REM Set your repository URL below (e.g., https://github.com/your-username/your-repo.git)
set "REPO_URL=ENTER_YOUR_REPO_URL_HERE"
REM Set your repository name below (e.g., your-repo)
set "REPO_NAME=ENTER_YOUR_REPO_NAME_HERE"
REM Set the path to your bfg.jar file below (e.g., C:\path\to\bfg.jar)
set "BFG_JAR=ENTER_PATH_TO_BFG_JAR_HERE"
REM Set the secret or sensitive string to remove (e.g., password123)
set "SECRET=ENTER_SECRET_TO_REMOVE_HERE"
set "TEMP_REPLACEMENT_FILE=_bfg_replacements.txt"

REM === Clone the repo as a mirror ===
echo Cloning %REPO_URL% as a mirror...
git clone --mirror %REPO_URL%
if errorlevel 1 (
    echo ERROR: Git clone failed.
    pause
    exit /b
)

cd "%REPO_NAME%.git" || (
    echo ERROR: Could not enter folder %REPO_NAME%.git
    pause
    exit /b
)

REM === Create temporary replacements file ===
echo Creating temporary replacements file...
(
    echo !SECRET!==^>***REMOVED***
) > "%TEMP_REPLACEMENT_FILE%"

REM === Run BFG to scrub the secret ===
echo Running BFG to remove secret: !SECRET!
java -jar "%BFG_JAR%" --replace-text "%TEMP_REPLACEMENT_FILE%"
if errorlevel 1 (
    echo ERROR: BFG failed.
    pause
    exit /b
)

REM === Clean up repo history ===
echo Cleaning up with git reflog and garbage collection...
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo Pushing cleaned history back to origin...
git push origin --force --all
git push origin --force --tags

del "%TEMP_REPLACEMENT_FILE%"

echo === DONE: Secret scrubbed from all history ===
pause

