---
name: writing-style
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.(md|markdown)$
  - field: new_text
    operator: regex_match
    pattern: \b(due to the fact that|in order to|at this point in time|at the present time|for the purpose of|in the event that|by virtue of|by means of|with respect to|in regard to|in terms of|as a matter of fact|for all intents and purposes|each and every|first and foremost|in the near future|prior to|subsequent to|in lieu of|with the exception of|has the ability to|is able to|make reference to|give consideration to|take into consideration|have a tendency to|past history|future plans|basic fundamentals|end result|close proximity|final outcome|general consensus|join together|new innovation|revert back|advance warning|brief summary|exact same|repeat again|return back|whether or not|reason why|collaborate together|very amazing|really important|extremely powerful|quite significant|pretty good|very unique|really great|extremely obvious|basically works|actually correct|final and last|true fact|added bonus|completely eliminate|currently now|each individual|initial beginning|overexaggerate|personal opinion|totally unique|unexpected surprise|honest truth|necessary requirement|absolutely essential|actual fact|entirely eliminate|final conclusion|ultimate goal|still remains|continue on|plan ahead|refer back|rise up|write down)\b
---

**Writing Style Issue Detected**

Your documentation may contain wordy, redundant, or imprecise language. Please review and revise.

---

## Writing Principles

### 1. Conciseness

Eliminate unnecessary words:

| Avoid                 | Prefer           |
| --------------------- | ---------------- |
| due to the fact that  | because          |
| in order to           | to               |
| at this point in time | now              |
| for the purpose of    | to, for          |
| in the event that     | if               |
| with respect to       | about, regarding |
| in terms of           | in, for          |

### 2. Avoiding Redundancy

Remove repetitive words:

| Avoid              | Prefer       |
| ------------------ | ------------ |
| past history       | history      |
| future plans       | plans        |
| basic fundamentals | fundamentals |
| end result         | result       |
| final outcome      | outcome      |
| new innovation     | innovation   |
| revert back        | revert       |
| repeat again       | repeat       |
| return back        | return       |
| whether or not     | whether      |
| join together      | join         |
| final and last     | final        |
| true fact          | fact         |

### 3. Active Voice

Prefer active over passive voice when appropriate:

| Passive (Avoid)                 | Active (Prefer)           |
| ------------------------------- | ------------------------- |
| The report was written by Jane  | Jane wrote the report     |
| Data is processed by the server | The server processes data |

### 4. Eliminating Filler

Cut unnecessary phrases:

| Avoid                 | Prefer   |
| --------------------- | -------- |
| has the ability to    | can      |
| is able to            | can      |
| make reference to     | refer to |
| give consideration to | consider |
| have a tendency to    | tend to  |

### 5. Precision and Clarity

Avoid vague intensifiers:

| Avoid              | Prefer                               |
| ------------------ | ------------------------------------ |
| very amazing       | amazing                              |
| really important   | important (or: critical)             |
| extremely powerful | powerful (or: describe capabilities) |
| quite significant  | significant                          |
| pretty good        | good                                 |

### 6. Avoiding Wordiness

Express ideas directly:

| Avoid               | Prefer     |
| ------------------- | ---------- |
| at the present time | now        |
| in the near future  | soon       |
| prior to            | before     |
| subsequent to       | after      |
| in lieu of          | instead of |

### 7. Definite, Specific Language

Replace vague terms with concrete ones:

| Vague                    | Specific                    |
| ------------------------ | --------------------------- |
| She did something nice   | She bought lunch            |
| The performance was fast | The query completes in 10ms |

### 8. Avoiding Weak Modifiers

Remove intensifiers that add no meaning:

- "very", "really", "quite", "extremely", "basically", "actually"
- If the base word is strong enough, the modifier weakens it
- "very unique" → "unique" (unique is already absolute)

### 9. Clarity and Brevity

Combine all principles for clear, concise writing.

---

## InferaDB Style Guide Requirements

Per `docs/templates/style-guide.md`:

**Headers:** Use plain text Title Case

```markdown
## Getting Started ✓ Correct

## **Getting Started** ✗ No bold in headers

## 1. Getting Started ✗ No numbering in headers
```

**Code blocks:** Always specify language

````markdown
```rust
fn main() { }             ✓ Correct
```
````

**Diagrams:** Use Mermaid, not ASCII art

````markdown
```mermaid
flowchart TD
    A[Start] --> B[End]   ✓ Correct
```
````

**File naming:** Use kebab-case (`getting-started.md`)

---

**Action:** Revise your text to follow these writing principles and style guidelines.
