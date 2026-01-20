---
description: Create, list, review, or suggest architecture decision records.
---

# Architecture Decision Records Management

Handle ADR operations based on the user's request.

## Actions

### Create new ADR
If the user wants to create a new ADR (e.g. `/adr new [title]`):
1. Run the `adr` command:
```bash
EDITOR=true adr new [title]
```
2. Read the created file path from the output.
3. Edit the ADR file to fill in proper content:
   - **Context**: Why this decision is needed, constraints, forces at play
   - **Decision**: The choice made and rationale
   - **Consequences**: Trade-offs, what becomes easier/harder
4. Stage and commit the new ADR:
```bash
git add doc/adr/*.md
git commit -m "docs(adr): add ADR for [title]"
```

### List existing ADRs
If the user wants to list ADRs (e.g. `/adr list`):
1. Run `adr list`:
// turbo
```bash
adr list
```
2. Display the results.

### Review ADR
If the user wants to review an ADR (e.g. `/adr review [number]`):
1. Find the ADR file containing the number.
2. Read the file content.
3. Check for:
   - Clear context explaining the problem
   - Explicit decision statement
   - Documented consequences (both positive and negative)
   - Proper status (Accepted/Proposed/Deprecated/Superseded)
   - Links to related ADRs if applicable
4. Suggest improvements if sections are incomplete.

### Suggest ADR topics
If the user wants suggestions for ADRs (e.g. `/adr suggest`):
1. Check existing ADRs with `adr list`.
2. Explore the codebase for significant patterns or choices (tech stack, infrastructure, auth, etc.) that are not documented.
   - Check `package.json`, `mix.exs`, `Cargo.toml`, `devenv.nix` etc.
3. Compare findings against existing ADRs.
4. Suggest missing ADRs with draft titles.
