# macOS debloat research: findings

Researched 2026-11-23. Targets: macOS 14 Sonoma, 15 Sequoia, 26 Tahoe, and the current release.
Every claim below carries the URL it was read on. Anything not read on a page is in
[UNVERIFIED](#unverified). Machine-readable candidates: `research/raw/macos-candidates.json`.

## Summary

- **Current macOS is 27 "Golden Gate"**, released 2026-09-14, Apple silicon only. A user report
  dated 2026-10-29 mentions build 27.2. Intel support ends at macOS 26 Tahoe.
  (https://www.macrumors.com/2026/09/10/macos-27-golden-gate-release-date/,
  https://gist.github.com/b0gdanw/b349f5f72097955cf18d6e7d8035c665?permalink_comment_id=6449310#gistcomment-6449310)
- **Removable apps are only GarageBand, iMovie, Keynote, Numbers and Pages.** Everything else
  Apple ships is on the sealed system volume or in a cryptex.
- **Apple Intelligence has no stable `defaults` key.** The only known key is named after the
  account's numeric id and changes. The supported controls are System Settings and MDM.
- **`launchctl disable` on Apple's own agents does not take effect with SIP enabled.** Every
  "debloat" list that targets them requires SIP off. Recommendation: offer none of them. The only
  defensible launchctl items are the legacy network daemons that the NIST mSCP baseline disables
  with SIP on.
- **Most privacy toggles that do have keys are verified only as MDM-managed preferences**
  (mSCP) plus user-level use in maintained dotfiles. Few sources state the exact build tested.
- **The App Store ids for Keynote, Numbers and Pages changed.** The old Mac-only ids no longer
  resolve, and the current builds require macOS 26, so "reinstall from the App Store" is not a
  reliable revert on macOS 14 and 15.

## 1. What can and cannot be removed

### Removable (in /Applications, installed as App Store apps)

Apple's "Apps included on your Mac" page marks exactly five apps as optional, each with the
wording "If X isn't installed on your Mac, you can get it from the App Store":
GarageBand, iMovie, Keynote, Numbers, Pages.
(https://support.apple.com/guide/mac-help/apps-included-on-your-mac-mchl110b00b7/mac)

Identifiers read from the iTunes lookup API on 2026-11-23
(https://itunes.apple.com/lookup?id=682658836,408981434,409183694,409203825,409201541&country=us&entity=macSoftware):

| App | Bundle id | App Store id | Store version | Store minimum macOS |
|---|---|---|---|---|
| GarageBand | `com.apple.garageband10` | 682658836 | 10.4.15 | 15.6 |
| iMovie | `com.apple.iMovieApp` | 408981434 | 10.4.6 | 26.6 |
| Keynote | `com.apple.Keynote` | 361285480 | 16.0 | 26.0 |
| Numbers | `com.apple.Numbers` | 361304891 | 16.0 | 26.0 |
| Pages | `com.apple.Pages` | 361309726 | 16.0 | 26.0 |

- **Old iWork ids are dead.** Lookups for 409183694 (Keynote), 409203825 (Numbers) and 409201541
  (Pages) return an empty result, and `https://apps.apple.com/us/app/keynote/id409183694` returns
  HTTP 404. (https://itunes.apple.com/lookup?id=409183694&country=us&entity=macSoftware)
- **Revert consequence.** The store builds of iMovie and iWork need macOS 26, and GarageBand
  needs 15.6. On older systems the engine should revert by moving the bundle back from the Trash
  and should not empty the Trash.
- Deleting an app does not remove documents made with it or cancel subscriptions; emptying the
  Trash makes it permanent. (https://support.apple.com/en-us/102610)

### Not removable

- Apple: "You can't use the Finder to delete apps that are required by your Mac. This includes
  many apps that are installed by macOS, such as Mail, Music, Books, Notes, Podcasts, Maps, News,
  and Stocks, as well as any apps in the System folder, which is reserved by macOS."
  (https://support.apple.com/en-us/102610)
- Bundled apps live in `/System/Applications` on the Signed System Volume. Safari has been
  delivered in a cryptex since Ventura and only appears in `/Applications`. Launch constraints
  let bundled apps run only from those locations, and the only way to break that is to turn SIP
  off. (https://eclecticlight.co/2023/10/24/where-safari-hides-and-bundled-apps-crash/)
- Apps Apple lists as included in macOS 27 that are therefore out of scope: Apple Games, App
  Store, Books, Calendar, Chess, Clock, Contacts, FaceTime, Find My, Freeform, Home, Image
  Playground, iPhone Mirroring, Journal, Magnifier, Mail, Maps, Messages, Music, News, Notes,
  Passwords, Phone, Photo Booth, Photos, Podcasts, TV, Voice Memos and the utilities.
  (https://support.apple.com/guide/mac-help/apps-included-on-your-mac-mchl110b00b7/mac)

### Support content (documentation only, never touched)

Paths such as `/Library/Application Support/GarageBand` and `/Library/Audio/Apple Loops` were
seen only in search-result summaries of Apple Community threads, not on a page that was read.
See UNVERIFIED.

## 2. Apple Intelligence and Siri

### What Apple documents (System Settings only)

From "Turn off and restrict access to Apple Intelligence features on Mac", macOS 27 edition
(https://support.apple.com/guide/mac-help/mchlb2e44f94/mac):

| Feature | Where |
|---|---|
| Siri AI (Beta) / Siri | System Settings > Siri > Turn Off Siri |
| Siri Classic instead of Siri AI | Turn Off Siri, then Turn On Siri > Use Siri Classic |
| Messages summaries | Messages > Settings > Summarize Messages |
| Email summaries | Mail > Settings > Viewing > Summarize Message Previews |
| Notification summaries | System Settings > Notifications > Summarize Notifications |
| Personalized Smart Replies | Mail > Settings > Composing |
| Journal writing prompts | Journal > Settings > General |
| Restrict features | Screen Time > Siri Restrictions |

"Improve Siri & Apple Intelligence or Improve Siri & Dictation" is under Privacy & Security >
Analytics & Improvements. (https://support.apple.com/en-us/127070)

### MDM-only keys (not settable by `defaults write`)

All in the `com.apple.applicationaccess` restrictions payload. Most are deprecated from macOS
26.4 in favour of declarative configurations (`com.apple.configuration.intelligence.settings`,
`com.apple.configuration.siri.settings`, `com.apple.configuration.external-intelligence.settings`,
`com.apple.configuration.keyboard.settings`).
(https://developer.apple.com/documentation/devicemanagement/restrictions)

| Key | macOS availability |
|---|---|
| `allowAssistant` | 14+ |
| `allowDictation` | 10.13+ |
| `forceOnDeviceOnlyDictation` | 14+ |
| `allowGenmoji`, `allowImagePlayground`, `allowWritingTools` | 15+ |
| `allowMailSummary` | 15.1+ (manual summaries only) |
| `allowNotesTranscriptionSummary` | 15.3+ |
| `allowMailSmartReplies`, `allowSafariSummary`, `allowNotesTranscription`, `allowAppleIntelligenceReport` | 15.4+ |
| `allowExternalIntelligenceIntegrations`, `allowExternalIntelligenceIntegrationsSignIn` | ChatGPT-style extensions; see the page for versions |
| `allowiPhoneMirroring` | 15+ |
| `allowApplePersonalizedAdvertising` | 12+ |
| `allowDiagnosticSubmission`, `allowGameCenter`, `allowMultiplayerGaming`, `allowAddingGameCenterFriends` | 10.13+ |
| `allowAirPlayIncomingRequests` | 12.3+ |
| `allowSpotlightInternetResults` | 10.11+ |
| `allowSiriAI` | iOS and iPadOS 27 only, not macOS |

mSCP's Tahoe baseline implements every one of these "by a Configuration Profile" and checks the
managed value through `NSUserDefaults`; it offers no `defaults write` fix for any of them.
(https://github.com/usnistgov/macos_security/blob/tahoe/rules/os/os_writing_tools_disable.yaml,
https://github.com/usnistgov/macos_security/blob/tahoe/rules/system_settings/system_settings_siri_disable.yaml,
https://github.com/usnistgov/macos_security/blob/tahoe/rules/system_settings/system_settings_external_intelligence_disable.yaml)

Winnow must not install profiles, so these stay documentation.

### `defaults` keys

| Setting | Domain / key / type / value | Status |
|---|---|---|
| Apple Intelligence master switch | `com.apple.CloudSubscriptionFeatures.optIn` / a numeric key / bool false | **Not usable as a catalog item.** macos-defaults.com tested it on Sequoia with key `545129924`, but a contributor note on the same page says the number changes after updates. A Jamf write-up says the key name matches the account's DSID, and that a fresh macOS 26 install lacks the value it is derived from. (https://macos-defaults.com/misc/apple-intelligence.html, https://github.com/yannbertrand/macos-defaults/blob/main/docs/misc/apple-intelligence.md, https://community.jamf.com/tech-thoughts-180/raising-your-iq-on-apple-intelligence-55524) |
| Siri off | `com.apple.assistant.support` / `Assistant Enabled` / bool false | In privacy.sexy (source is a 2016 Sierra post) and kdeldycke/dotfiles (2026-11), which says only `allowAssistant` prevents re-enablement. No tested build stated. In candidates as moderate. (https://github.com/undergroundwires/privacy.sexy/blob/master/src/application/collections/macos.yaml, https://github.com/kdeldycke/dotfiles/blob/main/macos-config.sh) |
| Siri menu bar icon | `com.apple.Siri` / `StatusMenuVisible` / bool false | Same two sources. In candidates as safe. |
| Siri declined flag | `com.apple.Siri` / `UserHasDeclinedEnable` / bool true | privacy.sexy only, 2016 source. Not in candidates. |
| Siri voice feedback | `com.apple.assistant.backedup` / `Use device speaker for TTS` / int 3 | privacy.sexy only, 2020 sources. Not in candidates. |
| Old Siri menu item | `com.apple.systemuiserver` / `NSStatusItem Visible Siri` | privacy.sexy only, no source cited. Not in candidates. |
| Siri setup prompt | `com.apple.SetupAssistant` / `DidSeeSiriSetup` / bool true | rtrouton (2020) and privacy.sexy. Not verified on 14+. In candidates. |
| Improve Siri & Dictation | `com.apple.assistant.support` / `Siri Data Sharing Opt-In Status` / int 2 | Key and value match mSCP on Sonoma, Sequoia and Tahoe. In candidates as safe. |
| Writing Tools, Genmoji, Image Playground, ChatGPT extension, summaries | none | MDM or System Settings only. |

### Re-enablement after updates

macOS 15.3 enabled Apple Intelligence by default, and 15.3.1 re-enabled it for some users who
had opted out; reports tie it to a post-update welcome screen with no "Set Up Later" option.
(https://www.macrumors.com/2025/02/11/apple-intelligence-re-enabled-in-latest-updates/,
https://9to5mac.com/2025/02/11/bug-in-macos-and-ios-updates-re-enables-apple-intelligence-for-some-whod-opted-out/)
These two pages were seen as search results, not opened: treat as UNVERIFIED detail.

## 3. Analytics and telemetry

Apple's page names two toggles under Privacy & Security > Analytics & Improvements: "Share Mac
Analytics" and "Share with app developers". The Mac keeps analytics for one month.
(https://support.apple.com/guide/mac-help/mh27990/mac)

| Setting | Domain / key / type / value | Verification |
|---|---|---|
| Share Mac Analytics | `/Library/Application Support/CrashReporter/DiagnosticMessagesHistory` / `AutoSubmit` / bool false, sudo | kdeldycke/dotfiles (2026-11) calls this the plist behind the pane. mSCP uses the profile-only `com.apple.SubmitDiagInfo` `AutoSubmit` plus `allowDiagnosticSubmission`. (https://github.com/kdeldycke/dotfiles/blob/main/macos-config.sh, https://github.com/usnistgov/macos_security/blob/tahoe/rules/system_settings/system_settings_diagnostics_reports_disable.yaml) |
| Share with app developers | same plist / `ThirdPartyDataSubmit` / bool false, sudo | kdeldycke/dotfiles. |
| Improve Siri & Dictation | `com.apple.assistant.support` / `Siri Data Sharing Opt-In Status` / int 2 | mSCP sonoma, sequoia, tahoe; privacy.sexy; kdeldycke. (https://github.com/usnistgov/macos_security/blob/tahoe/rules/system_settings/system_settings_improve_siri_dictation_disable.yaml) |
| Help Apple Improve Search | `com.apple.assistant.support` / `Search Queries Data Sharing Status` / int 2 | mSCP sequoia and tahoe, absent in sonoma; kdeldycke. (https://github.com/usnistgov/macos_security/blob/tahoe/rules/system_settings/system_settings_improve_search_disable.yaml) |
| Improve Assistive Voice Features | `com.apple.Accessibility` / `AXSAudioDonationSiriImprovementEnabled` / bool false | mSCP sequoia and tahoe, absent in sonoma; kdeldycke. (https://github.com/usnistgov/macos_security/blob/tahoe/rules/system_settings/system_settings_improve_assistive_voice_disable.yaml) |
| Personalized ads | `com.apple.AdLib` / `allowApplePersonalizedAdvertising` / bool false | privacy.sexy reports GUI toggle flips from Monterey on; kdeldycke. mSCP uses the managed domain. (https://github.com/undergroundwires/privacy.sexy/blob/master/src/application/collections/macos.yaml) |
| Ad identifier | `com.apple.AdLib` / `allowIdentifierForAdvertising` / bool false | privacy.sexy only; it says there is no official documentation. |
| Limit ad tracking | `com.apple.AdLib` / `forceLimitAdTracking` / bool true | **Excluded.** privacy.sexy notes Apple documents it for iOS only and the key does not exist on macOS by default. |
| Crash dialog | `com.apple.CrashReporter` / `DialogType` / string `none` | drduh, kdeldycke; commented out in mathiasbynens. No version stated. (https://github.com/drduh/macOS-Security-and-Privacy-Guide) |
| Safari suggestions | `com.apple.Safari` / `UniversalSearchEnabled` bool false, `SuppressSearchSuggestions` bool true | mathiasbynens (2024), kdeldycke (2026). Container caveat below. (https://github.com/mathiasbynens/dotfiles/blob/main/.macos) |
| Spotlight suggestions | `com.apple.Spotlight` `orderedItems` array with `MENU_SPOTLIGHT_SUGGESTIONS` disabled | mathiasbynens and kdeldycke write an array of dictionaries. **Outside the engine's value types** (bool, int, float, string), so not a candidate. |
| Safari ad measurement | `com.apple.Safari` / `WebKitPreferences.privateClickMeasurementEnabled` | kdeldycke sets it **true**, matching mSCP `os_safari_advertising_privacy_protection_enable`. Turning it off reduces privacy; not a debloat item. |
| Photos enhanced visual search | `com.apple.photos.shareddefaults` / `IPXDefaultEnhancedVisualSearchEnabled` / false | mSCP Tahoe, profile only. Not confirmed as a user-level write. (https://github.com/usnistgov/macos_security/blob/tahoe/rules/os/os_photos_enhanced_search_disable.yaml) |
| Share iCloud Analytics | none found | Apple's current page does not list it. |

**Safari container caveat.** Safari is sandboxed and reads only its container preferences. With
Full Disk Access, `defaults write com.apple.Safari` targets the container file; without it,
`defaults` falls back to `~/Library/Preferences`, which Safari never reads, so the write appears
to succeed and does nothing. (https://mjtsai.com/blog/2020/09/23/macos-containers-and-defaults/,
quoting https://lapcatsoftware.com/articles/containers.html)

## 4. Ads, nags and suggestions

| Item | Domain / key / type / value | Verification |
|---|---|---|
| App Store video autoplay | `com.apple.AppStore` / `AutoPlayVideoSetting` string `off` and `UserSetAutoPlayVideoSetting` | kdeldycke writes the second as int 1, philiprein as bool true. (https://github.com/kdeldycke/dotfiles/blob/main/macos-config.sh, https://github.com/philiprein/macos-settings/blob/main/app_settings/app_store.sh) |
| App Store in-app ratings | `com.apple.AppStore` / `InAppReviewEnabled` / bool false | philiprein only (2023), "needs reboot". |
| Desktop widgets | `com.apple.WindowManager` / `StandardHideWidgets` / bool true | Raycast extension has Sonoma, Sequoia and Tahoe code paths; nix-darwin. (https://github.com/raycast/extensions/blob/main/extensions/toggle-desktop-visibility/src/utils/tahoe.ts, https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/defaults/WindowManager.nix) |
| Stage Manager widgets | `com.apple.WindowManager` / `StageManagerHideWidgets` / bool true | nix-darwin only. |
| Dock recents | `com.apple.dock` / `show-recents` / bool false, restart Dock | macos-defaults.com: tested Mojave through Sequoia. (https://macos-defaults.com/dock/show-recents.html) |
| Spotlight menu bar icon | `-currentHost com.apple.Spotlight` / `MenuItemHidden` / bool true | kdeldycke only. |
| Siri menu bar icon | `com.apple.Siri` / `StatusMenuVisible` / bool false | privacy.sexy, kdeldycke. |
| Time Machine new-disk prompt | `com.apple.TimeMachine` / `DoNotOfferNewDisksForBackup` / bool true | macos-defaults.com: Catalina only. (https://macos-defaults.com/timemachine/donotoffernewdisksforbackup.html) |
| Music song notifications | `com.apple.Music` / `userWantsPlaybackNotifications` / bool false | macos-defaults.com: Catalina, Ventura. (https://macos-defaults.com/misc/userwantsplaybacknotifications.html) |
| AirPlay Receiver | `-currentHost com.apple.controlcenter` / `AirplayReceiverEnabled` / bool false | kdeldycke; it notes the earlier misspelling `AirplayRecieverEnabled` is no longer read. |
| Handoff | `-currentHost com.apple.coreservices.useractivityd` / `ActivityAdvertisingAllowed`, `ActivityReceivingAllowed` | kdeldycke sets both true; false is inferred. |
| AirDrop | `com.apple.NetworkBrowser` / `DisableAirDrop` / bool true | privacy.sexy, no source or version. Not in candidates. |
| Setup Assistant screens | `com.apple.SetupAssistant` / `DidSeeCloudSetup`, `DidSeePrivacy`, `DidSeeTrueTonePrivacy`, `DidSeeTouchIDSetup`, `DidSeeSiriSetup`, `DidSeeActivationLock`, `DidSeeScreenTime` (bool true), plus `LastSeenCloudProductVersion`, `LastSeenBuddyBuildVersion` | rtrouton script, last changed 2020-07. Not verified on 14+. (https://github.com/rtrouton/rtrouton_scripts/tree/main/rtrouton_scripts/disable_apple_icloud_data_privacy_diagnostic_touch_id_siri_activation_lock_and_screentime_pop_ups) |

Setup Assistant: the supported mechanism is the MDM payload `com.apple.SetupAssistant.managed`
with `SkipSetupItems` values such as `Siri`, `Intelligence`, `Privacy` and `iCloudStorage`.
(https://github.com/usnistgov/macos_security/blob/tahoe/rules/os/os_skip_apple_intelligence_enable.yaml,
https://github.com/usnistgov/macos_security/blob/tahoe/rules/os/os_icloud_storage_prompt_disable.yaml)
No user-level key for the Apple Intelligence screen was found.

**No verified `defaults` key found** for: Apple Music, TV, News and Podcasts promotions; iCloud
storage upsell; Tips notifications; Game Center; Screen Time prompts; macOS upgrade
notifications; iPhone widgets; Stage Manager tips; Photos memories notifications; Shared with
You. Game Center and iPhone Mirroring have MDM keys only. Software Update settings are out of
scope by design.

## 5. Background agents and daemons

### Does `launchctl disable` work with SIP on?

Not for Apple's own agents.

- b0gdanw's Sonoma, Sequoia, Tahoe and Golden Gate scripts all state "Disabling SIP is
  required", and that changes are stored in `/private/var/db/com.apple.xpc.launchd/disabled.plist`
  and `disabled.501.plist`. (https://gist.github.com/b0gdanw/47fe6a8c1dfec0a9b11edded58565dd5)
- A user ran the user-domain half with SIP on: only `com.apple.biomesyncd` was disabled.
  (https://gist.github.com/b0gdanw/b349f5f72097955cf18d6e7d8035c665?permalink_comment_id=5490707#gistcomment-5490707)
- The author: "SIP must remain disabled. If you turn SIP back on, the changes are deleted by
  macOS." (https://gist.github.com/b0gdanw/b349f5f72097955cf18d6e7d8035c665?permalink_comment_id=5694780#gistcomment-5694780)
- On Tahoe one user reports the services keep running even with SIP off; another found most
  died but seven survived, and warns that `launchctl print-disabled` only shows a service is
  marked disabled, not that it is dead.
  (https://gist.github.com/b0gdanw/0c20c2fd5d0a7e6cff01849b57108967?permalink_comment_id=6236273#gistcomment-6236273,
  https://gist.github.com/b0gdanw/0c20c2fd5d0a7e6cff01849b57108967?permalink_comment_id=6449343#gistcomment-6449343)
- On Apple silicon, customising SIP puts the Mac in Permissive Security and iPhone and iPad apps
  stop opening; the measured gain on an M1 Pro was limited to the first two minutes after boot.
  (https://gist.github.com/b0gdanw/b349f5f72097955cf18d6e7d8035c665?permalink_comment_id=6449310#gistcomment-6449310)
- privacy.sexy's Siri-agent script prints "This script requires SIP to be disabled".
  (https://github.com/undergroundwires/privacy.sexy/blob/master/src/application/collections/macos.yaml)
- drduh: system services are protected by SIP, and disabling SIP to modify them can compromise
  security and cause instability. (https://github.com/drduh/macOS-Security-and-Privacy-Guide)

`launchctl disable` itself: a disabled service cannot be loaded in that domain until enabled
again, and the state persists across boots. The system domain needs root.
(https://ss64.com/mac/launchctl.html)

### Commonly cited labels

The Golden Gate list has 107 user-domain and 25 system-domain labels
(https://gist.github.com/b0gdanw/47fe6a8c1dfec0a9b11edded58565dd5). Reported breakage:

| Label | Domain | What breaks | Source |
|---|---|---|---|
| `com.apple.sharingd` | user | AirDrop | gistcomment-5533837 |
| `com.apple.chronod` | user | Widgets go blank | gistcomment-5673370 |
| `com.apple.imagent` | user | Messages; `kickstart` cannot restore, needs enable and reboot | gistcomment-5438199 |
| `com.apple.quicklook`, `.ui.helper`, `.ThumbnailsAgent` | user | Finder thumbnails | gistcomment-5533837 |
| `com.apple.remindd` | user | Reminders | gistcomment-5533837 |
| `com.apple.siriactionsd` | user | Stocks widget | gistcomment-5533837 |
| `com.apple.telephonyutilities.callservicesd` | user | FaceTime | gistcomment-5533837 |
| `com.apple.TMHelperAgent` | user | Time Machine | gistcomment-5533837 |
| `com.apple.rapportd` | agent (as reported) | Screen mirroring, macOS 15.5 | gistcomment-5580459 |
| `com.apple.dhcp6d` | system | No internet after VPN disconnect until reboot | gistcomment-5461448 |
| `com.apple.modelmanagerd` | system | coreaudiod and launchd spin CPU | gistcomment-5461524 |
| `com.apple.locationd` | system | Location Services, widgets, Weather | gistcomment-5673370 |
| `com.apple.icloud.findmydeviced` | system | Disk Utility cannot erase ("FindMyDevice-Error 13"), Sonoma 14.8 | https://gist.github.com/b0gdanw/812997a189f72f3953e0a1bb237f783d?permalink_comment_id=5835812#gistcomment-5835812 |
| `com.apple.backupd`, `com.apple.backupd-helper` | system | Time Machine | gistcomment-5533837 |
| `com.apple.biometrickitd` | system | Touch ID | gistcomment-5461448 |

Unless a full URL is given, comment ids are on
https://gist.github.com/b0gdanw/b349f5f72097955cf18d6e7d8035c665 (append
`?permalink_comment_id=<n>#gistcomment-<n>`).

Other labels in the lists that map to features Winnow must not break: `com.apple.cloudd`,
`com.apple.cloudphotod`, `com.apple.CloudSettingsSyncAgent`,
`com.apple.security.cloudkeychainproxy3`,
`com.apple.protectedcloudstorage.protectedcloudkeysyncing`, `com.apple.findmymac`,
`com.apple.icloud.searchpartyd`, `com.apple.ManagedClientAgent.enrollagent`,
`com.apple.familycontrols`, `com.apple.ScreenTimeAgent`, `com.apple.universalaccessd`,
`com.apple.accessibility.axassetsd`, `com.apple.voicebankingd`.

A reviewer of the Sonoma script summed it up: it "would break a lot of things people buy macs
specifically for".
(https://gist.github.com/b0gdanw/812997a189f72f3953e0a1bb237f783d?permalink_comment_id=5154677#gistcomment-5154677)

### Recommendation

- **Apple agents and daemons: offer none.** They do not disable with SIP on, Winnow never
  disables SIP, results vary by build, and a "marked disabled" state gives a false success.
- **Short allow-list that is defensible:** services the mSCP baseline disables with plain
  `launchctl disable` in the system domain and checks with `launchctl print-disabled`, on
  Sonoma, Sequoia and Tahoe:
  `com.apple.tftpd`, `com.apple.uucp`, `org.apache.httpd`, `com.apple.nfsd`.
  (https://github.com/usnistgov/macos_security/blob/tahoe/rules/os/os_tftpd_disable.yaml)
- **Opt-in only, because they remove sharing features:** `com.apple.smbd`,
  `com.apple.screensharing`, `com.openssh.sshd`, `com.apple.AEServer`. Refuse the last three
  when the agent session is itself remote.
  (https://github.com/usnistgov/macos_security/blob/tahoe/rules/system_settings/system_settings_ssh_disable.yaml)
- mSCP also runs `bootout` for some and `rm -rf /etc/exports` for NFS. Winnow's action type is
  disable only, so the service may keep running until restart, and `/etc/exports` is left alone.
- The engine must verify with `launchctl print-disabled system` after the change.

## 6. Must never touch

| Target | Reason | Source |
|---|---|---|
| SIP (`csrutil`), partial SIP (`csrutil enable --without fs`) | Apple warns of an unsupported configuration; on Apple silicon it forces Permissive Security and breaks iPhone and iPad apps | gistcomment-5738356, gistcomment-6449310 |
| `/private/var/db/com.apple.xpc.launchd/disabled*.plist` (direct edits or deletion) | The debloat scripts' "revert" is to delete these and reboot; Winnow reverts with `launchctl enable` only | https://gist.github.com/b0gdanw/47fe6a8c1dfec0a9b11edded58565dd5 |
| `/System`, `/System/Applications`, the Safari cryptex | Sealed volume; launch constraints | https://eclecticlight.co/2023/10/24/where-safari-hides-and-bundled-apps-crash/ |
| All labels in the section 5 breakage table | Reported breakage | section 5 |
| iCloud, Keychain sync, Find My, Family, Screen Time, accessibility agents listed in section 5 | Data sync, anti-theft, parental controls and assistive features | https://gist.github.com/b0gdanw/47fe6a8c1dfec0a9b11edded58565dd5 |
| Software Update preferences (`com.apple.SoftwareUpdate`, `com.apple.commerce`) | Out of scope; hardening guides turn these on, not off | https://github.com/kdeldycke/dotfiles/blob/main/macos-config.sh |
| MDM profiles and managed domains (`com.apple.applicationaccess`, `com.apple.SetupAssistant.managed`) | Owned by the organisation | https://developer.apple.com/documentation/devicemanagement/restrictions |
| `/etc/hosts` blocking of Apple relay hosts | The Jamf write-up that tried it reports odd errors in some apps | https://community.jamf.com/tech-thoughts-180/raising-your-iq-on-apple-intelligence-55524 |
| `com.apple.CloudSubscriptionFeatures.optIn` | Key name is account-specific and changes | https://macos-defaults.com/misc/apple-intelligence.html |
| Spotlight indexing (`mdutil -i off`) | Not one of the three change types | https://github.com/undergroundwires/privacy.sexy/blob/master/src/application/collections/macos.yaml |

## 7. Existing tools

| Tool | URL | License | What it does | Revert | Notes |
|---|---|---|---|---|---|
| b0gdanw "Disable ... Bloatware" gists | https://gist.github.com/b0gdanw/47fe6a8c1dfec0a9b11edded58565dd5 (27), https://gist.github.com/b0gdanw/0c20c2fd5d0a7e6cff01849b57108967 (Tahoe), https://gist.github.com/b0gdanw/b349f5f72097955cf18d6e7d8035c665 (Sequoia), https://gist.github.com/b0gdanw/812997a189f72f3953e0a1bb237f783d (Sonoma) | none stated | `launchctl bootout` and `disable` on about 130 Apple labels | Delete the disabled plists and reboot, or re-enable SIP | Requires SIP off. Header says not to run it as is. Uses a fixed uid of 501. Breakage in section 5. Updated through 2026-11. |
| drduh/macOS-Security-and-Privacy-Guide | https://github.com/drduh/macOS-Security-and-Privacy-Guide | MIT | Prose guide, few commands | n/a | Pushed 2026-11-20. Advises against disabling SIP to modify services. |
| mathiasbynens/dotfiles `.macos` | https://github.com/mathiasbynens/dotfiles/blob/main/.macos | MIT | One-way `defaults` script | none | Last pushed 2024-08; many keys predate Sonoma. |
| privacy.sexy macOS collection | https://github.com/undergroundwires/privacy.sexy | AGPL-3.0 | Generates scripts from a YAML catalog | `revertCode` per item | Pushed 2026-02. Several Siri items cite 2016 to 2020 sources. AGPL: do not copy text or code. |
| macos-defaults.com | https://macos-defaults.com/, https://github.com/yannbertrand/macos-defaults | MIT | Documents keys with "tested on" lists, read and reset commands | documented per key | Mostly UI preferences; little that is debloat. |
| kdeldycke/dotfiles | https://github.com/kdeldycke/dotfiles/blob/main/macos-config.sh | BSD-2-Clause | Large maintained config script that cross-references mSCP rule names | none | Pushed 2026-11-23. Best current source for user-level equivalents of mSCP rules. |
| NIST mSCP (usnistgov/macos_security) | https://github.com/usnistgov/macos_security | CC BY 4.0 (Apple vendor text excluded) | Per-release compliance rules with check and fix | profile removal | Branches for sonoma, sequoia, tahoe; no macOS 27 branch seen on 2026-11-23. |
| rtrouton_scripts | https://github.com/rtrouton/rtrouton_scripts | MIT | Admin scripts, including Setup Assistant suppression | none | That script last changed 2020-07. |
| nix-darwin | https://github.com/nix-darwin/nix-darwin | MIT | Declarative `defaults` options | declarative | Useful as a key reference. |
| kcrawford/dockutil | https://github.com/kcrawford/dockutil | Apache-2.0 | Command line tool for managing Dock items | manual | Not a debloat tool. |
| ParetoSecurity/pareto-mac | https://github.com/ParetoSecurity/pareto-mac | GPL-3.0 | Audits a Mac for basic security hygiene | n/a (audit) | Pushed 2026-11-23. |
| mvdbent/CIS-Script | https://github.com/mvdbent/CIS-Script | Apache-2.0 | CIS benchmark checks | n/a | Last pushed 2022; stale. |

A GitHub search for "debloat macos" returned no maintained general-purpose macOS debloat
repository: results were browser debloaters and one zero-star repo (`joshuarli/dumb-macos`).

## 8. Agent and automation concerns

- **Reading prior values.** `defaults read domain key` prints a "does not exist" message when
  nothing is stored; `defaults read-type domain key` gives the type; `defaults delete` restores
  default behaviour for most apps. `-bool true` writes a boolean but a bare `true` writes a
  string, so always pass the type flag. The page read does not document exit codes.
  (https://ss64.com/mac/defaults.html)
- **Type drift.** The same key is written as int by one source and bool by another
  (`UserSetAutoPlayVideoSetting`). Log the prior type as well as the prior value.
- **Path domains.** A domain can be a file path without `.plist`; the documentation warns this
  will change in a future major release to operate only on preference domains. This affects
  the `DiagnosticMessagesHistory` items. (https://ss64.com/mac/defaults.html)
- **Sandboxed containers and Full Disk Access.** See the Safari caveat in section 3. Some
  preference files are unreadable even with sudo unless the terminal has Full Disk Access.
  (https://github.com/kdeldycke/dotfiles/blob/main/macos-config.sh)
- **Making changes visible.** A running app may not see a change and may overwrite it; restart
  Dock or Finder with `killall`. `cfprefsd` caches preferences, so use `defaults`, never direct
  plist edits. (https://ss64.com/mac/defaults.html) kdeldycke notes that killing `cfprefsd` can
  discard a write it has not yet flushed, and that an open System Settings pane can override
  changes, so quit System Settings first and restart `cfprefsd` last.
  (https://github.com/kdeldycke/dotfiles/blob/main/macos-config.sh)
- **sudo without a TTY.** `sudo -n` never prompts and exits with an error if a password is
  needed. `-A` or `SUDO_ASKPASS` uses a helper program; `-S` reads the password from stdin;
  `-v` refreshes cached credentials. An agent should probe with `sudo -n true` and stop with a
  precondition if it fails. (https://ss64.com/mac/sudo.html)
- **Restore point.** `tmutil snapshot` makes a snapshot of the current Data volume on any Mac,
  whether or not Time Machine is configured. `tmutil localsnapshot` is documented as covering
  "all APFS volumes included in the Time Machine backup". Snapshots are an APFS feature.
  Roll-back is done from Recovery (Restore from Time Machine) and discards later snapshots;
  the author knows of no working Terminal roll-back command. The sealed system volume is not
  what is being rolled back. List with `tmutil listlocalsnapshots <mount_point>`, delete with
  `tmutil deletelocalsnapshots`. (https://eclecticlight.co/2026/05/07/how-to-make-and-roll-back-to-a-snapshot/,
  https://ss64.com/mac/tmutil.html)
  A snapshot is therefore a manual, whole-volume safety net. Winnow's own log is the revert path.
- **Managed Macs.** `profiles status -type enrollment` reports DEP and MDM enrollment and shows
  "(User Approved)" when applicable. (https://ss64.com/mac/profiles.html) Refuse on enrolled
  Macs: managed preferences override user writes, the settings in section 2 are the
  organisation's to set, and mSCP-style baselines will flag or re-apply them.
- **python3.** Python 2.7 was removed in macOS 12.3.
  (https://developer.apple.com/documentation/macos-release-notes/macos-12_3-release-notes)
  Many `/usr/bin` tools are trampolines that prompt to install the developer tools.
  (https://developer.apple.com/forums/thread/702210) Do not depend on python3.
- **jq.** A forum user states `/usr/bin/jq` is in macOS Sequoia and an Apple DTS engineer
  acknowledged it ("Oh, hey, would you look at that. Nice!").
  (https://developer.apple.com/forums/thread/765803) Not present on macOS 14 by this evidence,
  so do not depend on it. `osascript -l JavaScript` and `plutil` are used by mSCP and kdeldycke
  for the same jobs.
- **uid.** The gui and user launchd domains take a numeric uid (`id -u`); b0gdanw's scripts
  hard-code 501. (https://ss64.com/mac/launchctl.html)
- **Intel vs Apple silicon.** SIP state is machine-wide in NVRAM on Intel.
  (gistcomment-6449310) macOS 27 does not run on Intel.

## Protected identifiers

Never selectable by default; the engine should refuse these even with `-Only`-style overrides
unless the catalog explicitly carries them as `never-default`.

launchd labels, user domain:
`com.apple.sharingd`, `com.apple.chronod`, `com.apple.imagent`, `com.apple.quicklook`,
`com.apple.quicklook.ui.helper`, `com.apple.quicklook.ThumbnailsAgent`, `com.apple.remindd`,
`com.apple.siriactionsd`, `com.apple.telephonyutilities.callservicesd`,
`com.apple.TMHelperAgent`, `com.apple.rapportd-user`, `com.apple.cloudd`,
`com.apple.cloudphotod`, `com.apple.CloudSettingsSyncAgent`,
`com.apple.security.cloudkeychainproxy3`,
`com.apple.protectedcloudstorage.protectedcloudkeysyncing`,
`com.apple.ManagedClientAgent.enrollagent`, `com.apple.ScreenTimeAgent`,
`com.apple.familycircled`, `com.apple.universalaccessd`, `com.apple.accessibility.axassetsd`,
`com.apple.voicebankingd`, `com.apple.findmy.findmylocateagent`.

launchd labels, system domain:
`com.apple.dhcp6d`, `com.apple.modelmanagerd`, `com.apple.locationd`,
`com.apple.icloud.findmydeviced`, `com.apple.backupd`, `com.apple.backupd-helper`,
`com.apple.biometrickitd`, `com.apple.cloudd`, `com.apple.findmymac`,
`com.apple.findmymacmessenger`, `com.apple.icloud.searchpartyd`, `com.apple.familycontrols`,
`com.apple.rapportd`.

Preference domains: `com.apple.applicationaccess`, `com.apple.SetupAssistant.managed`,
`com.apple.SoftwareUpdate`, `com.apple.commerce`, `com.apple.CloudSubscriptionFeatures.optIn`.

Paths: `/System/**`, `/System/Applications/**`, `/private/var/db/com.apple.xpc.launchd/**`,
`/etc/hosts`, `/etc/exports`, and by project rule the TCC databases, Keychains, FileVault,
Gatekeeper, XProtect and MRT.

Apps: everything in section 1 "Not removable".

## UNVERIFIED

Not read on a page, or read only in a search summary. Do not ship without checking on a Mac.

- **App bundle paths.** `/Applications/GarageBand.app`, `iMovie.app`, `Keynote.app`,
  `Numbers.app`, `Pages.app` are conventional. No read source states them. Resolve by bundle id.
- **GarageBand support content.** `/Library/Application Support/GarageBand`,
  `/Library/Audio/Apple Loops`, `~/Music/GarageBand`, and the "Remove GarageBand Sound Library"
  button were seen only in search summaries of Apple Community threads.
- **Whether removed apps return after an upgrade.** No source read.
- **Whether any of the five apps is still preinstalled on new Macs running macOS 26 or 27.**
- **Any user-level key working on macOS 27.** No source states a 27 test for a `defaults` item;
  mSCP has no 27 branch. kdeldycke's file is current but does not name the build.
- **User-level writes versus managed values.** mSCP proves the domain, key and value under a
  profile. That System Settings reads the same key from the user domain is supported only by
  dotfiles and privacy.sexy.
- **Handoff keys set to false**, and whether `useractivityd` needs a restart.
- **`AirplayRecieverEnabled` (misspelled)** being the live key on Sonoma or early Sequoia.
- **`InAppReviewEnabled`, `StageManagerHideWidgets`, `MenuItemHidden`,
  `allowIdentifierForAdvertising`:** one source each.
- **`DidSee*` keys on macOS 14 and later**, and the key for the Apple Intelligence screen.
- **Which processes need restarting** for most keys. The `restart` arrays in the JSON are a
  conservative default (`cfprefsd`) except where a source names the process (Dock, Music, Safari).
- **`defaults` exit codes** for a missing key or domain.
- **`tmutil` snapshot retention period** and whether `tmutil snapshot` needs root or Full Disk
  Access. The 24-hour figure was not found.
- **Exact output strings of `profiles status -type enrollment`.**
- **`/usr/bin/python3` being a stub** without Command Line Tools; `xcode-select -p` as the test.
- **`/usr/bin/jq` on macOS 26 and 27** (evidence is for Sequoia only).
- **Apple Intelligence re-enabled by 15.3.1:** MacRumors and 9to5Mac pages seen as search
  results only. No report found for 26 or 27.
- **`launchctl disable` under SIP for non-Apple-bloat daemons.** mSCP prescribes it for the
  section 5 allow-list, but no source read shows a test of the result on a SIP-enabled Mac.
- **Apple Community threads** (discussions.apple.com 256234375, 256015206) redirected and could
  not be read.
- **`rapportd` label.** The report names the agent `com.apple.rapportd`; the scripts list the
  user agent as `com.apple.rapportd-user`. Both are protected here.
- No keys found at all for: Tips, Game Center, Apple Music/TV/News/Podcasts promotions, iCloud
  storage upsell, Screen Time prompts, upgrade notifications, iPhone widgets, Photos memories,
  Shared with You, location-based suggestions, Share iCloud Analytics.
