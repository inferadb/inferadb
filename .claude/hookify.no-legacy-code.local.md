---
name: no-legacy-code
enabled: true
event: file
pattern: (@deprecated|DEPRECATED|deprecated\s*\(|backwards?\s*[-_]?compat|legacy[-_]?support|for\s+backwards?\s+compat|maintain\s+backwards|backward\s+compat|legacy\s+code|legacy\s+support|// TODO:?\s*(fix|remove|refactor|clean|hack|workaround|temporary|temp\s|later)|# TODO:?\s*(fix|remove|refactor|clean|hack|workaround|temporary|temp\s|later)|FIXME|HACK|XXX|kludge|workaround|temporary\s+fix|quick\s+fix|band[-]?aid|stopgap|\bfeature[-_]?flag|\bfeature[-_]?toggle|isFeatureEnabled|getFeatureFlag|if\s*\(\s*feature|enableFeature|disableFeature|__deprecated__|DeprecationWarning|warn.*deprecat|deprecation[-_]?warning|will\s+be\s+removed|scheduled\s+for\s+removal|to\s+be\s+deprecated)
action: block
---

🚫 **Breaking Changes Preferred - Legacy/Tech Debt Pattern Detected**

This codebase embraces breaking changes and optimal implementations. The following patterns are blocked:

## What Was Detected

Code that appears to introduce:
- **Backwards compatibility shims** - We don't maintain legacy support
- **Tech debt markers** (TODO, FIXME, HACK, workaround) - Fix it now or don't add it
- **Feature flags/toggles** - Ship the optimal solution directly
- **Deprecation patterns** - Remove old code, don't deprecate it

## Philosophy

This is a **new product**. Every change should be:
- ✅ The optimal, efficient implementation
- ✅ Following current best practices and standards
- ✅ Clean and maintainable from day one

Breaking changes are **encouraged** if they put us on the optimal track.

## What To Do Instead

1. **Instead of backwards compat**: Just make the breaking change
2. **Instead of TODO/FIXME**: Implement it correctly now
3. **Instead of feature flags**: Ship the final implementation
4. **Instead of deprecation**: Remove the old code entirely

If you genuinely need to add one of these patterns, discuss with the team first.
