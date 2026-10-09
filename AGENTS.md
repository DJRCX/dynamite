# Dynamite contributor rules

- Never restart or stop `simple-bar.service`; Quickshell live reloads QML.
- Every animated value uses a spring from `theme/Motion.qml`.
- Read colors, design sizes and user-configurable values from `Theme`, `Metrics` and `Config`.
- Do not push changes. Commit only when asked.
- Keep the shell self-contained. The one-time config import is the only legacy-file read.
- Use `DYNAMITE_DEV=1` inside the nested session. Hardware integrations must be dry-run there.
- Use argv arrays for every process; do not construct shell command strings.
- Stop the nested session after development work.
