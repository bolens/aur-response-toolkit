# Requirement coverage

| Requirement | Source and acceptance evidence |
| --- | --- |
| FR-001 | `src/cli.rs`, exported exit constants, engine/report policy, and CLI integration tests. |
| FR-002 | `src/integrity.rs`, `src/inspection.rs`, lists/IOC registries, tamper/oversize and parsing tests. |
| FR-003 | Inspection/IOC adapters, package fixtures, and native security/inspection tests. |
| FR-004 | `src/engine.rs:remove_packages` and ApplyHardening routing; native recovery/dry-run fixtures. |
| FR-005 | `src/engine.rs:scrub_history`, atomic config writer, history fixtures and recovery tests. Invoking this recovery command without --dry-run is a write operation. |
| FR-006 | `src/config.rs`, `src/model.rs`, `src/report.rs`, legacy migration and reporting/exit-policy tests. |

## Verification receipt

Native formatting, locked all-target Clippy with warnings denied, 65 Rust tests, and the locked release build passed. Site metadata rejection fixtures, accessibility, and workflow syntax/security passed. Separate self-review checked bounded no-follow inspection, exit/report policy, removal confirmation, explicit hardening apply, and backup-before-replacement history scrubbing. Tests used fixture package, log, history, and campaign data. No workstation scan, recovery, installation, or publication was performed.


## Exhaustive retrofit pass, in progress

The native source at `fa7ad7c998d8196bc0cea495fea8c3a85c631081` was inspected across CLI routing, configuration, ALPM adapters, registry/list parsing, evidence inspection, detection, recovery, and reporting. Ancillary site, packaging, and automation review is still pending. The earlier verification receipt is historical and does not close this pass.

| Corrective requirement | Regression evidence |
| --- | --- |
| FR-007 | `explicit_removal_verification_reports_only_installed_targets`: absent explicit target incorrectly returned 1; absent and mixed inventories now return 0/1 and report only the installed target. |
| FR-008 | `hardening_preserves_unterminated_npm_configuration`: apply concatenated the new setting to a registry URL; dry-run preserves bytes, apply separates lines, and repeating apply preserves the result. |
| FR-009 | `inspection::tests::rejects_fifo_without_waiting_for_a_writer`: a bounded child blocked for three seconds before the parent killed/reaped it; Linux nonblocking open and descriptor type validation now reject the FIFO. Existing symlink, byte-bound and hash fixtures still pass. |
| FR-010 | `insufficient_evidence_never_claims_complete_summary_coverage`: summaries incorrectly claimed complete coverage for insufficient state at both exit 0 and 3; coverage now checks insufficient state/counters independently of exit policy. |
| FR-011 | `maintainer_comment_does_not_suppress_independent_hook_evidence`: a known comment false positive suppressed an unrelated suspicious hook; filtering only that comment preserves benign-comment acceptance and detects the hook. Text is never executed. |
| FR-012 | `persistence_decode_and_size_failures_mark_coverage_incomplete`: malformed cron text did not increment unreadable evidence; the shared inspected-text adapter now accounts for it and ignores non-file traversal entries. |

| FR-013 | `report_publication_failure_is_not_silent_success`: blocked directory/state/summary destinations previously returned 0 without JSON; each now returns 3 with a diagnostic. |
| FR-014 | `prune_days_rejects_overflow_for_both_argument_forms`: both accepted `u64::MAX`; validation rejects overflowing seconds conversions while retaining zero/ordinary values. |
| FR-015 | `atomic_replacement_preserves_private_file_permissions`: a 0600 file became 0644; replacement now preserves its mode, and new Unix output starts at 0600. Concurrent atomic publication remains covered. |

The Spec Kit validation/update workflow references and both tooling references advance together to `c161a6757130ea687def9eb1e81c6a4190488f07`, the fleet's reviewed immutable integration revision. No live scan, package removal, shell-history change, service change, or publication was performed during these fixtures.


### Current corrective-batch verification

The native development gate passed: formatting, locked all-target Clippy with warnings denied, 73 Rust tests, locked release build, site release-metadata fixtures, static site accessibility, actionlint, and offline zizmor. Five development-adapter tests and their source checks passed. Baseline/changelog Markdown and regenerated changelog equality passed. Separate self-review traced all changed callers, file modes, failure paths, fixture isolation, and report/exit semantics. This is self-review, not an independent review. Linux FIFO coverage is platform-conditional; hosted Arch/macOS checks remain delivery evidence.

Source-wide sensitive-content review scanned 194 files with no secret candidates or skipped files. All 44 privacy-review lines already exist unchanged in the base and are documentation/examples, public source references, or attribution. No actual workstation recovery or package operation was run. The open findings in [native legacy contracts](legacy-native-contracts.md) and the ancillary audit remain incomplete.

A subsequent compatibility review reproduced loss of the final newline during comment filtering. `heuristic_comment_filter_preserves_custom_pattern_line_endings` now verifies that retained text keeps its original line endings for user-supplied patterns.
