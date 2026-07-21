---
name: worktree
description: Creates, inspects, synchronizes, reviews, finishes, and safely removes Git worktrees stored outside repositories under $MANIN_WORKTREE_ROOT or $HOME/.manin-wt, with optional Herdr integration. Use whenever a task involves Git worktrees, isolated branches, parallel implementation directories, worktree cleanup, or opening worktree tasks in Herdr.
compatibility: Requires Git and a POSIX shell. Uses shasum or sha256sum only for local repositories without an origin remote.
---

# Worktree

Manage Git worktrees in one external hierarchy rather than inside the repository.

## Layout

Use:

```text
${MANIN_WORKTREE_ROOT:-$HOME/.manin-wt}/<repository-id>/<worktree-name>
```

Derive `<repository-id>` from `remote.origin.url` as a readable, filesystem-safe `host-owner-repository` value. Remove a trailing `.git`. Examples:

- `git@github.com:acme/api.git` → `github.com-acme-api`
- `https://github.com/acme/api.git` → `github.com-acme-api`

For a repository without an origin, use `<repo-basename>-<8-char-sha256-of-absolute-primary-repo-path>`.

Do not create or modify a `.worktrees` directory in the repository.

## Resolve Repository Context

Commands may start in either a primary checkout or a linked worktree.

1. Require `git rev-parse --is-inside-work-tree` to return `true`.
2. Resolve the absolute common Git directory with `git rev-parse --path-format=absolute --git-common-dir`.
3. The primary repository is the parent directory when the common directory is named `.git`.
4. Refuse bare repositories or unusual layouts unless the user supplies the primary repository explicitly.
5. Run worktree-management commands with `git -C <primary-repository>`.

Always quote paths.

## Optional Herdr Integration

Herdr integration is available only when both checks succeed:

```bash
test "${HERDR_ENV:-}" = 1
command -v herdr >/dev/null 2>&1
```

Availability alone is not permission to control Herdr. Use Herdr only when the user explicitly mentions Herdr or asks to open, create, run, inspect, or remove the worktree through Herdr. Otherwise manage the worktree with Git and report its path normally.

When Herdr is requested:

1. Load and follow the `herdr` skill as well as this skill.
2. Treat the installed CLI as authoritative. Run `herdr --help` and then `herdr worktree` to discover the current worktree syntax; do not guess subcommands or flags.
3. Stay inside the configured `${MANIN_WORKTREE_ROOT:-$HOME/.manin-wt}` hierarchy. If a Herdr create command cannot accept the required destination, create the worktree safely with Git first and ask Herdr to open the existing path instead.
4. Never create the same worktree once with Git and again with Herdr. After any Herdr worktree mutation, refresh `git worktree list --porcelain` and use returned Herdr IDs rather than predicting them.
5. Default an explicitly requested interactive worktree context to a sibling pane in the current tab, with its cwd set to the worktree path. Preserve focus unless the user asks to switch. Create a new tab or workspace only when explicitly requested.
6. Give new panes a useful label based on the worktree name. When starting an agent, launch its normal interactive executable, wait for `idle`, and then submit the task atomically.
7. Treat Herdr removal as destructive: apply this skill's clean, merged, and confirmation checks before invoking it. Do not assume Herdr removal also deletes the branch.

If `HERDR_ENV` is not `1`, explain that the current agent is not inside a Herdr-managed pane and continue with ordinary Git worktree operations unless the user required Herdr specifically.

## Naming

- A worktree name is one safe path component matching `[A-Za-z0-9][A-Za-z0-9._-]*`.
- Reject `.`, `..`, slashes, backslashes, control characters, and names beginning with `-`.
- The branch defaults to the worktree name. A branch may be supplied separately when it contains `/` or follows another naming convention.
- Never infer a path directly from an unsanitized branch name.

## Create

Usage intent:

```text
create <worktree-name> [base-ref] [branch]
```

Before creating:

1. Resolve the primary repository, repository ID, destination, and branch.
2. Prefer an explicitly supplied base ref. Otherwise use `origin/HEAD`, then `main`, then `master`, then the current branch. State the selected base.
3. Fetch only when the selected base is remote-backed and network access is appropriate.
4. Check `git worktree list --porcelain` for the destination and branch.
5. Check whether the destination already exists.
6. Create parent directories with `mkdir -p`; do not pre-create the destination itself.

For a new branch:

```bash
git -C "$primary" worktree add -b "$branch" "$destination" "$base"
```

For an existing branch that is not checked out elsewhere:

```bash
git -C "$primary" worktree add "$destination" "$branch"
```

Never reset, overwrite, or reuse an existing path or branch implicitly. Report the final path, branch, and base.

## List and Status

For `list`, run:

```bash
git -C "$primary" worktree list --porcelain
```

Present each worktree with path, branch or detached state, HEAD abbreviation, and whether it is prunable or locked. Clearly identify worktrees under the configured root.

For `status`, run `git -C <worktree-path> status --short --branch` for the requested worktree. If checking several worktrees, summarize rather than dumping repetitive output.

## Sync

Usage intent:

```text
sync <worktree-name> [base-ref]
```

1. Refuse to proceed if the worktree has tracked or untracked changes unless the user explicitly chooses how to preserve them.
2. Fetch the relevant remote when appropriate.
3. Show commits unique to both sides before changing history.
4. Ask before rebasing or merging unless the user already specified the strategy.
5. Never force-push as part of sync.

Prefer rebase for an unpublished task branch and merge for a shared branch, but confirm when publication status is unknown.

## Review

Determine the merge base against the explicit or detected base, then inspect:

```bash
git -C "$worktree" status --short --branch
git -C "$worktree" log --oneline --decorate "$base"..HEAD
git -C "$worktree" diff --stat "$base"...HEAD
git -C "$worktree" diff --check "$base"...HEAD
```

Review the actual diff and run project-appropriate checks when requested. Report uncommitted changes separately because `<base>...HEAD` excludes them.

## Finish

Usage intent:

```text
finish <worktree-name> [base-branch]
```

Treat finishing as a guarded workflow, not an unconditional merge:

1. Require a clean worktree.
2. Confirm the task branch and base branch.
3. Review ahead/behind state and run requested verification.
4. Ensure the base checkout is clean before changing it.
5. Show the proposed merge command and obtain confirmation unless the user explicitly requested that merge strategy.
6. Prefer `--ff-only` after a successful rebase. Do not silently fall back to a merge commit.
7. Remove the worktree only after a successful merge or explicit user instruction.
8. Delete the branch only after proving it is merged, and only with confirmation or explicit prior instruction.

Do not push unless explicitly requested.

## Remove

Usage intent:

```text
remove <worktree-name>
```

- Resolve the target from Git metadata, not only from the expected directory.
- Show `status --short --branch` first.
- Use `git worktree remove <path>` without `--force` by default.
- Never use `rm -rf` as a substitute for `git worktree remove`.
- If removal is blocked by changes, explain them and ask what to do.
- Branch deletion is a separate, explicit operation.
- Run `git worktree prune` only after successful removal.

## Cleanup

Cleanup is preview-first:

1. Run `git worktree list --porcelain` and `git worktree prune --dry-run --verbose`.
2. Inspect directories only within the resolved repository directory under the configured root.
3. Classify registered, stale, locked, dirty, unmerged, and unregistered paths.
4. Present candidates and reasons before deleting anything.
5. Use Git removal/pruning commands for registered metadata.
6. Never recursively delete an unregistered directory without explicit confirmation after showing its path and contents summary.

## Safety Rules

- Do not use `--force`, `git reset --hard`, branch `-D`, or `rm -rf` unless the user explicitly authorizes the exact destructive action after seeing the risk.
- Do not remove worktrees with uncommitted or untracked files by default.
- Do not delete branches with unpushed or unmerged commits by default.
- Do not assume the current checkout is the primary repository.
- Do not modify `.gitignore`; external worktrees require no repository ignore rule.
- Expand `$HOME` and environment variables through the shell; never store a literal `~` in Git worktree metadata.
