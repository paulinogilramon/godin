#!/usr/bin/env sh
# godin — thin launcher for godin.ps1 on Linux/macOS (requires pwsh).
exec pwsh -NoProfile -File "$(dirname "$0")/godin.ps1" "$@"
