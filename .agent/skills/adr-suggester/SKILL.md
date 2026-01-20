---
name: adr-suggester
description: Automatically suggests creating ADRs after implementing significant code changes.
---

# ADR Suggester

You've just completed significant code changes. Analyze them and suggest relevant Architecture Decision Records.

## Trigger Patterns

Create ADR when changes involve:
- **Dependencies**: New library, framework, package added
- **Data Storage**: Database choice, schema changes, caching layer
- **API Design**: New endpoints, contract changes, versioning
- **Authentication**: Auth mechanism, session handling, token strategy
- **Infrastructure**: Cloud services, deployment config, CI/CD changes
- **Architecture**: New patterns, service boundaries, communication style
- **Build System**: Tooling changes, compilation flags, bundler config
- **Third-party**: External service integrations, payment providers, analytics

## Analysis Steps

1. **Check recent changes**
   ```bash
   git diff HEAD~1 --name-only
   git log -1 --pretty=format:"%s"
   ```

2. **Identify ADR-worthy decisions**
   Look for:
   - New files in `package.json`, `mix.exs`, `Cargo.toml`, `devenv.nix` etc.
   - Schema files (`.sql`, migrations)
   - Config files (`.env.example`, `docker-compose.yml`, CI configs)
   - New service integrations

3. **Suggest specific ADR titles**
   Format: `Use [technology/pattern] for [purpose]`

   Examples:
   - "Use Redis for session caching"
   - "Use JWT tokens for API authentication"
   - "Use GitHub Actions for CI/CD"
   - "Use event-driven architecture for order processing"

## Output Format

```markdown
## Suggested ADRs

Based on your changes, consider creating:

1. **[Title]**
   - Context: [why this decision was needed]
   - Key trade-offs: [what was considered]

To create: `/adr new [Title]`
```

## Skip Conditions

Do NOT suggest ADR if:
- Changes are bug fixes without architectural impact
- Updates are version bumps only
- Changes are documentation/comments only
- Tests added without new patterns

## Integration

After suggesting, remind user to run:
```bash
/adr new [suggested title]
```
