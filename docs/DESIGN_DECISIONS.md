# SafeOpsToolkit — Design Decisions

This document records the significant architectural and design choices made during the
development of SafeOpsToolkit, along with the reasoning behind each. Future contributors
should read this before proposing changes that touch the module's security model or public API.

---

## DD-001 — Explicit export list over wildcard

**Decision:** `SafeOpsToolkit.psm1` uses `Export-ModuleMember -Function @(...)` with an
explicit list, and the manifest sets `FunctionsToExport` to the same explicit list. No
wildcard (`*`) exports are used in either location.

**Rationale:** Wildcard exports leak every function defined in `Public/` **and** any helpers
accidentally defined in the global scope during dot-sourcing into the module's public surface.
This makes it easy for callers to take accidental dependencies on internal APIs, and silently
expands the module's attack surface whenever a new private helper is added. Explicit exports
also enable `Get-Command -Module SafeOpsToolkit` to return exactly the intended API.

---

## DD-002 — Private helpers intentionally absent from the manifest

**Decision:** `FunctionsToExport` in `SafeOpsToolkit.psd1` names only the six public commands.
The three private helpers (`Write-SafeOpsLog`, `Assert-SafeOpsAllowed`, `ConvertTo-SafeOpsResult`)
are omitted.

**Rationale:** Private functions exist to serve the implementation, not the caller. Exposing
them would lock their signatures and semantics into a compatibility contract, preventing
refactoring. Keeping them private also means they cannot be called out-of-sequence — a caller
cannot invoke `Assert-SafeOpsAllowed` independently to "test" whether a service name is allowed
and then use that result to drive a direct `Restart-Service` call that bypasses the module.

---

## DD-003 — Allowlist enforcement in a single private function

**Decision:** All public commands that touch services call `Assert-SafeOpsAllowed` as their
first substantive action. The authoritative allowlist (`@('Spooler', 'wuauserv', 'WinDefend')`)
lives in exactly one place.

**Rationale:** If each public function maintained its own allowlist copy, they would inevitably
diverge. A single function also means a single location to audit, update, and test. The
`[ValidateSet]` attributes in public function parameters provide a first-pass rejection at the
parameter-binding layer; `Assert-SafeOpsAllowed` provides a defence-in-depth check at runtime.
Both must be kept in sync — this is enforced by the Pester test suite.

**Trade-off considered:** An allowlist loaded from a configuration file would be more flexible,
but it would require validating the source and integrity of that file, introducing a new attack
surface. Hardcoding the list means any change requires a PR, code review, and a module version
bump — which is the intended governance model.

---

## DD-004 — SupportsShouldProcess with ConfirmImpact on mutating commands

**Decision:** `Restart-AllowlistedService` uses `ConfirmImpact = 'High'` and
`Set-AllowlistedServiceStartupType` uses `ConfirmImpact = 'Medium'`. Both use the affirmative
`if ($PSCmdlet.ShouldProcess(...)) { }` pattern rather than the early-return negation form.

**Rationale:** `ConfirmImpact` signals the severity of the action relative to the session's
`$ConfirmPreference`. At `High`, PowerShell will always prompt unless the caller explicitly
passes `-Confirm:$false`, which creates a visible opt-in for non-interactive automation.
The affirmative pattern (rather than `if (-not $PSCmdlet.ShouldProcess(...)) { return }`) is
required by PSScriptAnalyzer's `PSShouldProcess` rule, which validates that `ShouldProcess`
is called when `SupportsShouldProcess` is declared. Satisfying the analyser keeps CI clean
and signals correct ShouldProcess usage to readers.

---

## DD-005 — Module structure over standalone scripts

**Decision:** The toolkit is a PowerShell module (`.psm1` + `.psd1`) rather than a collection
of standalone scripts or a single monolithic script file.

**Rationale:**

- **Discoverability:** `Get-Command -Module SafeOpsToolkit` lists the public API. Standalone
  scripts have no equivalent.
- **Encapsulation:** Private helpers are genuinely private — callers cannot call them directly.
  A monolithic script file has no equivalent mechanism.
- **Versioning:** The manifest carries a `ModuleVersion` field. Downstream consumers can pin
  to a specific version with `#Requires -Modules @{ ModuleName = 'SafeOpsToolkit'; ModuleVersion = '1.0.0' }`.
- **Help system integration:** Comment-based help in function files is surfaced automatically
  by `Get-Help`. Standalone scripts require explicit documentation maintenance.
- **Testability:** Pester can import and unload a module cleanly in `BeforeAll`/`AfterAll`
  blocks, giving each test run a reproducible state.

---

## DD-006 — Pester 5 + GitHub Actions CI

**Decision:** The test suite uses Pester 5's configuration-object API (not the legacy
positional parameter form), and the CI workflow runs both `Invoke-Pester` and
`Test-ModuleManifest` on every push and pull request.

**Rationale:** The manifest is the contract between the module and its consumers.
`Test-ModuleManifest` failing in CI means a broken manifest can never reach `main`.
Pester 5's configuration API (`New-PesterConfiguration`) enables structured test results
in JUnit XML format, which GitHub Actions can consume natively for test-result reporting.

**What CI does not do:** CI does not run integration tests against live Windows services
(that would require a real Windows runner with specific services present and admin rights).
The test suite uses mocks for all SCM and Event Log calls. Real-environment validation is
the responsibility of a pre-production staging step outside this repository.

---

## DD-007 — Intentional exclusions

The following capabilities were explicitly considered and rejected:

| Capability | Reason for exclusion |
|---|---|
| `-ComputerName` / remote targeting | Adds credential management complexity and a much larger attack surface. Remote operations belong in a separate, purpose-built tool with appropriate authentication controls. |
| Configurable allowlist (JSON/registry) | Configuration files can be tampered with or replaced. A hardcoded list requires a code change, code review, and a version bump to modify — which is the intended change-control model. |
| `-BypassAllowlist` switch | A bypass flag defeats the entire purpose of an allowlist. Any legitimate need for a service outside the list should go through the allowlist-update process. |
| Arbitrary scriptblock or `-Command` parameters | Accepting scriptblocks or string commands makes the module a general-purpose execution proxy, eliminating all safety guarantees. |
| Credential parameters (`-Credential`, `-Password`) | No credential parameters exist anywhere in the module. There is no code path through which a secret can enter the system. This is enforced by the absence of the parameters, not by input validation. |
| Automatic log forwarding (SIEM, HTTP) | Network output introduces dependencies, latency, and additional attack surface. Log forwarding is an operational concern handled by the host's log-collection agent. |
| `Disable-AllowlistedService` or `Stop-AllowlistedService` | Stopping services (as distinct from restarting) is a higher-risk operation with a narrower legitimate use case. It can be added in a future version with appropriate review, but was excluded from v1.0 to keep the scope minimal. |

---

## DD-008 — Ordered hashtables for output consistency

**Decision:** All calls to `ConvertTo-SafeOpsResult` pass `[ordered] @{ ... }` rather than
`@{ ... }`.

**Rationale:** Unordered hashtables produce `PSCustomObject`s whose property order is
non-deterministic across PowerShell versions and object instances. Ordered hashtables produce
objects with properties in declaration order, which means `Format-Table` columns appear in a
predictable, human-readable sequence without requiring an explicit `Select-Object` call.
