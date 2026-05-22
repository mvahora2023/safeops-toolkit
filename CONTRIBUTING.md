# Contributing to SafeOpsToolkit

Thank you for taking the time to contribute. This guide explains the expectations for
pull requests, tests, allowlist changes, and the module's security principles.

---

## Ground rules

- All changes must pass the full Pester 5 test suite (87+ tests) with zero failures.
- PSScriptAnalyzer must report no Errors or Warnings under `PSScriptAnalyzerSettings.psd1`.
- Code coverage must remain at or above 80% (enforced on the PS 7 CI matrix leg).
- No new external dependencies — the module must remain zero-dependency beyond PowerShell 5.1.
- No changes to the public API (function names, parameter names, output schemas) without a
  corresponding version bump and CHANGELOG entry.

---

## Pull request process

1. **Fork → branch → PR**: branch names should be descriptive, e.g.
   `feature/get-service-health` or `fix/log-rotation-edge-case`.
2. **One logical change per PR**: mix unrelated fixes only when they are trivially small.
3. **Keep the safety model intact**: read [THREAT_MODEL.md](docs/THREAT_MODEL.md) and
   [DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md) before proposing structural changes.
4. **Update CHANGELOG.md**: add an entry under `[Unreleased]` in the appropriate section
   (Added / Changed / Fixed / Security).
5. **Update docs if needed**: if a public command is added or changed, update README.md
   and the relevant section of RUNBOOK.md.
6. **CI must be green**: the `lint` job (PSScriptAnalyzer) must pass before the `test` job
   runs; both must succeed on PS 5.1 and PS 7.

---

## Test requirements

Every code change must be accompanied by tests. The minimum bar:

| Change type | Required tests |
|---|---|
| New public command | Parameter validation, output schema, WhatIf (if mutating), at least one happy-path and one error-path |
| New private helper | At least one happy-path and one edge-case per distinct code branch |
| Bug fix | A regression test that would have caught the bug |
| Refactor | No net reduction in test count or coverage |

Run the suite locally before pushing:

```powershell
$cfg = New-PesterConfiguration
$cfg.Run.Path         = '.\Tests'
$cfg.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $cfg
```

---

## Allowlist update procedure

Adding a service to the allowlist is a **deliberate, high-scrutiny change**. The process:

1. Open an issue describing the service, its purpose, and why it belongs on the allowlist.
2. Obtain at least one approving review from a maintainer before merging.
3. Update **both** of the following in the same commit (the Pester allowlist-sync test will
   fail if they diverge):
   - `[ValidateSet(...)]` attribute on the `$Name` parameter in every public service command.
   - `$allowlist` array in `SafeOpsToolkit/Private/Assert-SafeOpsAllowed.ps1`.
4. Bump the module version to the next **minor** release (`1.X.0`) in `SafeOpsToolkit.psd1`
   and add a CHANGELOG entry under a new `[1.X.0]` heading.
5. Update the allowlist reference in `README.md`, `RUNBOOK.md`, and `THREAT_MODEL.md`.

**There is no `-Force` or `-BypassAllowlist` flag. Do not add one.**

---

## Security principles

SafeOpsToolkit exists to make unsafe operations impossible, not just discouraged. When
evaluating a contribution, ask:

- Does this add a parameter that accepts arbitrary input that could be used to target
  services outside the allowlist?
- Does this create a code path where credentials, tokens, or secrets could be logged,
  printed, or stored?
- Does this remove, weaken, or bypass the dual-enforcement model (`[ValidateSet]` +
  `Assert-SafeOpsAllowed`)?
- Does this introduce a network call, file download, or external process execution?

If the answer to any of these is yes, the PR will not be merged without an explicit,
documented security review.

---

## Commit message style

Use a short imperative subject line (≤ 72 characters) followed by a blank line and a body
that explains *why*, not just *what*:

```
fix: handle Get-Service timeout on slow SCM responses

Get-Service can hang for several seconds when the SCM is busy. Adding
-ErrorAction Stop ensures the catch block fires and logs an ERROR entry
rather than leaving the function blocked indefinitely.
```

Prefix options: `feat:`, `fix:`, `tests:`, `security:`, `docs:`, `ci:`, `refactor:`.
