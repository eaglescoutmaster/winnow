# Winnow Linux research: findings

Researched 2026-11-23/24. Research only; no scripts. Every claim below carries the URL it was read on.
Anything not read on a page is under UNVERIFIED at the end. Companion data: research/raw/linux-candidates.json (90 items).

Release baseline used (verified):
- Ubuntu LTS 22.04 jammy, 24.04 noble, 26.04 resolute; interim 25.10 questing; current interim 26.10 "Stonking Stingray", released 2026-10-15.
  https://canonical.com/blog/canonical-releases-ubuntu-26-10-stonking-stingray , https://documentation.ubuntu.com/release-notes/26.10/
- Fedora current two: 44 and 45 (45 released 2026-11-03 after two slips, GNOME 51). https://fedoramagazine.org/announcing-fedora-linux-45/ , https://itsfoss.com/news/fedora-45-features/
- Linux Mint current: 22.3 "Zena" (Jan 2026, Ubuntu noble base). Next release is numbered 27 "Adrien" (Ubuntu 26.04 base, due Christmas 2026); the repo already has an "adrien" dist with "Version: 27".
  http://packages.linuxmint.com/dists/zena/Release , http://packages.linuxmint.com/dists/adrien/Release , https://itsfoss.com/news/linux-mint-27-announced/
- Debian 12 bookworm, 13 trixie.

Primary sources used repeatedly (short names used below):
- [SEED-<rel>]   Ubuntu desktop seeds: https://git.launchpad.net/~ubuntu-core-dev/ubuntu-seeds/+git/ubuntu/plain/desktop?h=<rel> and .../desktop-minimal?h=<rel>  (rel = jammy, noble, questing, resolute, stonking)
- [PLATSEED]     https://git.launchpad.net/~ubuntu-core-dev/ubuntu-seeds/+git/platform/plain/desktop-common?h=noble
- [UD-<rel>]     https://packages.ubuntu.com/<rel>/ubuntu-desktop , https://packages.ubuntu.com/noble/ubuntu-desktop-minimal
- [FILELIST]     https://packages.ubuntu.com/noble/<arch>/<pkg>/filelist
- [DEB12]/[DEB13] https://deb.debian.org/debian/dists/bookworm/main/binary-amd64/Packages.xz , .../trixie/...
- [F44]/[F45]    comps from release repodata:
                 https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/os/repodata/6a37d36914955dc65cf6dc037c37dcf00c64ded464dc34164a674bf65fa16927-comps-Everything.x86_64.xml.zst
                 https://dl.fedoraproject.org/pub/fedora/linux/releases/45/Everything/x86_64/os/repodata/33b08445a1beb3712913d91fa00042d3a60b678be68f8e68cc2587bbb6b35d06-comps-Everything.x86_64.xml.zst
- [MINT]         http://packages.linuxmint.com/dists/zena/main/binary-amd64/Packages.gz

Key structural fact (drives everything in section 3): in the Ubuntu seeds, an entry in parentheses is a Recommends of the
metapackage and a bare entry is a Depends. Verified by comparing [SEED-noble] against the Depends/Recommends lists on [UD-noble]:
e.g. "(thunderbird)" is under Recommends, "yelp" is under Depends.

------------------------------------------------------------------------------------------------------------------------
## 1. Telemetry / reporting
------------------------------------------------------------------------------------------------------------------------

### Ubuntu
- ubuntu-report: package `ubuntu-report`, Recommends of ubuntu-desktop-minimal in jammy, noble, questing, resolute; REMOVED from the 26.10 (stonking) seed. [SEED-*], [UD-noble]
  Ships user units `ubuntu-report.path`, `ubuntu-report.service` and `/etc/xdg/autostart/ubuntu-report-on-upgrade.desktop`. https://packages.ubuntu.com/noble/amd64/ubuntu-report/filelist
  Stores reports under ~/.cache/ubuntu-report/. https://discourse.ubuntu.com/t/ubuntu-insights-how-telemetry-is-changing-on-ubuntu-desktop/73442
- Ubuntu Insights: package `ubuntu-insights`, Recommends from 25.10 (questing) onward, including 26.04 and 26.10. [SEED-questing], [SEED-resolute], [UD-stonking]
  Opt-in, per-user consent; consent from ubuntu-report does not carry over. CLI: `ubuntu-insights consent -s=false` (opt out), `ubuntu-insights collect -df` (preview).
  No system-wide opt-out; Canonical suggests removing the package or restricting consent files. In 25.10 both tools are installed, fresh installs use Insights, upgraders stay on Report.
  https://discourse.ubuntu.com/t/ubuntu-insights-how-telemetry-is-changing-on-ubuntu-desktop/73442
  When consent is false the client still sends `{"OptOut": true}`. https://raw.githubusercontent.com/ubuntu/ubuntu-insights/main/README.md
  Reports monthly, held one week before sending; `ubuntu-insights revoke` also named as opt-out. https://www.omgubuntu.co.uk/2025/12/ubuntu-insights-telemetry-26-04-lts
  Repo: ubuntu/ubuntu-insights, GPL-3.0. https://api.github.com/repos/ubuntu/ubuntu-insights
  => Engine op: package removal (apt). Consent files are per-user and their paths were not found (UNVERIFIED), so no keyvalue op.
- apport: `/etc/default/apport` contains `enabled=1` upstream with the comment "set this to 0 to disable apport". https://raw.githubusercontent.com/canonical/apport/main/etc/default/apport
  Ubuntu docs: "Apport is not enabled by default in stable releases, even if it is installed"; crash files in /var/crash; popups off via
  `gsettings set com.ubuntu.update-notifier show-apport-crashes false`. https://ubuntu.com/project/docs/contributors/debugging/apport/
  Units shipped by `apport` (noble): apport-autoreport.path, apport-autoreport.service, apport-autoreport.timer, apport-coredump-hook@.service,
  apport-forward.socket, apport-forward@.service; plus /etc/cron.daily/apport. https://packages.ubuntu.com/noble/all/apport/filelist
  apport-autoreport.service runs whoopsie-upload-all; is skipped by ConditionPathExists=/var/lib/apport/autoreport; with whoopsie.path disabled it now exits 0
  (fixed noble 2.28.1-0ubuntu3.1, previously logged a failure). https://bugs.launchpad.net/apport/+bug/2069360
- whoopsie: package `whoopsie` (Recommends), units `whoopsie.service`, `whoopsie.path`. https://packages.ubuntu.com/noble/amd64/whoopsie/filelist , [UD-noble]
- kerneloops: binary package `kerneloops` (seed name "kerneloops-daemon"), Recommends in jammy and noble, absent from 26.10 ubuntu-desktop. [PLATSEED], [UD-noble], [UD-stonking]
  Submits oops signatures to oops.kernel.org; config /etc/kerneloops.conf. https://manpages.ubuntu.com/manpages/noble/en/man8/kerneloops.8.html
