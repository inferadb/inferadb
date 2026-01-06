# Efficiency Guidelines

## File Operations

### Moving/Copying Files
For simple file moves or copies, **do not read file contents into context**. Instead:
- Provide the user with the shell command to run (if git operations are blocked)
- Or use direct shell commands like `mv`, `cp` if allowed

**Bad pattern (slow, wasteful):**
1. Read source file contents
2. Write contents to destination
3. Delete source

**Good pattern (fast):**
```bash
mv source destination
# or
cp source destination
```

### When to Read Files
Only read file contents when you need to:
- Understand the code/content for analysis
- Make modifications to specific parts
- Answer questions about what's inside

Don't read files just to move them somewhere else.
