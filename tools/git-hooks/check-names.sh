#!/bin/sh
# Refuses commits that contain a protected personal name (Nick's son's), in
# added lines, file paths or the commit message. Names are stored base64 so
# this file doesn't contain them. Nick alone authorizes an exception by
# creating ~/.config/ridgeline/allow-protected-names (sessions can't write
# outside the project). See SETUP.md, "Protected names".
NAMES="U2ltb24="
ALLOW="$HOME/.config/ridgeline/allow-protected-names"
[ -f "$ALLOW" ] && exit 0
found=""
for b in $NAMES; do
  n=$(printf '%s' "$b" | base64 -d)
  if [ "$1" = msg ]; then
    grep -qi -- "$n" "$2" && found=yes
  else
    git diff --cached --no-color -U0 --diff-filter=ACMR | grep '^+' | grep -v '^+++ ' | grep -qi -- "$n" && found=yes
    git diff --cached --name-only --diff-filter=ACMR | grep -qi -- "$n" && found=yes
  fi
done
if [ -n "$found" ]; then
  echo "Commit refused: it contains a protected personal name (see tools/git-hooks/check-names.sh)." >&2
  echo "Remove it, or ask Nick; only he can authorize an exception." >&2
  exit 1
fi
exit 0
