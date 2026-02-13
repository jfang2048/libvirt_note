#!/bin/sh

DEV_BRANCH="dev"
MAIN_BRANCH="main"
REMOTE="origin"

get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

handle_error() {
    printf "Error: %s\n" "$1" >&2
    exit 1
}

verify_git_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        handle_error "Not in a Git repository"
    fi
}

ensure_git_identity() {
    if [ -z "$(git config user.name)" ]; then
        printf "Git username not set, setting default...\n"
        git config user.name "jfang2048"
    fi
    if [ -z "$(git config user.email)" ]; then
        printf "Git email not set, setting default...\n"
        git config user.email "hhelibebcn9527@163.com"
    fi
}

ensure_dev_branch() {
    if ! git show-ref --quiet "refs/heads/${DEV_BRANCH}"; then
        printf "Creating new development branch '%s'...\n" "$DEV_BRANCH"
        git checkout -b "$DEV_BRANCH" || handle_error "Failed to create $DEV_BRANCH branch"
    elif [ "$(git symbolic-ref --short HEAD)" != "$DEV_BRANCH" ]; then
        printf "Switching to development branch '%s'...\n" "$DEV_BRANCH"
        git checkout "$DEV_BRANCH" || handle_error "Failed to switch to $DEV_BRANCH branch"
    else
        printf "Already on development branch '%s'\n" "$DEV_BRANCH"
    fi
}

commit_dev_changes() {
    timestamp=$(get_timestamp)
    printf "Staging all changes...\n"
    git add . || handle_error "Failed to stage changes"
    git status
    printf "Committing changes to '%s' branch...\n" "$DEV_BRANCH"
    git commit --no-verify -m "Update at $timestamp" || handle_error "Commit failed"
}

update_main_branch() {
    printf "Switching to main branch '%s'...\n" "$MAIN_BRANCH"
    git checkout "$MAIN_BRANCH" || handle_error "Failed to switch to $MAIN_BRANCH"
    printf "Pulling latest changes from remote '%s/%s'...\n" "$REMOTE" "$MAIN_BRANCH"
    git pull "$REMOTE" "$MAIN_BRANCH" || handle_error "Failed to pull updates"
}

merge_and_push() {
    timestamp=$(get_timestamp)
    printf "Merging changes from '%s' branch...\n" "$DEV_BRANCH"
    if git merge --no-ff --no-commit "$DEV_BRANCH" >/dev/null 2>&1; then
        git commit -m "Merge $DEV_BRANCH: $timestamp"
        printf "Pushing changes to remote '%s/%s'...\n" "$REMOTE" "$MAIN_BRANCH"
        git push "$REMOTE" "$MAIN_BRANCH" || handle_error "Push failed"
    else
        handle_merge_conflict
    fi
}

handle_merge_conflict() {
    printf "\nMERGE CONFLICT DETECTED! Please resolve manually:\n"
    printf "  1. Check conflict markers in files\n"
    printf "  2. Resolve conflicts and mark fixed files: git add <files>\n"
    printf "  3. Complete the merge: git commit\n"
    printf "  4. Push resolved changes: git push %s %s\n" "$REMOTE" "$MAIN_BRANCH"
    printf "  5. Return to dev branch: git checkout %s\n\n" "$DEV_BRANCH"
    exit 1
}

return_to_dev_branch() {
    printf "Switching back to development branch '%s'...\n" "$DEV_BRANCH"
    git checkout "$DEV_BRANCH" || printf "Warning: Failed to switch back to %s\n" "$DEV_BRANCH" >&2
}

main() {
    printf "\nStarting safe push workflow to %s/%s\n" "$REMOTE" "$MAIN_BRANCH"
   # verify_git_repo
   # ensure_git_identity
    ensure_dev_branch
    commit_dev_changes
    update_main_branch
    merge_and_push
    return_to_dev_branch
    printf "Operation completed successfully!\n"
}

main
