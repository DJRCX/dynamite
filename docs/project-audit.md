# Project audit: faults and improvement opportunities

## Scope

This report captures the original static audit and tracks which findings have since been addressed. Descriptions of the defects refer to the pre-fix code; current resolution is recorded in each heading. Items still labeled as recommendations or needing verification remain open. No application or desktop-session changes were made during the audit.

## Prioritized findings

### 1. Protect tracked work during takeover rollback — High, addressed

`dev/takeover.sh:171–174` confirms the rollback and then runs `git reset --hard pre-dynamite` without checking that the working tree is clean or preserving tracked edits made since that tag. The reset discards those edits. The prepare path checks for a clean tree (`:23–28`), but rollback does not.

**Addressed:** rollback now refuses to reset when `git status --porcelain` is non-empty and prints the working-tree status before returning.

### 2. Make takeover application recoverable after unexpected failure — High, addressed for Niri config edits

`dev/takeover.sh:117–147` backs up and edits Niri configuration, but restoration is only implemented for user rejection and `niri validate` failure (`:151–160`). With `set -e`, an earlier command failure or interruption can exit after some files have been modified and leave the edits/backups in a partial state. The git merge and systemd enablement happen earlier and are not rolled back by the Niri recovery path.

**Addressed:** the script now installs an exit cleanup trap around Niri edits; it restores backed-up files and removes the newly created include after an error or interruption. The earlier git merge and systemd enablement remain separate and are not automatically rolled back.

### 3. Avoid disabling other displays after target enablement fails — High, addressed

`services/Displays.qml:98–107` calls `setEnabled(name, true)` for the requested output but ignores its boolean result, then records other outputs as disabled and queues commands to turn enabled outputs off. `setEnabled()` can return `false` at `:76–89`. The code therefore does not stop the “use only” sequence on reported failure. Whether the sequence can leave no active display depends on the compositor’s command behavior and should be reproduced before calling it a user-visible failure.

**Addressed:** `useOnly()` now waits for the queued `on` command to complete successfully before disabling other outputs. On command failure it leaves the other displays enabled and restores the target's saved enabled flag. Runtime testing against Niri is still recommended.

### 4. Prevent stale weather responses from replacing current data — Medium, addressed

`services/Weather.qml:53–79` starts an independent request on each refresh trigger, and `:82–94` starts a new geocoding request for each query. Neither path cancels or identifies superseded requests. Each callback writes shared service properties when it completes, so a slower older request can overwrite newer results or clear the newer search's `searching` state.

**Addressed:** weather refresh and geocoding now use generation counters so superseded callbacks cannot update state. Reordered-response behavior still needs a focused automated or mocked test.

### 5. Isolate per-download state in Wallhaven callbacks — Medium, overlap blocked

`services/Wallhaven.qml:21–24` stores pending URL/path/action/theme in singleton properties. `startDownload()` overwrites them (`:88–92`), while the mkdir/download callbacks later read the current properties (`:94–115`). `preview()` does not guard against an existing download (`:59–67`), so another preview can replace pending values while an earlier operation is active. A callback can then use the wrong URL, destination, or action. `keep()` has a guard, but it does not protect all starts.

**Addressed:** preview and download startup now reject overlapping mkdir/download/categorize operations. Per-request immutable state would be preferable if concurrent downloads are added later.

### 6. Remove developer-specific path from the Niri snippet — Medium, addressed using newest-instance IPC

Every IPC binding in `niri/simple-bar.kdl:3–13` points to `/home/djrcx/.config/quickshell/simple-bar`. On another account or installation path, those bindings target the wrong shell instance.

**Addressed:** bindings use `qs ipc --newest` instead of an account-specific config path. This assumes the intended shell is the most recently launched Quickshell instance; systems running multiple independent shells should use explicit instance selection.

### 7. Make nested-session state per-user and clean it on failed startup — Medium, addressed

`dev/run-nested.sh:10–13` and related `dev/ipc.sh:6` / `dev/shot.sh:6` use fixed `/tmp/dynamite-*` paths. Startup writes the PID before confirming Niri opened (`run-nested.sh:46–63`), and error exits at `:54–62` do not remove the PID file or temporary config. A later invocation can encounter stale state; predictable global paths also allow collisions between sessions/users.

