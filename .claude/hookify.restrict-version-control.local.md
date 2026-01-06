---
name: restrict-version-control
enabled: true
event: bash
pattern: \bgit\s+(add|commit|push|pull|fetch|merge|rebase|reset|checkout|switch|branch\s+(-d|-D|-m|-M|--delete|--move)|stash|cherry-pick|revert|tag|am|apply|bisect|clean|clone|init|mv|rm|restore|submodule\s+(add|update|init|deinit|sync))\b|\bhg\s+(commit|push|pull|update|merge|revert|backout|strip|graft|histedit|shelve|unshelve)\b|\bsvn\s+(commit|ci|add|delete|del|remove|rm|copy|cp|move|mv|mkdir|import|checkout|co|switch|sw|merge|revert|resolve|lock|unlock|update)\b|\bbzr\s+(commit|push|pull|merge|revert|uncommit|shelve|unshelve)\b|\bfossil\s+(commit|ci|push|pull|merge|update|revert|undo|stash)\b|\bgh\s+(pr\s+(create|merge|close|reopen|edit|review|comment|ready)|issue\s+(create|close|reopen|edit|delete|comment|transfer|pin|unpin)|repo\s+(create|delete|fork|rename|edit|archive|unarchive|sync)|release\s+(create|delete|edit|upload)|gist\s+(create|delete|edit)|label\s+(create|delete|edit|clone)|secret\s+(set|delete|remove)|variable\s+(set|delete)|workflow\s+(run|enable|disable)|run\s+(cancel|delete|rerun|watch)|cache\s+delete|codespace\s+(create|delete|stop|rebuild|edit)|project\s+(create|delete|edit|close|copy|field-create|field-delete|item-add|item-delete|item-edit)|auth\s+(login|logout|refresh))
action: block
---

**Version Control Write Operation Blocked**

You attempted to use a version control command that **modifies the repository**, which is forbidden in this project.

**Blocked write operations include:**
- `git add`, `commit`, `push`, `pull`, `fetch`, `merge`, `rebase`, `reset`, `checkout`, `switch`, `stash`, `cherry-pick`, `revert`, `tag`, `clean`, `clone`, `init`, `mv`, `rm`, `restore`, destructive `branch` operations, `submodule` modifications
- `gh pr create/merge/close/edit/review/comment`, `gh issue create/close/edit/delete/comment`, `gh repo create/delete/fork/edit`, `gh release create/delete/edit`, `gh gist create/delete/edit`, `gh secret set/delete`, `gh variable set/delete`, `gh workflow run/enable/disable`, `gh auth login/logout`
- `hg` (Mercurial) write commands
- `svn` (Subversion) write commands
- `bzr` (Bazaar) write commands
- `fossil` write commands

**Allowed read-only operations:**
- `git status`, `git log`, `git diff`, `git show`, `git branch` (listing only), `git remote -v`, `git config --list`, `git ls-files`, `git blame`, `git shortlog`
- `gh pr list/view/status/diff/checks`, `gh issue list/view/status`, `gh repo list/view`, `gh release list/view`, `gh gist list/view`, `gh api` (GET requests), `gh auth status`, `gh secret list`, `gh variable list`

**This rule exists because:** The user wants to preserve full read access to the repository while preventing any modifications.

If you need to perform write operations, please ask the user to do so manually.
