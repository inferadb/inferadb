---
name: require-complete-implementation
enabled: true
event: stop
pattern: .*
action: block
---

🛑 **Implementation Quality Check Required**

Before stopping, verify this work is **complete and high-quality**:

## DRY (Don't Repeat Yourself)
- [ ] No duplicated code that should be extracted
- [ ] Shared logic is properly abstracted
- [ ] No copy-paste patterns that will diverge

## KISS (Keep It Simple, Stupid)
- [ ] Solution is as simple as possible, but no simpler
- [ ] No unnecessary abstractions or indirection
- [ ] Clear, readable code that's easy to follow

## Completeness Checklist
- [ ] All requested functionality is implemented
- [ ] Edge cases are handled
- [ ] Error handling is appropriate
- [ ] Code follows project conventions and best practices
- [ ] No placeholder code or "will fix later" sections

## The Standard

**Either implement something fully and correctly, or don't implement it at all.**

Half-measures create more work later. If something isn't ready to be done right, discuss scope with the user rather than shipping incomplete work.

---

If this implementation meets the above standards, you may proceed. If not, complete the work first.
