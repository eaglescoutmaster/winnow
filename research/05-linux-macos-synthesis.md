# Linux and macOS: synthesis

How the research in [linux/findings.md](linux/findings.md) and [macos/findings.md](macos/findings.md)
became `catalog/linux.json` and `catalog/macos.json`. Every catalog item carries its own sources.

## Design decisions

- **Closed set of reversible operations.** Linux: remove a package (apt, dnf, snap, flatpak), disable a
  systemd unit, set a gsettings key, set `KEY=value` in a file under `/etc`. macOS: `defaults write`,
  move an app to the Trash, `launchctl disable`. Anything that fits none of these is left out
  (Ubuntu Pro apt news, the KDE feedback switch, Spotlight suggestion arrays, MDM-only keys).
- **Package removals are previewed.** `apt-get -s remove` (or `rpm -e --test`) runs at plan time; if
  anything besides the named package would go, the item is `skip:blocked`. This is what keeps a
  catalog entry that is a soft dependency on Ubuntu from pulling a metapackage on Debian.
- **Remove, never purge; never autoremove.** Configuration stays so reinstalling restores behaviour.
- **Distribution match is exact** (`ID` in `/etc/os-release`). Derivatives such as Linux Mint and
  Pop!_OS are not assumed to behave like their parent; their defaults were not verified.
- **No Apple background agents.** `launchctl disable` on them needs SIP off and breaks AirDrop,
  Messages, widgets, Touch ID and more. Only legacy network daemons that the NIST mSCP baseline
  disables with SIP on are offered; the reported-breakage labels are in `protected.labels`.
- **Apple Intelligence** has no stable preference key (it is named after the account id), so it is
  not in the catalog. Use System Settings.
- **Snapshots are a safety net, the run log is the revert path.** Timeshift/Snapper or a Time
  Machine local snapshot is taken first; without one the engine stops unless `--no-snapshot`.
- **Tiers.** `firefox-snap` and `snap-store` were moved to `never-default` so that no profile removes
  the default browser or the only graphical installer; the file indexers are `aggressive` and are
  masked, because plain disable does not survive D-Bus activation.

## Not verified on real machines

Neither catalog has been applied on a real desktop. CI runs the engine's real plan, apply and revert
against throwaway targets on Ubuntu and macOS runners, which proves the operations, not the catalog
entries. Unit names were verified on Ubuntu 24.04 only; most macOS keys have no source naming the
build they were tested on, and none for macOS 27. See the UNVERIFIED sections of both findings files.

## Left out of the linux catalog

| Candidate | Reason |
|---|---|
| `python3` | moved to protected.packages; never offered |
| `network-manager` | moved to protected.packages; never offered |
| `unattended-upgrades` | moved to protected.packages; never offered |
| `yelp` | moved to protected.packages; never offered |
| `evolution-data-server` | moved to protected.packages; never offered |
| `gnome-software-fedora` | moved to protected.packages; never offered |
| `mintreport` | moved to protected.packages; never offered |
| `snapd-service` | disabling it breaks every snap; protected unit |
| `gnome-games-meta` | removing the metapackage alone removes no games; the engine never runs autoremove |

## Left out of the macos catalog

| Candidate | Reason |
|---|---|
| `protected-sharingd` | moved to protected.labels |
| `protected-chronod` | moved to protected.labels |
| `protected-imagent` | moved to protected.labels |
| `protected-quicklook` | moved to protected.labels |
| `protected-dhcp6d` | moved to protected.labels |
| `protected-modelmanagerd` | moved to protected.labels |
| `protected-locationd` | moved to protected.labels |
| `protected-findmydeviced` | moved to protected.labels |
| `protected-backupd` | moved to protected.labels |
| `protected-biometrickitd` | moved to protected.labels |
| `safari-search-queries-to-apple-off` | Safari reads only its sandbox container; without Full Disk Access the write silently does nothing and the engine cannot check for it |
| `safari-suppress-search-suggestions` | same as above |
| `handoff-advertising-off` | the false value is inferred, not shown by any source |
| `handoff-receiving-off` | the false value is inferred, not shown by any source |
| `setup-assistant-siri-seen` | not verified on macOS 14 or later |
| `setup-assistant-icloud-seen` | not verified on macOS 14 or later |
| `setup-assistant-privacy-seen` | not verified on macOS 14 or later |
| `setup-assistant-screen-time-seen` | not verified on macOS 14 or later |
| `time-machine-new-disk-prompt-off` | tested on Catalina only |
| `music-song-notifications-off` | tested up to Ventura only; not a promotion |

## Credits

No code was copied. Tools and references studied are listed with licences in section 7 of each
findings file: for Linux, unsnap, ubuntu-debullshit, snap-to-flatpak, linutil and the Fedora
post-install guides; for macOS, the NIST macOS
Security Compliance Project, kdeldycke/dotfiles, mathiasbynens/dotfiles, macos-defaults.com,
privacy.sexy (AGPL: read for identifiers only), drduh's guide, nix-darwin, rtrouton_scripts and
the b0gdanw gists (used as a record of what breaks).
