---
description: Create, list, review, or suggest architecture decision records. Use when user asks to "create ADR", "document decision", "list decisions", "review architecture", or "suggest ADR topics".
argument-hint: [new|list|review|suggest] [title-or-number]
allowed-tools: Bash(adr:*), Bash(cat:*), Bash(ls:*), Bash(git:*)
---

# Architecture Decision Records Management

Handle ADR operations based on the first argument ($1):

## Actions

### `new [title]` - Create new ADR
1. Run `EDITOR=true adr new $2 $3 $4 $5 $6 $7 $8 $9` to create the ADR file
2. Read the created file path from output
3. Edit the ADR to fill in proper content:
   - **Context**: Why this decision is needed, constraints, forces at play
   - **Decision**: The choice made and rationale
   - **Consequences**: Trade-offs, what becomes easier/harder
4. Auto-commit: `git add doc/adr/*.md && git commit -m "docs(adr): add ADR for [title]"`

### `list` - List existing ADRs
Run `adr list` and display results formatted.

### `review [number]` - Review ADR for completeness
1. Find ADR file: `adr list | grep "^doc/adr/000$2"` or search by partial name
2. Read the file content
3. Check for:
   - Clear context explaining the problem
   - Explicit decision statement
   - Documented consequences (both positive and negative)
   - Proper status (Accepted/Proposed/Deprecated/Superseded)
   - Links to related ADRs if applicable
4. Suggest improvements if sections are incomplete

### `suggest` - Suggest ADR topics for codebase
Analyze entire codebase to identify undocumented architectural decisions:

1. Check existing ADRs: `adr list`
2. Explore codebase for patterns indicating decisions:
   - Package.json/Cargo.toml/go.mod for tech stack choices
   - Docker/K8s files for infrastructure decisions
   - CI/CD configs for deployment strategy
   - Auth code for security decisions
   - API routes for API design patterns
   - Test files for testing strategy
3. Compare findings against existing ADRs
4. Suggest missing ADRs with draft titles

## ADR Template Structure

```markdown
# N. Title

Date: YYYY-MM-DD

## Status

Accepted | Proposed | Deprecated | Superseded by [N](link)

## Context

[Problem/situation requiring a decision. Include constraints, forces, requirements.]

## Decision

[The choice made. Be explicit about what was decided and why.]

## Consequences

[Results of the decision. Include:]
- What becomes easier
- What becomes harder
- Risks to mitigate
- Follow-up actions needed
```

## Linking ADRs

For decisions that supersede or relate to others:
- Supersede: `adr new -s 3 New approach to authentication`
- Link: `adr link 5 "Implements" 3 "Implemented by"`

## Common ADR Topics

Technology: language, framework, database, ORM
Architecture: monolith/microservices, API style, messaging
Infrastructure: cloud provider, CI/CD, IaC, containers
Code: monorepo/multirepo, branching, conventions
Security: auth mechanism, secrets management, encryption
Testing: test strategy, coverage, E2E approach
DevOps: deployment strategy, monitoring, logging
