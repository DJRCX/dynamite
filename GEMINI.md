# Project Rules & Guidelines

## Critical Rules
1. **NEVER run `systemctl --user restart simple-bar.service`**:
   - Doing so terminates the entire systemd service cgroup, which kills all running applications and processes launched from the bar (browsers, IDEs, steam, etc.).
   - To reload configuration or QML changes:
     - Quickshell live-reloads files automatically when saved.
     - Never restart the `simple-bar.service` unit via systemctl during a live session.

2. **NEVER push code to GitHub or remote repositories unless explicitly instructed**:
   - Never run `git push` autonomously.
   - All code changes and commits must remain strictly local unless the user explicitly requests to push.
