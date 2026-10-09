#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGING_NAME="$(basename "$SCRIPT_DIR")"
command_name="${1:-}"
shift || true

die() { echo "takeover: $*" >&2; exit 1; }
confirm() {
    local prompt="$1" answer
    read -r -p "$prompt [y/N] " answer
    [[ "$answer" == "y" || "$answer" == "Y" ]]
}
show_status() { git -C "$ROOT" status --short; }

prepare() {
    local status current head temp worktree entry force=false
    for entry in "$@"; do
        if [[ "$entry" == "--force" ]]; then force=true; else die "unknown prepare option: $entry"; fi
    done
    status="$(git -C "$ROOT" status --porcelain)"
    if [[ -n "$status" ]]; then
        echo "Working tree is not clean:" >&2
        show_status >&2
        echo "Commit the work first, then run: $0 prepare" >&2
        exit 1
    fi
    if git -C "$ROOT" show-ref --verify --quiet refs/tags/pre-dynamite; then
        $force || die "tag pre-dynamite already exists (use --force only after reviewing the existing tag)"
    fi
    git -C "$ROOT" show-ref --verify --quiet refs/heads/takeover && die "branch takeover already exists"
    current="$(git -C "$ROOT" branch --show-current)"
    [[ -n "$current" ]] || die "detached HEAD is not supported"
    head="$(git -C "$ROOT" rev-parse HEAD)"
    if $force; then git -C "$ROOT" tag -f pre-dynamite "$head"; else git -C "$ROOT" tag pre-dynamite "$head"; fi
    temp="$(mktemp -d "${TMPDIR:-/tmp}/dynamite-takeover.XXXXXX")"
    worktree="$temp/worktree"
    cleanup() { git -C "$ROOT" worktree remove --force "$worktree" >/dev/null 2>&1 || true; rmdir "$temp" 2>/dev/null || true; }
    trap cleanup EXIT
    git -C "$ROOT" worktree add -b takeover "$worktree" "$current"
    git -C "$worktree" rm -r --ignore-unmatch -- shell.qml scripts systemd tlp install.sh README.md CHANGELOG.md GEMINI.md AGENTS.md config.json .gitignore
    local stage="$worktree/$STAGING_NAME"
    [[ -d "$stage" ]] || die "staging directory missing: $STAGING_NAME"
    shopt -s dotglob nullglob
    for entry in "$stage"/*; do
        [[ -e "$entry" ]] || continue
        if [[ "$(basename "$entry")" == "takeover.sh" ]]; then
            git -C "$worktree" mv "$entry" "$worktree/dev/takeover.sh"
        else
            git -C "$worktree" mv "$entry" "$worktree/"
        fi
    done
    rmdir "$stage"
    shopt -u dotglob nullglob
    if [[ -d "$worktree/docs/dynamite" ]]; then
        shopt -s nullglob dotglob
        for entry in "$worktree/docs/dynamite"/*; do git -C "$worktree" mv "$entry" "$worktree/docs/"; done
        rmdir "$worktree/docs/dynamite"
        shopt -u nullglob dotglob
    fi
    local docs_prefix="docs/${STAGING_NAME}/" dev_prefix="${STAGING_NAME}/dev/"
    while IFS= read -r -d '' entry; do
        sed -i "s#${docs_prefix}#docs/#g; s#${dev_prefix}#dev/#g" "$entry"
    done < <(find "$worktree/docs" "$worktree" -maxdepth 1 -type f \( -name '*.md' -o -name '*.kdl' \) -print0)
    local runtime_prefix="${STAGING_NAME}/"
    if rg -n "$runtime_prefix" "$worktree" --glob '*.{qml,js,sh}' --glob '!*.service' | rg -v '(\.config/dynamite|\.local/state/dynamite|\.cache/dynamite)' ; then
        die "runtime path check failed; review the matches above"
    fi
    git -C "$worktree" add -A
    git -C "$worktree" commit -m "Replace simple-bar with Dynamite"
    git -C "$ROOT" worktree remove "$worktree"
    trap - EXIT
    rmdir "$temp" 2>/dev/null || true
    git -C "$ROOT" show --stat --oneline takeover
    echo "Prepared. Review with: git show --stat takeover"
    echo "Next step (after reviewing): $SCRIPT_DIR/takeover.sh apply --dry-run"
}

apply_takeover() {
    local dry=false niri_dir binds config startup backup
    [[ "${1:-}" == "--dry-run" ]] && dry=true
    [[ "$(git -C "$ROOT" branch --show-current)" == "main" ]] || die "apply requires the main branch"
    [[ -z "$(git -C "$ROOT" status --porcelain)" ]] || { show_status; die "apply requires a clean working tree"; }
    git -C "$ROOT" show-ref --verify --quiet refs/tags/pre-dynamite || die "tag pre-dynamite is missing"
    git -C "$ROOT" show-ref --verify --quiet refs/heads/takeover || die "branch takeover is missing"
    [[ "$(git -C "$ROOT" merge-base HEAD takeover)" == "$(git -C "$ROOT" rev-parse HEAD)" ]] || die "main moved since prepare; rerun prepare after reviewing changes"
    cat <<'PLAN'
Plan:
  1. Fast-forward main to takeover.
  2. Install the prepared user systemd units, reload the user manager and enable them (never start/stop/restart).
  3. Back up and update Niri include/bind files; validate the temporary configuration before keeping it.
  4. Print any TLP drop-in command for manual installation.
  5. Show the post-login checklist.
PLAN
    if $dry; then echo "Dry run: no files or system settings changed."; return; fi
    confirm "Apply the takeover to this checkout and user configuration?" || { echo "Cancelled."; return; }
    git -C "$ROOT" merge --ff-only takeover
    mkdir -p "$HOME/.config/systemd/user"
    install -m 0644 "$ROOT/systemd/"*.service "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload
    systemctl --user enable simple-bar.service awww-daemon.service
    for unit in cliphist.service cliphist-images.service; do
        systemctl --user is-enabled --quiet "$unit" || echo "Warning: $unit is not enabled."
    done
    mkdir -p "$HOME/.config/autostart"
    for desktop in polkit-gnome-authentication-agent-1.desktop polkit-mate-authentication-agent-1.desktop; do
        if [[ -f "/etc/xdg/autostart/$desktop" ]]; then
            printf '[Desktop Entry]\nHidden=true\n' > "$HOME/.config/autostart/$desktop"
        fi
    done
    niri_dir="$HOME/.config/niri"
    binds="$niri_dir/config.d/70-binds.kdl"
    config="$niri_dir/config.kdl"
    startup="$niri_dir/config.d/50-startup.kdl"
    for file in "$binds" "$config" "$startup"; do
        [[ -f "$file" ]] || continue
        [[ ! -e "$file.pre-dynamite" ]] || die "backup already exists: $file.pre-dynamite"
        cp -p "$file" "$file.pre-dynamite"
    done
    cp "$ROOT/niri/simple-bar.kdl" "$niri_dir/config.d/75-simple-bar.kdl"
    python3 - "$binds" <<'PY'
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]); lines=p.read_text().splitlines(True)
keys=re.compile(r'^\s*(?:Mod\+Alt\+(?:Left|Right|L)|Mod\+Shift\+Ctrl\+Q|XF86MonBrightness(?:Up|Down))\b')
out=[]; depth=0; dropping=False
for line in lines:
    if not dropping and depth==0 and keys.search(line):
        dropping=True
    if dropping:
        depth += line.count('{')-line.count('}')
        if depth<=0: dropping=False; depth=0
        continue
    out.append(line)
p.write_text(''.join(out))
PY
    if [[ -f "$startup" ]]; then
        sed -i -E 's/^([[:space:]]*spawn-at-startup[[:space:]]+"[^"]*polkit-mate-authentication-agent-1[^"]*")/\/\/ \1/' "$startup"
    fi
    python3 - "$config" <<'PY'
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]); text=p.read_text()
line=re.compile(r'(?m)^(\s*include\s+"[^"]*70-binds\.kdl"\s*)$')
if not line.search(text): raise SystemExit('could not locate the 70-binds include in config.kdl')
if '75-simple-bar.kdl' not in text: text=line.sub(lambda m:m.group(1)+'\ninclude "config.d/75-simple-bar.kdl"',text,count=1)
p.write_text(text)
PY
    echo "Niri changes prepared. Review the diff before validating:"
    for file in "$binds" "$config" "$startup"; do [[ -f "$file.pre-dynamite" ]] && diff -u "$file.pre-dynamite" "$file" || true; done
    if ! confirm "Keep these Niri changes?"; then
        for file in "$binds" "$config" "$startup"; do [[ -f "$file.pre-dynamite" ]] && cp -p "$file.pre-dynamite" "$file"; done
        rm -f "$niri_dir/config.d/75-simple-bar.kdl"
        echo "Niri changes restored; the repository merge and systemd enablement remain applied."
        return
    fi
    if ! niri validate -c "$config"; then
        for file in "$binds" "$config" "$startup"; do [[ -f "$file.pre-dynamite" ]] && cp -p "$file.pre-dynamite" "$file"; done
        rm -f "$niri_dir/config.d/75-simple-bar.kdl"
        die "Niri validation failed; original configuration restored"
    fi
    if [[ -f /etc/tlp.d/90-simple-bar.conf ]] && ! cmp -s "$ROOT/tlp/simple-bar.conf" /etc/tlp.d/90-simple-bar.conf; then
        echo "TLP file differs. If desired, install manually with: sudo install -m 0644 '$ROOT/tlp/simple-bar.conf' /etc/tlp.d/90-simple-bar.conf"
    fi
    cat <<'CHECKLIST'
After logging back in, check the service, notification toast, polkit prompt, and the Mod+Space / Mod+V / Mod+Slash / Mod+Escape bindings.
CHECKLIST
    if confirm "Log out now?"; then niri msg action quit --skip-confirmation; fi
}

rollback() {
    echo "Rollback will reset the checkout to pre-dynamite and restore prepared user-config backups."
    confirm "Continue with rollback?" || { echo "Cancelled."; return; }
    git -C "$ROOT" reset --hard pre-dynamite
    local niri_dir="$HOME/.config/niri" file
    for file in "$niri_dir/config.d/70-binds.kdl" "$niri_dir/config.kdl" "$niri_dir/config.d/50-startup.kdl"; do
        [[ -f "$file.pre-dynamite" ]] || continue
        cp -p "$file.pre-dynamite" "$file"
        rm -f "$file.pre-dynamite"
    done
    rm -f "$niri_dir/config.d/75-simple-bar.kdl"
    for desktop in polkit-gnome-authentication-agent-1.desktop polkit-mate-authentication-agent-1.desktop; do
        override="$HOME/.config/autostart/$desktop"
        if [[ -f "$override" ]] && grep -qx 'Hidden=true' "$override"; then rm -f "$override"; fi
    done
    mkdir -p "$HOME/.config/systemd/user"
    install -m 0644 "$ROOT/systemd/"*.service "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload
    echo "Checkout restored. Restore any user-config backups, then log out and back in."
}

case "$command_name" in
    prepare) prepare "$@" ;;
    apply) apply_takeover "$@" ;;
    rollback) rollback ;;
    *) echo "Usage: $0 {prepare|apply [--dry-run]|rollback}" >&2; exit 2 ;;
esac
