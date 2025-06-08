# Useful Git Scripts

A collection of Windows batch scripts for advanced Git repository management.

## Scripts

- **clean_repo.bat**: Remove sensitive data (like secrets or passwords) from a Git repository's entire history using BFG Repo-Cleaner. Prompts for repo URL, repo name, BFG path, and the secret to scrub.
- **git-clone-and-mirror.bat**: Clone a Git repository both normally and as a mirror, with options for naming and cleanup.
- **rm-commit#.bat**: Remove a specific commit from a repository's history using `git filter-repo`. Prompts for repo URL, repo name, and commit hash.
