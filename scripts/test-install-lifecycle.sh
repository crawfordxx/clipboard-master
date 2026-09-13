#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# The graceful quit gate must run before replacing the installed bundle.
QUIT=$(grep -n 'swift scripts/quit-running-app.swift "$DEST"' install.sh | cut -d: -f1)
REPLACE=$(grep -n 'rm -rf "$DEST"' install.sh | cut -d: -f1)
[[ -n "$QUIT" && "$QUIT" -lt "$REPLACE" ]]
! grep -Eq 'forceTerminate|kill\(|pkill' scripts/quit-running-app.swift
swift scripts/quit-running-app.swift /nonexistent/ClipboardMaster-install-test.app
printf 'PASS graceful exit gate precedes replacement; absent target succeeds; no forced termination\n'
