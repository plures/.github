# Contributing to <!-- Project Name -->

Thank you for your interest in contributing! This guide covers everything you need to get started.

---

## Code of Conduct

All contributors are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md). Be respectful, inclusive, and constructive.

---

## How to Contribute

### Reporting Bugs

1. Search [existing issues](../../issues) to avoid duplicates.
2. Open a new issue using the **Bug Report** template.
3. Include steps to reproduce, expected behavior, and actual behavior.

### Suggesting Features

1. Open a [Feature Request](../../issues/new?template=feature_request.md) issue first.
2. Describe the problem you're solving and why the feature fits the project.
3. Wait for maintainer feedback before opening a PR.

### Submitting Pull Requests

1. Fork the repo and create a branch from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   ```
2. Make your changes following the [code style](#code-style) guidelines.
3. Add or update tests to cover your change.
4. Ensure the full test suite passes:
   ```bash
   npm test        # Node.js / TypeScript
   cargo test      # Rust
   ```
5. Commit using [conventional commits](#commit-messages).
6. Push and open a PR against `main`.

---

## Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`

**Breaking changes:** append `!` after the type or add `BREAKING CHANGE:` in the footer.

Examples:
```
feat(auth): add OAuth2 provider support
fix(parser): handle empty input gracefully
docs: update API reference for v2
chore!: drop Node.js 18 support
```

PR titles must also follow this format — they become the squash-merge commit message.

---

## Code Style

### TypeScript / JavaScript

- **Strict TypeScript** — `strict: true` in `tsconfig.json`, no `any` without justification.
- **ESM only** — no `require()` or CommonJS.
- **Named exports only** — no default exports.
- Run `npm run lint` before pushing; do not add `eslint-disable` comments.

### Rust

- `cargo fmt` before every commit.
- `cargo clippy -- -W clippy::all` must pass clean — fix warnings, do not suppress them.
- Use `thiserror` for library error types, `anyhow` for application-level errors.
- Prefer `rustls-tls` over `native-tls` to avoid openssl-sys.

---

## Testing

- Unit tests are required for all new public functions.
- Integration tests go in the `tests/` directory (or colocated per project convention).
- Never call real external APIs in tests — mock or stub them.
- Do not skip tests or add `#[ignore]` / `.skip` to make CI pass.

---

## CI / Release

- CI runs automatically on every push and PR.
- Releases are created automatically from conventional commits — **do not manually bump version numbers**.
- Publishing to registries (npm, crates.io, GHCR) happens via the org reusable release workflow.

---

## Getting Help

Open a [Discussion](../../discussions) or comment on the relevant issue. Maintainers aim to respond within 2 business days.
