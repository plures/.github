# Copilot Instructions (Organization)

## Before Committing

### Formatting (MANDATORY)
- **Rust projects**: Run `cargo fmt --all` before every commit
- **Node/TypeScript**: Run the project's lint/format command (e.g., `pnpm run format` or `npx prettier --write .`)
- **Python**: Run `black .` or `ruff format .` if configured

### Testing
- Run `cargo test` for Rust projects before committing
- Run `pnpm test` or `npm test` for Node projects if a test script exists
- Never commit code that fails existing tests

### Version Files
- **NEVER modify version fields** in `Cargo.toml`, `package.json`, or `deno.json` — the release workflow handles versioning automatically
- If a version looks wrong (e.g., contains "undefined"), do NOT fix it in your PR — create a separate issue

### Issue Requirements (ADR-0004)
- All issues MUST have at least one label AND an issue type set
- Without both, Copilot coding agent silently cancels

### PR Guidelines
- Keep PRs focused on the issue they're assigned to
- Don't modify unrelated files
- Write clear commit messages following conventional commits (feat:, fix:, chore:, etc.)