- popularity-contest on Ubuntu: installed-but-not-enabled claim only seen in a Launchpad comment; not in ubuntu-desktop deps. Treated as Debian item.

### GNOME (Ubuntu, Debian, Fedora)
Schema org.gnome.desktop.privacy, upstream defaults: report-technical-problems=false, send-software-usage-stats=false, remember-recent-files=true,
recent-files-max-age=-1, remember-app-usage=true, remove-old-trash-files=false, remove-old-temp-files=false, old-files-age=30, disable-camera=false,
disable-microphone=false, usb-protection=true.
https://gitlab.gnome.org/GNOME/gsettings-desktop-schemas/-/raw/master/schemas/org.gnome.desktop.privacy.gschema.xml.in
Schema org.gnome.system.location: enabled=false (default), max-accuracy-level='exact'.
https://gitlab.gnome.org/GNOME/gsettings-desktop-schemas/-/raw/master/schemas/org.gnome.system.location.gschema.xml.in
Night Light sunrise/sunset needs location. https://gitlab.gnome.org/GNOME/gnome-settings-daemon/-/issues/71
geoclue: unit `geoclue.service` (system) in package geoclue-2.0. https://packages.ubuntu.com/noble/amd64/geoclue-2.0/filelist
Use the gsettings key, not the unit (see UNVERIFIED on D-Bus activation).

### Debian
- popularity-contest: /usr/share/popularity-contest/default.conf has `PARTICIPATE="no"`, "If this option is missing, the default is no"; local override /etc/popularity-contest.conf.
  https://sources.debian.org/src/popularity-contest/1.79/default.conf
  Run weekly from /etc/cron.daily/popularity-contest. https://manpages.ubuntu.com/manpages/noble/man8/popularity-contest.8.html
  Package is Priority optional, Depends only debconf|dpkg; not required by gnome/gnome-core/task-gnome-desktop. [DEB12], [DEB13]
- reportbug: Priority standard, Depends apt, python3-reportbug. It is a user-run bug filing tool, not background telemetry; no candidate. [DEB12], [DEB13]

### Fedora
- Telemetry proposal: Changes/Telemetry (F40) "was withdrawn and has been obsoleted by a newer version". https://fedoraproject.org/wiki/Changes/Telemetry
  Changes/Metrics (opt-in, targeted F43): "DROPPED - this change was dropped by the proposing party and marked as CLOSED WONTFIX", FESCo #3242, last updated 2026-04-12.
  https://fedoraproject.org/wiki/Changes/Metrics
  Proposed packages were eos-metrics, eos-event-recorder-daemon, eos-metrics-instrumentation, azafea, azafea-metrics-proxy. https://discussion.fedoraproject.org/t/f42-change-proposal-opt-in-metrics-for-fedora-workstation-system-wide/124325
  => No Fedora telemetry daemon to disable in F44/F45.
- ABRT: F44 Workstation ships without gnome-abrt; proposal (2026-04-23) to remove all ABRT in F45; retrace server does not support F43/F44.
  https://discussion.fedoraproject.org/t/last-call-to-save-abrt/188901
  Comps evidence: F44 `abrt-cli` is default in group workstation-product; F45 has no abrt package in any Workstation group (abrt-desktop remains only in kde/mate/xfce groups). [F44], [F45]
  Units to disable where present: abrtd.service, abrt-journal-core.service, abrt-oops.service, abrt-xorg.service. https://dev.to/robbinespu/disabling-fedora-abrt-notification-1i40
- fwupd-refresh contacts the LVFS CDN for metadata "but will not send any information about the hardware without user interaction". https://fedoraproject.org/wiki/Changes/EnableFwupdRefreshByDefault (read via search result)

### Mint
- mintreport ("System Reports") gathers crash information locally. https://projects.linuxmint.com/reference/git/bugs/mintreport-crash-info.html
  It is a hard Depends of mint-meta-core (with mintupdate, mintinstall, mintdrivers, mintsystem ...). [MINT]  => never-default.

### KDE
- KUserFeedback global kill switch: /etc/xdg/KDE/UserFeedback.conf, section [UserFeedback], Enabled=false. https://mail.kde.org/pipermail/kde-community/2020q4/006655.html
  This is an INI file with a section header; the engine's keyvalue op has no section concept, so it is NOT in the candidates. Needs an "ini" op or a guarantee the file is created with the header.

------------------------------------------------------------------------------------------------------------------------
## 2. Ads / upsell
------------------------------------------------------------------------------------------------------------------------
- APT news: `pro config set apt_news=false` / `pro config show apt_news` (default True). Fetches https://motd.ubuntu.com/aptnews.json at most daily.
  Distinct from the Ubuntu Pro "available update" (ESM) messages. https://ubuntu.com/pro-client/docs//en/docs/howtoguides/disable_enable_apt_news/
  The docs give no file path for the setting, so there is no verified keyvalue equivalent. => needs a "command" op or stays out of scope.
- ESM messages in apt: produced by `apt-esm-hook` and `apt-esm-json-hook` (LTS only), configured by `20apt-esm-hook.conf`; templates built by the `update_messages` timer job.
  The docs page describes no supported off switch. https://ubuntu.com/pro-client/docs/en/latest/explanations/apt_messages/
  File content (upstream main): APT::Update::Pre-Invoke starts `apt-news.service esm-cache.service` with `systemctl start --no-block`;
  binary::apt::AptCli::Hooks::Upgrade runs /usr/lib/ubuntu-advantage/apt-esm-json-hook. https://raw.githubusercontent.com/canonical/ubuntu-pro-client/main/apt-hook/20apt-esm-hook.conf
  Because the hook uses `systemctl start`, `systemctl disable apt-news.service` does not stop it (disable only removes enablement; see systemctl man page in section 8).
  ubuntu-pro-client ships: /etc/apt/apt.conf.d/20apt-esm-hook.conf, /etc/update-motd.d/91-contract-ua-esm-status, apt-news.service, esm-cache.service,
  ua-reboot-cmds.service, ua-timer.service, ua-timer.timer, ubuntu-advantage.service. https://packages.ubuntu.com/noble/all/ubuntu-pro-client/filelist
  Community workaround = comment out the hooks in /etc/apt/apt.conf.d/20apt-esm-hook.conf (the Pro FAQ says "you can comment lines out"); it does not affect MOTD.
  Canonical: "you can only disable all or nothing of the info of 90-updates-available". https://discourse.ubuntu.com/t/remove-pro-advertising-from-apt/34051
  Persistent-ad report on 24.04.2 despite apt_news=false: LP #2110353 (status New). https://lists.snapcraft.io/archives/foundations-bugs/2025-May/538401.html
  None of this maps to package/systemd/gsettings/keyvalue => documented, not in candidates.