**Addressed:** nested-session state and logs now live in a mode-700 per-user runtime directory, and early startup failures remove the PID, display state, and temporary config. PID identity validation and a simulated startup-failure test remain open.

### 8. Update the contributor guide to match the implemented repository — Medium, clarified in the guide

The current code and top-level `README.md` describe the implementation at the repository root. However `docs/README.md:5–7, 38–48, 55–62` still directs contributors through an 18-phase build in `dynamite/` and says legacy files remain untouched until a future Phase 18. `docs/01-architecture.md:5–25` likewise specifies a staged `dynamite/` directory and component names that differ from the current tree. `docs/09-phases.md` remains phrased as a build plan, despite the current implementation already containing the described systems. `docs/README.md:12–14` does call the phases historical where they differ, but the action-oriented instructions still conflict.

**Addressed in part:** `docs/README.md` now identifies the phased workflow and prompt as historical and points to the root-level project. The detailed architecture and phase specs still contain historical instructions, so readers should continue treating them as design references.

### 9. Reconcile Quickshell version records — Low, historical discrepancy labeled

`docs/01-architecture.md:3` says Quickshell 0.3.1; `docs/quickshell/README.md:5–6` and `:58–60` report 0.3.2. Version-sensitive changes need one clear baseline, while the platform guide correctly says to match installed runtime documentation.

**Addressed:** `docs/01-architecture.md` now labels its 0.3.1 stack as a historical snapshot and points to the version-specific platform references.

### 10. Expand repeatable automated tests and make checks discoverable — Medium, confirmed coverage gap

The checked-in QML test `tests/qml/tst_WallpaperCommand.qml` tests wallpaper command construction and selection, but the reviewed risk areas above have no corresponding tests in the visible test suite. The repository documentation does not provide a clear, authoritative test command. `docs/changes-since-v2.0.0.md:97–101` also records that no application tests were run for that audit; that is a dated audit record, not proof of the current test status.

**Improve:** document the supported Qt/QML test invocation and required prerequisites. Add hardware-independent tests for display command sequencing, request ordering, Wallhaven operation state, and takeover backup/rollback logic. Add shell/Python syntax and whitespace checks to a repeatable local or CI validation command.

### 11. Validate screenshot helper arguments — Low, addressed

`dev/spans.py:31–35` reads `sys.argv[1]` and converts it to an integer without checking argument count or conversion errors. `spans()` uses that row directly in `Image.getpixel()` (`:13–18`), so an invalid/out-of-range row or missing image arguments raises a traceback.

**Addressed:** the helper validates required arguments, integer row input, and image bounds, and reports concise errors for unreadable files.

## Suggested order

1. **Safety and recoverability:** protect rollback data; make takeover edits transactional; stop display deactivation when the target cannot be enabled.
2. **State correctness:** sequence/discard stale weather requests; isolate Wallhaven callback state.
3. **Portability and development reliability:** remove the hard-coded Niri home path; isolate nested-session state and cleanup.
4. **Maintenance:** clarify current-vs-historical documentation, reconcile the version record, then establish regression tests and helper validation.

## Verification checklist

- In a safe nested Niri setup, simulate a failed output-enable command and confirm that `useOnly()` leaves another enabled output untouched. Confirm against the Niri version installed before changing assumptions about command results or refresh-rate units.
- Mock weather requests and complete newer/older geocoding and forecast responses in both orders; only current inputs should update service state.
- Start overlapping Wallhaven preview/keep actions with controlled completion order; each callback should operate on its own URL, path, and action.
- In a disposable repository/config copy, create tracked and untracked changes and exercise rollback/failure paths; confirm the script refuses or preserves them and restores all Niri files after injected failures.
- Simulate nested Niri startup failure before socket creation; ensure no stale PID/state/config is treated as a running session.
- Search the distributed Niri snippet for account-specific absolute paths and test its documented setup on a non-default home/install path.
- Verify documentation file paths and the stated test command against the current tree and installed Quickshell/Qt versions.

Do not restart or stop `simple-bar.service` as part of these checks. Use dry-run/nested workflows for hardware or desktop integrations.