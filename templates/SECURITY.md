# Security Policy

## Supported Versions

We provide security fixes for the versions listed below.

| Version | Supported          |
| ------- | ------------------ |
| latest  | ✅ Yes              |
| < 1.0   | ❌ No               |

<!-- Update this table to reflect your actual release policy -->

---

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

### Preferred method — GitHub Private Security Advisory

1. Go to the **Security** tab of this repository.
2. Click **"Report a vulnerability"**.
3. Fill in the details (description, impact, reproduction steps, suggested fix if known).
4. Submit. You will receive an acknowledgement within **2 business days**.

### Alternative — Email

If you cannot use the GitHub advisory flow, email **security@plures.dev** with:

- A description of the vulnerability
- Steps to reproduce
- Potential impact assessment
- Any suggested mitigations

We will confirm receipt within **2 business days** and aim to publish a fix within **7 days** for critical issues and **30 days** for others.

---

## Disclosure Policy

We follow [responsible disclosure](https://en.wikipedia.org/wiki/Responsible_disclosure):

1. Reporter notifies us privately.
2. We confirm and investigate.
3. We develop and test a fix.
4. We release the fix and credit the reporter (unless they prefer anonymity).
5. A public advisory is published after the fix is available.

---

## Security Best Practices for Users

- Always use the latest published version.
- Pin dependency versions in production and use `npm audit` / `cargo audit` regularly.
- Never expose API keys or secrets in client-side code.
- Report suspicious package activity to [npm security](https://www.npmjs.com/support) or [crates.io support](https://crates.io/policies).

---

## Acknowledgements

We thank all security researchers who responsibly disclose vulnerabilities. Contributors will be credited in release notes unless they request otherwise.