- ESM lines in MOTD: opt-out is a marker file `hide-esm-in-motd` (bug text says /var/lib/ubuntu-advantage/, verifiers used /var/lib/update-notifier/ : inconsistent),
  Fix Released jammy 3.192.54.8, noble 3.192.68build1. Marker file creation is not one of the four ops. https://bugs.launchpad.net/ubuntu/+source/update-notifier/+bug/2015420
- motd-news: /etc/default/motd-news "has an ENABLED=1 setting that if set to 0 will turn off this functionality". Sends Ubuntu version, kernel, arch, CPU model, uptime, cloud id.
  https://canonical.com/legal/motd
  The file lives in package `motd-news-config` (split from base-files); motd-news is disabled on desktops, enabled where ubuntu-server pulls the package.
  https://bugs.launchpad.net/ubuntu/+source/base-files/+bug/1888575
  base-files ships /etc/update-motd.d/50-motd-news, motd-news.service, motd-news.timer. https://packages.ubuntu.com/noble/amd64/base-files/filelist
  Timer still triggers the service with ENABLED=0 per reporters; maintainer: free to disable the timer. https://bugs.launchpad.net/bugs/2022825
- update-notifier-common ships /etc/update-motd.d/90-updates-available, 95-hwe-eol, update-notifier-download.timer, update-notifier-motd.timer.
  https://packages.ubuntu.com/noble/all/update-notifier-common/filelist . `update-notifier` and `update-manager` are hard Depends of ubuntu-desktop-minimal => protected. [UD-noble]
