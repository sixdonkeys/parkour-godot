# Survey: remote-test

## Joel Bruner, macOS screen-lock detection — https://gist.github.com/brunerd/5ba75737b2093e88eb30aa614584a21b (fetched through the GitHub API, 2026-11-15)

> function screenIsLocked { [ "$(/usr/libexec/PlistBuddy -c "print :IOConsoleUsers:0:CGSSessionScreenIsLocked" /dev/stdin 2>/dev/null <<< "$(ioreg -n Root -d1 -a)")" = "true" ] && return 0 || return 1; }

## Apple Developer Forums — https://developer.apple.com/forums/thread/803553 ("Macos Tahoe issue launching apps through SSH") and https://developer.apple.com/forums/thread/756081 ("'open' command in macOS fails to launch .app file in non GUI environment")

Consulted. The pages render their posts by script, so `curl` returned no post text to quote; no excerpt is claimed from them. Their titles report that launching apps from SSH can fail on recent macOS. That is why `open` over SSH is tested on the Neo itself (`remote neo play`, then `bench`) before the loop is trusted.

## Build brief, item 2 and the harness addendum

> It needs nothing installed on the Neo beyond Tailscale and macOS's own Remote Login: no Godot, no git, no copy of this repository.

> The Neo is a boy's own laptop: `bench` and `play` never start while it has been touched in the last five minutes.

> A remote number is honest only if the game was really on screen, so the benchmark log records, for the whole run, whether the display was awake and unlocked and the game's window in front, the refresh rate, the power source and whether a low-power mode was on.

> Use that alias and nothing else: never create, read or copy an SSH key, and never write to `~/.ssh`.

## Local probes, 2026-11-15

`tailscale status` from the Fedora laptop (outside the sandbox) listed `mac-mini-m1`, `thinkpad-t14-gen3`, `thinkpad-t450s` and others; no Neo yet.

`python3 tools/verify.py remote unreachable check`:
> remote unreachable check: unreachable: cannot reach ridgeline-unreachable.invalid over SSH (ssh: Could not resolve hostname ridgeline-unreachable.invalid: Name or service not known)

`python3 tools/verify.py remote unreachable-timeout check` (8.1 s):
> remote unreachable-timeout check: unreachable-timeout: cannot reach 192.0.2.1 over SSH (ssh: connect to host 192.0.2.1 port 22: Connection timed out)
