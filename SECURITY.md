# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in dama-rb, please report it responsibly.

**Do not open a public issue.** Instead, email [caiubi@icloud.com](mailto:caiubi@icloud.com) with:

- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Scope

dama-rb includes native code (Rust FFI bindings) and web components (WASM, JS bridge).
Security concerns may include:

- Memory safety issues in the Rust backend
- FFI boundary vulnerabilities
- Web backend (JS eval, WASM) injection risks
- Dependency vulnerabilities

## Response

I will acknowledge receipt within 48 hours and aim to provide a fix or mitigation
plan within 7 days.