- Pro promotion history (apt "ad" Oct 2022, Software Updater listing Pro updates, banner in Software & Updates). https://www.theregister.com/2022/10/13/canonical_ubuntu_ad/ , https://www.omgubuntu.co.uk/2022/10/ubuntu-pro-terminal-ad (read via search result)
- Amazon launcher: gone since 20.04 (ubuntu-web-launchers dependency dropped; 18.04.4 package emptied, LP #1860565). Not present on any target release.
  https://www.omgubuntu.co.uk/2020/01/ubuntu-removes-the-amazon-web-app , https://bugs.launchpad.net/bugs/1860565 (read via search result)
- Firefox/Thunderbird snap redirection: the `thunderbird` deb in 24.04 "is a transition package" (like Firefox and Chromium); installing it "installs the Thunderbird snap
  (and reinstalls snapd, if that has been removed)"; with unattended upgrades "the Thunderbird snap may magically reappear"; workaround pins
  /etc/apt/preferences.d/mozillateamppa with Pin-Priority 1001 / -1. https://www.omgubuntu.co.uk/2024/08/install-thunderbird-deb-not-snap-in-ubuntu-24-04
- Snap Store / App Center promotions: nothing verified (UNVERIFIED).

------------------------------------------------------------------------------------------------------------------------
## 3. Preinstalled apps per distro
------------------------------------------------------------------------------------------------------------------------

### Ubuntu (seeds + metapackage pages)
Full-desktop Recommends (safe to remove without losing ubuntu-desktop):
- jammy: thunderbird, thunderbird-gnome-support, transmission-gtk, gnome-todo, baobab, rhythmbox, cheese, totem, simple-scan, remmina, shotwell, usb-creator-gtk, deja-dup,
  gnome-calendar, aisleriot, gnome-mahjongg, gnome-mines, gnome-sudoku, branding-ubuntu, libreoffice-{style-breeze,gnome,writer,calc,impress,math,ogltrans,pdfimport}. [SEED-jammy], [UD-jammy]
- noble and questing (identical desktop seed): snap:thunderbird + transitional thunderbird deb, transmission-gtk, rhythmbox, gnome-snapshot, totem, simple-scan, remmina, shotwell,
  usb-creator-gtk, deja-dup, file-roller, gnome-calendar, libreoffice-{style-yaru,gnome,writer,calc,impress,math}. Games and cheese are gone. [SEED-noble], [SEED-questing], [UD-noble]
- resolute and stonking: same but totem -> showtime. [SEED-resolute], [UD-stonking]
Minimal-desktop Recommends (noble): gnome-clocks, gnome-characters, gnome-logs, gnome-font-viewer, baobab, eog, evince, gnome-calculator, gnome-disk-utility, gnome-system-monitor,
gnome-text-editor, gnome-terminal, gnome-power-manager, seahorse, firefox (deb), ubuntu-report, whoopsie, apport-gtk, snapd, packagekit, fwupd, cups*, avahi-daemon, bluez,
speech-dispatcher, orca, network-manager, gnome-initial-setup, gnome-remote-desktop, cloud-init ... [SEED-noble], [PLATSEED], [UD-noble]
Minimal-desktop hard Depends (removing any of these removes ubuntu-desktop-minimal AND ubuntu-desktop): gdm3, gnome-shell, gnome-control-center, gnome-settings-daemon, gnome-menus,
nautilus, yelp, zenity, update-manager, update-notifier, ubuntu-release-upgrader-gtk, software-properties-gtk (26.x: software-properties-common), language-selector-gnome,
ubuntu-session, ubuntu-settings, pipewire-pulse, wireplumber, xdg-user-dirs(-gtk), gstreamer1.0-packagekit, at-spi2-core, libatk-adaptor, alsa-base, alsa-utils, anacron,
ca-certificates, wpasupplicant, ubuntu-drivers-common, xorg (not in 26.10), ghostscript, foomatic-db-compressed-ppds, openprinting-ppds, printer-driver-pnm2ppa,
gnome-shell-extension-* (26.x: gnome-shell-ubuntu-extensions), libnotify-bin, unzip, zip, bc ... [UD-noble], [UD-stonking]
Seeded snaps: jammy firefox, gnome-42-2204, gtk-common-themes, snap-store, snapd-desktop-integration (+gnome-46-2404, mesa-2404);
noble + firmware-updater; questing/resolute + prompting-client, desktop-security-center; resolute + hwctl (amd64). [SEED-*]
gnome-tour is not in any Ubuntu desktop seed read. [SEED-*]

Is losing the metapackage harmful?
- apt marks the remaining dependencies manual when a metapackage is removed as a consequence of removing one of its deps, so they are not autoremoved
  (Kalnischkies: "apt will mark the packages as manual if the metapackage is removed as a consequence of another package"; explicit removal of the metapackage does NOT do this).
  https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1583591
- Upgrade impact: ubuntu-release-upgrader marks installed MetaPkgs for upgrade and, if none is installed, tries to guess one from KeyDependencies; if it cannot it errors
  "Can't guess meta-package ... Please install one of the packages above first". MetaPkgs list: ubuntu-desktop, kubuntu-desktop, xubuntu-*, lubuntu-desktop, ...;
  [ubuntu-desktop] KeyDependencies=lightdm, unity, ubuntu-artwork, ubuntu-sounds. BaseMetaPkgs ubuntu-minimal, ubuntu-standard are always (re)installed.
  https://git.launchpad.net/ubuntu-release-upgrader/plain/DistUpgrade/DistUpgradeCache.py , https://git.launchpad.net/ubuntu-release-upgrader/plain/data/DistUpgrade.cfg
  The upgrader's own removal denylist: ubuntu-standard, ubuntu-minimal, ubuntu-desktop, update-manager, update-manager-core, ubuntu-release-upgrader-core, openssh-server,
  screen, cryptsetup-initramfs, postgresql-*. https://git.launchpad.net/ubuntu-release-upgrader/plain/data/removal_denylist.cfg
  => Policy: the engine must REFUSE any apt removal whose simulation removes ubuntu-desktop or ubuntu-desktop-minimal. Recommends-only removals do not.
- Real report of the metapackage being lost at dist-upgrade and the desktop going with it: LP #2025462, fixed by `apt install ubuntu-desktop-minimal`. https://bugs.launchpad.net/ubuntu/+source/apt/+bug/2025462 (read via search result)
Do upgrades reinstall removed apps?
- Seeded snaps: yes when snapd is installed. The seed says desktop snaps "also exist in ubuntu-release-upgrader's DistUpgradeQuirks.py for users who upgrade";
  the quirk runs _replaceDebsAndSnaps when snapd is installed. [SEED-noble], https://git.launchpad.net/ubuntu-release-upgrader/plain/DistUpgrade/DistUpgradeQuirks.py
- 22.04 -> 24.04 transitions firefox and thunderbird debs to snaps and can fail on the thunderbird snap. https://lists.ubuntu.com/archives/ubuntu-mozillateam-bugs/2025-September/181792.html (read via search result)
- Removed Recommends debs after upgrade: not verified => "unknown" in the JSON.

### Debian (Packages index)
- task-gnome-desktop: Depends tasksel, task-desktop, gnome-core; Recommends gnome (+ libreoffice/synaptic on 12). [DEB12], [DEB13]
- gnome-core hard Depends, Debian 12: baobab, eog, evince, evolution-data-server, gdm3, gnome-calculator, gnome-characters, gnome-contacts, gnome-control-center,
  gnome-disk-utility, gnome-font-viewer, gnome-keyring, gnome-logs, gnome-online-accounts, gnome-shell, gnome-shell-extensions, gnome-software, gnome-sushi,
  gnome-system-monitor, gnome-text-editor, gnome-user-docs, gnome-user-share, nautilus, totem, tracker, yelp, zenity ... [DEB12]
- gnome-core hard Depends, Debian 13 (much larger app set): adds gnome-calendar, gnome-clocks, gnome-connections, gnome-maps, gnome-weather, loupe, simple-scan, gnome-snapshot,
  orca, cups, "totem | showtime", "evince | papers"; Recommends gnome-tour, gnome-remote-desktop, gnome-user-share, rygel-*, network-manager. [DEB13]
  => On Debian 13 maps/weather/contacts/clocks/calendar/simple-scan/cups cannot be removed without removing gnome-core. gnome-tour is only a Recommends (removable).
- gnome (the larger metapackage), Debian 12 Depends: cheese, file-roller, gnome-calendar, gnome-clocks, gnome-maps, gnome-music, "shotwell | gnome-photos", gnome-weather,
  simple-scan, evolution, libreoffice-{gnome,writer,calc,impress}, rhythmbox, seahorse, avahi-daemon, ...; Recommends gnome-games, transmission-gtk, gnome-initial-setup. [DEB12]
  Debian 13 Depends: evolution, file-roller, gnome-sound-recorder, gnome-tweaks, libreoffice-{calc,impress,gnome,gtk3,writer}, seahorse, shotwell, avahi-daemon, network-manager;
  Recommends gnome-music, totem-plugins. [DEB13]
  Removing a Depends of `gnome` removes only that metapackage (gnome-core and the desktop stay; deps get marked manual per the apt rule above).
- gnome-games metapackage Depends: aisleriot, five-or-more, four-in-a-row, gnome-2048, gnome-chess, gnome-klotski, gnome-mahjongg, gnome-mines, gnome-nibbles, gnome-robots,
  gnome-sudoku, gnome-taquin, gnome-tetravex, hitori, iagno, lightsoff, quadrapassel, swell-foop, tali. Only pulled by default on Debian 12. [DEB12], [DEB13]
- task-desktop Recommends: avahi-daemon, libnss-mdns, anacron, cups, sudo, firefox | firefox-esr ... [DEB13]

### Fedora Workstation 44/45 (comps)
- Environment workstation-product-environment groups: base-graphical, container-management, core, desktop-accessibility, firefox, fonts, gnome-desktop, guest-desktop-agents,
  hardware-support, libreoffice, multimedia, networkmanager-submodules, printing, workstation-product. [F45]
- gnome-desktop MANDATORY: dconf, gdm, gnome-control-center, gnome-initial-setup, gnome-session-wayland-session, gnome-settings-daemon, gnome-shell, gnome-software,
  gnome-text-editor, nautilus, polkit, ptyxis, yelp. [F45]
- gnome-desktop DEFAULT (removable apps): baobab, decibels, gnome-boxes, gnome-calculator, gnome-calendar, gnome-characters, gnome-clocks, gnome-connections, gnome-contacts,
  gnome-disk-utility, gnome-font-viewer, gnome-logs, gnome-maps, gnome-system-monitor, gnome-weather, loupe, papers, showtime, simple-scan, snapshot, sushi, rygel,
  gnome-user-share, gnome-remote-desktop, gnome-classic-session, localsearch, tinysparql, ModemManager, avahi, ... [F45]
  gnome-tour, rhythmbox, cheese, totem are NOT in the Workstation groups in F44/F45. [F44], [F45]
- libreoffice group mandatory: libreoffice-calc, -emailmerge, -graphicfilter, -impress, -writer. firefox group mandatory: firefox, fedora-bookmarks. [F45]
- printing group: mandatory cups, cups-filters, ghostscript; default cups-browsed, hplip, gutenprint, system-config-printer-udev, ... [F45]
- workstation-product mandatory: dnf5, sudo, systemd-udev, linux-firmware, *-firmware, tar; default includes mediawriter, fedora-flathub-remote, gamemode, toolbox, thermald. [F45]
- F44 -> F45 differences in these groups: abrt-cli dropped; gvfs-afp, gvfs-archive, NetworkManager-vpnc-gnome dropped; NetworkManager-libreswan-gnome added. [F44], [F45]
- dnf protection: protected_packages default `dnf5,glob:/etc/dnf/protected.d/*.conf`; protect_running_kernel=True. https://dnf5.readthedocs.io/en/latest/dnf5.conf.5.html
  /etc/dnf/protected.d/fedora-workstation.conf contains `NetworkManager` and `gnome-shell`; error text
  "The operation would result in removing the following protected packages: gnome-shell". https://bugzilla.redhat.com/show_bug.cgi?id=2400488
- Comps "mandatory" is a group-install concept; it does not by itself block `dnf remove`. Only protected_packages and RPM dependencies do. Upgrade/return behaviour not verified.

### Linux Mint 22.3
- mint-meta-cinnamon Depends: mint-meta-core, cinnamon, nemo, nemo-fileroller, cinnamon-control-center, cinnamon-screensaver, bulky, folder-color-switcher, xdg-desktop-portal-xapp.
- mint-meta-core Depends: linuxmint-keyring, mint-info, mint-artwork, mintsystem, ubuntu-system-adjustments, mintbackup, mintinstall, mintupdate, mintwelcome, mintsources,
  mintdrivers, mintreport, mintstick, mintsysadm; Recommends thingy. [MINT]
- The default application list (thunderbird, libreoffice, hypnotix, celluloid, ...) could not be verified: Mint publishes no manifest and the metapackages do not list apps. UNVERIFIED.

------------------------------------------------------------------------------------------------------------------------
## 4. Snap itself (never-default)
------------------------------------------------------------------------------------------------------------------------
- snapd is a Recommends of ubuntu-desktop-minimal ("(snapd)" in desktop-common), so apt lets it go without removing the metapackage. [PLATSEED], [UD-noble]
- What goes with it: every seeded snap: firefox, thunderbird (24.04+), snap-store/App Center, firmware-updater (24.04+), desktop-security-center + prompting-client (25.10+),
  hwctl (26.04), gnome-*/mesa-*/gtk-common-themes runtimes, snapd-desktop-integration. [SEED-*]
- Units (noble): snapd.service, snapd.socket, snapd.seeded.service, snapd.apparmor.service, snapd.autoimport.service, snapd.core-fixup.service, snapd.failure.service,
  snapd.snap-repair.service/.timer, snapd.system-shutdown.service, snapd.recovery-chooser-trigger.service; user snapd.session-agent.service/.socket;
  /etc/apt/apt.conf.d/20snapd.conf. https://packages.ubuntu.com/noble/amd64/snapd/filelist
- It comes back: transitional debs (thunderbird; firefox/chromium per the same article) reinstall snapd, including via unattended upgrades.
  https://www.omgubuntu.co.uk/2024/08/install-thunderbird-deb-not-snap-in-ubuntu-24-04
- Purge failure on fresh 24.04: `apt autopurge snapd` failed in postrm with read-only errors under /var/snap/firefox/common/host-hunspell; fixed in Firefox snap 129,
  snapd task still "Confirmed". https://bugs.launchpad.net/ubuntu/+source/snapd/+bug/2058810
- do-release-upgrade: if snapd is installed and its socket exists, the upgrader checks Snap Store connectivity and warns the "release upgrade will fail if snapd is not functional";
  after upgrade it replaces debs with snaps. If snapd is not installed those quirk steps are skipped. https://git.launchpad.net/ubuntu-release-upgrader/plain/DistUpgrade/DistUpgradeQuirks.py
- Pinning: Mint ships /etc/apt/preferences.d/nosnap.pref to forbid snapd via APT (documented for Mint 20; re-enable by deleting the file). File contents not shown on the page.
  https://linuxmint-user-guide.readthedocs.io/en/latest/snap.html
  Community Ubuntu guides use an equivalent pin with Pin-Priority: -1 (linuxblog.io, ubuntuhandbook.org; read via search results). Writing a pin file is not one of the four ops.
- snap data safety: `snap remove` saves an automatic snapshot of the snap's data unless `--purge`; `snap saved` / `snap restore` / `snap forget`. https://manpages.ubuntu.com/manpages/noble/en/man8/snap.8.html
  => The engine's snap revert can be reinstall + `snap restore`; never pass --purge.

------------------------------------------------------------------------------------------------------------------------
## 5. Background services
------------------------------------------------------------------------------------------------------------------------
Unit names verified on Ubuntu 24.04 file lists unless stated. `systemctl disable` "does not implicitly stop the units"; only `mask` "prohibits all kinds of activation".
https://www.freedesktop.org/software/systemd/man/latest/systemctl.html  => for socket/D-Bus/path-activated units a plain disable is often not enough.

| Unit / package | Scope | What breaks | Tier | Source |
| avahi-daemon.service + avahi-daemon.socket | system | mDNS/DNS-SD: nss-mdns name resolution, service discovery for D-Bus apps | moderate | https://packages.ubuntu.com/noble/amd64/avahi-daemon/filelist , https://manpages.ubuntu.com/manpages/noble/en/man8/avahi-daemon.8.html |
| ModemManager.service | system | mobile broadband modems | moderate | https://packages.ubuntu.com/noble/amd64/modemmanager/filelist , https://manpages.ubuntu.com/manpages/noble/en/man8/ModemManager.8.html |
| bluetooth.service (bluez) | system | all Bluetooth | aggressive | https://packages.ubuntu.com/noble/amd64/bluez/filelist |
| fwupd-refresh.timer | system | periodic firmware metadata refresh + MOTD notice | moderate | https://packages.ubuntu.com/noble/amd64/fwupd/filelist , https://manpages.ubuntu.com/manpages/noble/man8/fwupd-refresh.service.8.html |
| fwupd.service | system | firmware updates (on-demand unit) | not offered | same |
| packagekit.service | system | software centre / gstreamer codec install; reports say disable fails or the unit is static and gnome-software re-activates it; masking gives "Unit packagekit.service is masked" errors | not offered (needs mask) | https://packages.ubuntu.com/noble/amd64/packagekit/filelist , https://medium.com/opsops/how-to-disable-packagekit-f935207044c1 (via search) |
| speech-dispatcherd.service (system); speech-dispatcher.service/.socket (user) | both | screen reader speech (orca) | not offered (accessibility) | https://packages.ubuntu.com/noble/amd64/speech-dispatcher/filelist |
| whoopsie.service, whoopsie.path, apport-autoreport.path/.timer | system | crash report upload | safe | section 1 |
| motd-news.timer | system | MOTD news fetch | safe | section 2 |
| localsearch-3.service (localsearch >= 3.8) | user | file indexing / search; also D-Bus + XDG autostart activated | moderate | https://gitlab.gnome.org/GNOME/localsearch/-/raw/main/src/indexer/meson.build , https://gitlab.gnome.org/GNOME/localsearch/-/raw/main/NEWS |
| tracker-miner-fs-3.service, tracker-miner-fs-control-3.service (tracker-miners <= 3.7) | user | same | moderate | https://packages.ubuntu.com/noble/amd64/tracker-miner-fs/filelist , https://gitlab.gnome.org/GNOME/localsearch/-/raw/3.7.3/src/miners/fs/meson.build |
| evolution-source-registry.service, evolution-calendar-factory.service, evolution-addressbook-factory.service, evolution-user-prompter.service | user | GNOME calendar/contacts/online accounts integration | not offered; package is protected | https://packages.ubuntu.com/noble/amd64/evolution-data-server/filelist |
| geoclue.service | system | location (use gsettings instead) | not offered | https://packages.ubuntu.com/noble/amd64/geoclue-2.0/filelist |
| snapd.service / snapd.socket | system | all snaps | never-default | section 4 |
| unattended-upgrades.service | system | automatic security updates | never-default | https://packages.ubuntu.com/noble/all/unattended-upgrades/filelist |
| cups / cups-browsed | system | printing / network printer auto-detect. Ubuntu blog: removing cups-browsed "would affect the ability to detect network printers"; configured printers keep working | cups aggressive; cups-browsed moderate | https://ubuntu.com/blog/cups-remote-code-execution-vulnerability-fix-available |

Rename: project renamed tracker-miners -> LocalSearch in 3.8.alpha (2024-07-04); the D-Bus service file sets SystemdService=localsearch-3.service (3.8+) vs tracker-miner-fs-3.service (3.7).
Fedora 44/45 ship `localsearch` and `tinysparql` in gnome-desktop defaults. [F45]

------------------------------------------------------------------------------------------------------------------------
## 6. Must-never-touch (with breakage reports)
------------------------------------------------------------------------------------------------------------------------
- python3 (and python3-minimal, python3-apt): gnome-shell Depends on python3 on noble (https://packages.ubuntu.com/noble/gnome-shell). A 24.04 user who replaced the system
  Python got `ModuleNotFoundError: No module named 'apt_pkg'` on apt update; advice was reinstall the OS; ubuntu-minimal depends on python3.
  https://discourse.ubuntu.com/t/ubuntu-desktop-24-04-lts-system-issue-after-remove-default-python/71901
- gnome-shell and its hard deps, gdm3/gdm, gnome-session, gnome-settings-daemon, gnome-control-center, nautilus, mutter libs, evolution-data-server (Debian gnome-core Depends). [UD-noble], [DEB13], [F45]
  Fedora protects gnome-shell and NetworkManager via protected.d (bug above). A Fedora 41 user removing GNOME groups/apps ended with `dnf` "not found" and reinstalled.
  https://discussion.fedoraproject.org/t/uninstalling-gnome-software-uninstalled-dnf/144477
- Pop!_OS / Linus Tech Tips (Nov 2021): installing Steam with a broken i386 dependency made apt propose removing Pop!_OS desktop packages; he typed "Yes, do as I say!".
  System76 patched apt to hide that prompt. https://www.gamingonlinux.com/2021/11/system76-patches-apt-for-pop-os-to-prevent-users-breaking-their-systems
  APT 2.3.12 then stopped its solver from removing essential or protected packages. https://www.gamingonlinux.com/2021/11/apt-2312-package-manager-released-will-no-longer-let-you-break-everything/
  Lesson for the engine: an install or remove can remove unrelated packages; always simulate and diff.
- network-manager / NetworkManager: LP #407302 "No more network after removing network-manager"; users unable to reinstall without connectivity.
  https://launchpad.net/bugs/407302 , https://answers.launchpad.net/ubuntu/+source/network-manager/+question/703821 (read via search result)
- unattended-upgrades: installed and enabled by default, applies security updates daily; supported off-switch is APT::Periodic in /etc/apt/apt.conf.d/20auto-upgrades.
  https://ubuntu.com/server/docs/how-to/software/automatic-updates/
- snapd: section 4 (purge failures, upgrader quirks, transitional debs).
- ubuntu-desktop / ubuntu-desktop-minimal / ubuntu-minimal / ubuntu-standard and any Depends of them (yelp, update-manager, update-notifier, ubuntu-release-upgrader-gtk,
  software-properties-gtk, zenity ...): upgrader denylist + "Can't guess meta-package" path (section 3).
- Mint: mint-meta-core, mint-meta-<edition> and their Depends (mintreport, mintupdate, mintinstall, mintsources, mintdrivers, mintsystem, mintbackup, mintwelcome, mintstick, mintsysadm). [MINT]

------------------------------------------------------------------------------------------------------------------------
## 7. Existing Linux debloat tools
------------------------------------------------------------------------------------------------------------------------
| Tool | URL | License | What it does | Revert | Notes / breakage |
| unsnap (popey) | https://github.com/popey/unsnap | MIT | Generates scripts 00-backup (snap save), 01-install-flatpak, 02-enable-flathub, 03-install-flatpaks, 04-remove-snaps, 99-remove-snapd; has a check mode | none (only snap save backups) | Self-described "Pre-alpha ... kinda works on my computer"; repo archived (last push 2024-05) |
| ubuntu-debullshit (polhdez, ex polkaulfield) | https://github.com/polhdez/ubuntu-debullshit | Unlicense | Removes snaps completely, installs vanilla GNOME session, Flathub, Firefox from Mozilla repo, disables data reporting and crash popup, "removes terminal ads"; tested 22.04-25.04; run as `sudo bash -c "$(wget ...)"` | none documented | Only open issue is a thank-you (#17); curl-pipe-root install pattern |
| snap-to-flatpak (MasterGeekMX) | https://github.com/MasterGeekMX/snap-to-flatpak | GPL-3.0 | Removes Snap, installs Flatpak, optionally a store | none documented | last push 2024-01 |
| linutil (Chris Titus Tech) | https://github.com/ChrisTitusTech/linutil | MIT | Rust TUI "distro-agnostic toolbox"; `curl -fsSL https://christitus.com/linux | sh`; config supports auto_execute, skip_confirmation | none mentioned | "still in active development, you may encounter some issues"; no specific breakage report found |
| ufit (koulaxizis) | https://github.com/koulaxizis/ufit | none stated | "Dead-simple script to clean up Ubuntu-based distros" | unknown | last push 2020 |
| Fedora-45-Post-Install-Guide (devangshekhawat) | https://github.com/devangshekhawat/Fedora-45-Post-Install-Guide | none stated | Post-install guide (not an engine) | n/a | 2.8k stars, pushed 2026-11 |
| Fedora-Noble-Setup (wz790) | https://github.com/wz790/Fedora-Noble-Setup | GPL-3.0 | Post-install setup guide | n/a | |
| mikehorn-git/ubuntu-debloat | (404 at research time) | MIT per index | Ubuntu 22 minimal debloat | unknown | repo no longer resolves |
(Metadata from https://api.github.com/repos/<owner>/<repo> and each README.)
Gap Winnow fills: none of these record prior state or offer a revert; none simulate and refuse on collateral removals. No code was copied.

------------------------------------------------------------------------------------------------------------------------
## 8. Agent / automation concerns
------------------------------------------------------------------------------------------------------------------------
apt (https://manpages.ubuntu.com/manpages/noble/en/man8/apt-get.8.html):
- `-s/--simulate/--just-print/--dry-run/--recon/--no-act`: "No action; perform a simulation of events that would occur based on the current system state but do not actually change the system."
  Output lines: one per dpkg operation: "configure (Conf), remove (Remv) or unpack (Inst)". Square brackets indicate broken packages. Simulation disables locking (no root needed in practice: see UNVERIFIED).
- `-y/--assume-yes`: non-interactive; "If an undesirable situation, such as changing a held package, trying to install an unauthenticated package or removing an essential package occurs then apt-get will abort."
- `--assume-no`: "Automatic no to all prompts". `--no-remove`: "If any packages are to be removed apt-get immediately aborts without prompting."
- `--allow-remove-essential`: "dangerous option". NEVER pass. `-qq` implies -y: never use without -s.
- `--purge`: purge instead of remove (config files lost => breaks faithful revert; use plain remove). `--auto-remove`: acts like autoremove after remove: never pass.
- DEBIAN_FRONTEND=noninteractive: "the anti-frontend. It never interacts with you at all, and makes the default answers be used for all questions". https://manpages.ubuntu.com/manpages/noble/en/man7/debconf.7.html
Preview-and-refuse algorithm (design, built on the documented output):
  1. `apt-get -s remove <pkg>`; collect every `Remv <name>` line.
  2. Refuse if the set contains anything except <pkg> itself unless each extra name is on an explicit per-item allowlist (e.g. the Debian `gnome`/`gnome-games` metapackage).
  3. Always refuse if the set intersects the protected list (below) or any package with Essential: yes / Priority: required (fields exist in the Packages index, [DEB13]).
  4. Apply with `DEBIAN_FRONTEND=noninteractive apt-get -y --no-auto-remove remove <pkg>` (see UNVERIFIED for the exact --no-auto-remove spelling) and never run autoremove.
apt-mark (https://manpages.ubuntu.com/manpages/noble/en/man8/apt-mark.8.html): auto / manual / showauto / showmanual / hold / unhold / minimize-manual.
  Hazards: Ubuntu's own docs warn that `apt-mark minimize-manual` + `apt autoremove` "could ... lead to unexpected loss of functionality" and "the system may become unusable";
  "always evaluate what packages are automatically-removed". https://documentation.ubuntu.com/security/common-mistakes/unnecessary-packages/
  Explicitly removing a metapackage leaves its deps auto-marked (autoremove would then take the desktop); removing it as a side effect marks them manual. https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1583591
  Log `apt-mark showauto`/`showmanual` state for each removed package so revert can restore the auto/manual bit after reinstall.
dnf5:
- `--assumeno` "Automatically answer no for all questions" (prints the transaction, changes nothing) ; `-y/--assumeyes`; `--setopt=`. https://dnf5.readthedocs.io/en/latest/dnf5.8.html
- `remove --no-autoremove` "Disable removal of dependencies that are no longer used"; `--store=PATH` stores the transaction instead of running it (replayable); `--offline`. https://dnf5.readthedocs.io/en/latest/commands/remove.8.html
- conf: clean_requirements_on_remove=True by default (removes unused deps: main collateral hazard); tsflags=test "provides a transaction check without performing the transaction";
  protected_packages; protect_running_kernel=True. https://dnf5.readthedocs.io/en/latest/dnf5.conf.5.html
  => Fedora apply: `dnf5 -y remove --no-autoremove <pkg>`; preview: `dnf5 remove --no-autoremove --assumeno <pkg>` and refuse on any extra removed package.
snap: `snap remove <name>` (auto snapshot; no --purge), `--no-wait` prints change id. https://manpages.ubuntu.com/manpages/noble/en/man8/snap.8.html
flatpak: `flatpak uninstall --noninteractive -y <ref>`; do NOT pass --delete-data or --unused; --system / --user select the installation. https://docs.flatpak.org/en/latest/flatpak-command-reference.html
systemd: `is-enabled` states to record as prior state: enabled, enabled-runtime, linked, linked-runtime, alias, masked, masked-runtime, static, indirect, disabled, generated, transient, not-found.
  `disable` does not stop; `--now` stops too; `--user` talks to the calling user's manager; `--global` changes config for all users. Units with no install info are ignored by preset.
  https://www.freedesktop.org/software/systemd/man/latest/systemctl.html
  Engine rule: if prior state is static/indirect/generated/masked/not-found, report "no-op / not applicable" rather than pretending success.
Restore points:
- Timeshift (linuxmint/timeshift): `timeshift --list`, `timeshift --create --comments "..." --tags D`, `--scripted` "Run in non-interactive mode", `--yes`, `--btrfs` / `--rsync`,
  `--snapshot-device`. https://manpages.ubuntu.com/manpages/noble/en/man1/timeshift.1.html
  BTRFS mode only supports Ubuntu-type layouts with @ and @home subvolumes; "Fedora is not fully supported". https://raw.githubusercontent.com/linuxmint/timeshift/master/README.md
  mintbackup/timeshift context: Mint depends on mintbackup, not timeshift, in mint-meta-core. [MINT]
- Snapper (openSUSE/snapper, GPL-2.0): `snapper list-configs`, `snapper -c root create --type single|pre|post --description ... --print-number`, `create --command`,
  `undochange`, `rollback` (btrfs only), `--jsonout`. https://manpages.ubuntu.com/manpages/noble/en/man8/snapper.8.html
- Detection order suggestion: `command -v timeshift` -> `timeshift --list` succeeds; else `snapper list-configs` non-empty; else no restore point (state this in the plan, do not block).
Privilege:
- `sudo -n`: "Avoid prompting the user for input of any kind. If a password is required for the command to run, sudo will display an error message and exit."
  `sudo -v` refreshes cached credentials; `-l` lists privileges; `-S` reads password from stdin; `-A` askpass helper. https://www.sudo.ws/docs/man/sudo.man/
  => Agent pattern: probe with `sudo -n true`; on failure stop and ask the human to run `sudo -v` in the same terminal; never handle the password.
- pkexec: uses the session's polkit agent, falls back to a textual agent unless --disable-internal-agent; exit 126 = dialog dismissed, 127 = not authorized; minimal environment,
  DISPLAY/XAUTHORITY unset. https://manpages.ubuntu.com/manpages/noble/en/man1/pkexec.1.html
- gsettings and `systemctl --user` ops must run as the target desktop user, not root (per-user dconf / user manager): see UNVERIFIED for the exact environment needed.

------------------------------------------------------------------------------------------------------------------------
## Protected identifiers
------------------------------------------------------------------------------------------------------------------------
Packages (apt, Ubuntu/Debian/Mint): ubuntu-desktop, ubuntu-desktop-minimal, ubuntu-minimal, ubuntu-standard, ubuntu-session, ubuntu-settings, ubuntu-drivers-common,
ubuntu-release-upgrader-core, ubuntu-release-upgrader-gtk, update-manager, update-manager-core, update-notifier, software-properties-gtk, software-properties-common,
language-selector-common, language-selector-gnome, gnome-shell, gnome-shell-common, gnome-session, gnome-settings-daemon, gnome-control-center, gnome-menus, gdm3, nautilus,
yelp, zenity, xorg, pipewire-pulse, wireplumber, at-spi2-core, libatk-adaptor, ca-certificates, wpasupplicant, network-manager, python3, python3-minimal, python3-apt,
apt, dpkg, sudo, polkitd/policykit-1 (name per release), systemd, libc6, snapd, unattended-upgrades, ufw, apparmor, evolution-data-server, gnome-core, gnome (metapackage,
unless per-item allowlisted), task-gnome-desktop, task-desktop, tasksel, openssh-server, cryptsetup-initramfs, linux-image-*, grub-*, shim-signed, initramfs-tools, dracut,
mint-meta-core, mint-meta-cinnamon, mint-meta-mate, mint-meta-xfce, mintreport, mintupdate, mintinstall, mintsources, mintdrivers, mintsystem, mintbackup, mintwelcome,
mintstick, mintsysadm, cinnamon, nemo, lightdm.
Debian 13 additionally (gnome-core Depends): gnome-calendar, gnome-clocks, gnome-maps, gnome-weather, gnome-contacts, gnome-connections, simple-scan, gnome-snapshot, loupe,
cups, orca, gnome-software, gnome-characters, gnome-logs, gnome-font-viewer, baobab, gnome-calculator, gnome-disk-utility, gnome-system-monitor, gnome-text-editor.
Packages (dnf, Fedora): gnome-shell, NetworkManager (both in protected.d), dnf5, sudo, systemd, systemd-udev, polkit, gdm, gnome-session-wayland-session, gnome-settings-daemon,
gnome-control-center, gnome-initial-setup, gnome-software, gnome-text-editor, nautilus, ptyxis, yelp, dconf, firewalld, kernel*, grub2*, shim*, glibc, linux-firmware,
fedora-release-workstation, cups, firefox (group-mandatory; offer only as never-default).
Snaps: snapd, core*/bare, gnome-*-*, mesa-*, gtk-common-themes, snapd-desktop-integration.
Units: snapd.service, snapd.socket, snapd.seeded.service, snapd.apparmor.service, unattended-upgrades.service, NetworkManager.service, systemd-*, gdm.service/gdm3.service,
polkit.service, dbus*.service, ufw.service, firewalld.service, apparmor.service, packagekit.service, fwupd.service, evolution-*.service (user), update-notifier-*.timer,
ua-timer.timer, esm-cache.service, apt-news.service (ineffective to disable), speech-dispatcher* (accessibility).
(Names without a URL beside them in sections 1-6 are category-required by the brief, e.g. kernel/bootloader/libc; their exact per-release package names are UNVERIFIED.)

------------------------------------------------------------------------------------------------------------------------
## Conflicts found
------------------------------------------------------------------------------------------------------------------------
1. Apport default: upstream /etc/default/apport ships enabled=1, Ubuntu docs say Apport is not enabled by default in stable releases. Record prior value; do not assume.
2. ubuntu-insights opt-out command: Canonical Discourse says `consent -s=false`; OMG Ubuntu says `ubuntu-insights revoke`; a third guide says `sudo ubuntu-insights disable` (search result only).
3. hide-esm-in-motd marker path: /var/lib/ubuntu-advantage/ (bug description) vs /var/lib/update-notifier/ (verification comments). LP #2015420.
4. motd-news: Canonical legal page says ENABLED=0 turns it off; LP #2022825 reporters say the timer still fires the service; maintainer could not reproduce.
5. ABRT in Fedora 45: comps show no abrt in Workstation groups, but abrt packages are still built for F45 and the removal thread ends as a proposal, not a decision.
6. Seed name vs binary name: seed "kerneloops-daemon" vs package `kerneloops`; seed "(firefox)" deb is transitional while the app is snap:firefox.
7. Same package, different safety per distro: simple-scan / gnome-clocks / gnome-calendar / cups are removable Recommends on Ubuntu but hard Depends of gnome-core on Debian 13;
   totem is a hard Depends of gnome-core on Debian 12. The catalog must be keyed by distro+release, not just package name.
8. Brief vs findings: `disable` is insufficient for D-Bus/socket/XDG-autostart-activated units (localsearch, packagekit, evolution, geoclue, apt-news). A `mask` op (revert = unmask)
   would be needed for them to be effective.
9. Brief assumed gnome-tour is default bloat: it is not in Ubuntu seeds nor Fedora 44/45 Workstation comps; only a Recommends of Debian 13 gnome-core.

------------------------------------------------------------------------------------------------------------------------
## UNVERIFIED (not read on a page, or read only as a search-result summary)
------------------------------------------------------------------------------------------------------------------------
- Unit names on Debian, Fedora and Mint for avahi/ModemManager/bluetooth/fwupd/whoopsie: only Ubuntu noble file lists were read (Debian package site and Fedora src/docs were
  behind bot challenges). JSON restricts those systemd items to Ubuntu.
- Unit names on Ubuntu 22.04 / 25.10 / 26.04 / 26.10 (only noble file lists read).
- cups.service, cups-browsed.service, kerneloops.service unit names (file list pages returned empty); cups-browsed default-install status on Ubuntu.
- Contents of /etc/default/motd-news package file list (page returned no matching lines) and whether the file exists on desktop installs.
- ubuntu-insights systemd unit/timer names and per-user consent file paths.
- Whether ubuntu-pro-client / ubuntu-advantage-tools can be removed without removing ubuntu-minimal (page fetch failed); where `pro config set apt_news` is stored.
- Whether a system with only ubuntu-desktop-minimal installed passes the upgrader's metapackage check (code read, behaviour not tested).
- Whether removed Recommends packages return after do-release-upgrade, dnf system-upgrade or Mint upgrades ("unknown" in JSON).
- Linux Mint 22.3 default application set; nosnap.pref contents and its presence on Mint 22.x (only the Mint 20 doc was read).
- Pop!_OS and Arch-based specifics beyond the 2021 apt incident; nothing else was read.
- Snap Store / App Center promoted-content behaviour; software-properties Pro tab; ubuntu-advantage-desktop-daemon.
- Ubuntu distro overrides of GNOME privacy gsettings defaults.
- geoclue D-Bus activation after disable; KUserFeedback path still valid on Plasma 6.
- Exact apt flag spelling for suppressing autoremove during remove (`--no-auto-remove`), and whether `apt-get -s` works unprivileged: not on the fetched man page excerpt.
- Environment needed to run gsettings / systemctl --user for another user from a root or agent context (DBUS_SESSION_BUS_ADDRESS, XDG_RUNTIME_DIR, `--machine=user@.host`).
- Exact kernel / bootloader / libc / polkit package names per release in the protected list.
- Fedora abrt unit enablement via presets (src.fedoraproject.org blocked); abrt-vmcore.service, abrt-pstoreoops.service names.
- Arch wiki, Fedora docs (docs.fedoraproject.org), forge.fedoraproject.org, salsa.debian.org and packages.debian.org were all blocked by bot challenges; nothing from them is used.
