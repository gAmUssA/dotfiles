#!/usr/bin/env bash
# macos-defaults.sh — reproduce this Mac's system settings on another machine.
#
# The gap this fills: linkall.sh handles config files, prefs-backup.sh handles
# GUI app preferences, Brewfile handles packages — but macOS's own settings
# (Dock, Finder, keyboard, hot corners, trackpad) were manual on every new
# machine. prefs-backup.sh deliberately excludes them, noting they "belong in
# a `defaults write` script". This is that script.
#
# GENERATED FROM THIS MACHINE, not from a generic opinionated list. Every line
# below was read off a real setting that was actually customised here; OS
# defaults were skipped. 55 settings across 10 domains.
#
# To refresh after changing System Settings, re-read the values you care about:
#     defaults read com.apple.dock tilesize
# and update the line here. There is no automatic re-dump — that is deliberate,
# since `defaults` cannot distinguish "customised" from "OS default that
# happens to be written", and a blind dump would bloat this file every run.
#
# Idempotent: re-running changes nothing that is already set.
#
# Some settings only apply after a logout (notably tap-to-click and the
# keyboard repeat rates) — the killall at the end covers the rest.
#
# Usage:
#     ./macos-defaults.sh              apply
#     ./macos-defaults.sh --dry-run    print what would change, touch nothing

set -uo pipefail

DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

defaults() {
    if (( DRY )); then
        # Show current vs intended so a dry run is actually informative.
        if [[ "$1" == "write" ]]; then
            local cur want flag
            cur=$(command defaults read "$2" "$3" 2>/dev/null || echo "<unset>")
            flag="$4"
            want="${*: -1}"
            # `defaults read` prints booleans as 1/0, but we write true/false.
            # Without normalising, every -bool line reports as a change even on
            # a machine that already matches exactly.
            if [[ "$flag" == "-bool" ]]; then
                case "$cur" in 1) cur=true ;; 0) cur=false ;; esac
            fi
            # Likewise -float: `defaults read` may print 53 for a float 53.0.
            if [[ "$flag" == "-float" || "$flag" == "-int" ]]; then
                [[ "$cur" =~ ^-?[0-9]+\.0+$ ]] && cur="${cur%%.*}"
                [[ "$want" =~ ^-?[0-9]+\.0+$ ]] && want="${want%%.*}"
            fi
            if [[ "$cur" == "$want" ]]; then
                printf '  same    %s %s = %s\n' "$2" "$3" "$cur"
            else
                printf '  CHANGE  %s %s : %s -> %s\n' "$2" "$3" "$cur" "$want"
            fi
            return 0
        fi
    fi
    command defaults "$@"
}

echo "=== macos-defaults$( ((DRY)) && echo ' (dry run)' ) ==="

# ---- NSGlobalDomain ----------------------------------------------------
defaults write NSGlobalDomain KeyRepeat -int 2                                # key repeat rate (lower = faster)
defaults write NSGlobalDomain InitialKeyRepeat -int 15                        # delay before repeat starts
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3                      # full keyboard access
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool true     # auto-capitalise
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool true   # smart dashes
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool true  # period on double-space
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool true  # smart quotes
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool true  # autocorrect
defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool true  # autocorrect in web views
defaults write NSGlobalDomain AppleMeasurementUnits -string "Inches"          # measurement units
defaults write NSGlobalDomain AppleMetricUnits -bool false                    # metric units
defaults write NSGlobalDomain AppleTemperatureUnit -string "Fahrenheit"       # temperature unit
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.5           # trackpad tracking speed
defaults write NSGlobalDomain com.apple.mouse.scaling -float 1.5              # mouse tracking speed
defaults write NSGlobalDomain com.apple.springing.enabled -bool true          # spring-loaded folders
defaults write NSGlobalDomain com.apple.springing.delay -float 0.5            # spring-loading delay

# ---- com.apple.AppleMultitouchTrackpad ---------------------------------
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true          # tap to click (built-in)
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool false  # three-finger drag

# ---- com.apple.driver.AppleBluetoothMultitouch.trackpad ----------------
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true  # tap to click (bluetooth)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool false  # three-finger drag (bluetooth)

# ---- com.apple.dock ----------------------------------------------------
defaults write com.apple.dock autohide -bool true                             # auto-hide the Dock
defaults write com.apple.dock autohide-delay -float 0.2                       # delay before the Dock appears
defaults write com.apple.dock autohide-time-modifier -int 0                   # Dock show/hide animation speed
defaults write com.apple.dock tilesize -float 53                              # Dock icon size
defaults write com.apple.dock magnification -bool true                        # Dock magnification
defaults write com.apple.dock largesize -float 119                            # magnified icon size
defaults write com.apple.dock orientation -string "right"                     # Dock position
defaults write com.apple.dock mineffect -string "scale"                       # minimise effect
defaults write com.apple.dock minimize-to-application -bool true              # minimise into the app icon
defaults write com.apple.dock show-recents -bool false                        # show recent apps in the Dock
defaults write com.apple.dock mru-spaces -bool false                          # auto-rearrange Spaces by use
defaults write com.apple.dock wvous-tl-corner -int 14                         # hot corner: top-left
defaults write com.apple.dock wvous-bl-corner -int 5                          # hot corner: bottom-left
defaults write com.apple.dock wvous-br-corner -int 14                         # hot corner: bottom-right
defaults write com.apple.dock wvous-tl-modifier -int 524288                   # hot corner modifier: top-left
defaults write com.apple.dock wvous-bl-modifier -int 0                        # hot corner modifier: bottom-left
defaults write com.apple.dock wvous-br-modifier -int 524288                   # hot corner modifier: bottom-right

# ---- com.apple.finder --------------------------------------------------
defaults write com.apple.finder ShowPathbar -bool true                        # path bar
defaults write com.apple.finder ShowStatusBar -bool true                      # status bar
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"           # default view style
defaults write com.apple.finder NewWindowTarget -string "PfHm"                # new window opens at
defaults write com.apple.finder NewWindowTargetPath -string "file:///Users/vikgamov/"  # new window path
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true    # external drives on desktop
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true            # internal drives on desktop
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true        # removable media on desktop

# ---- com.apple.screencapture -------------------------------------------
defaults write com.apple.screencapture show-thumbnail -bool false             # floating thumbnail after capture

# ---- com.apple.WindowManager -------------------------------------------
defaults write com.apple.WindowManager GloballyEnabled -bool false            # Stage Manager
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false  # click wallpaper to show desktop
defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true    # hide desktop icons
defaults write com.apple.WindowManager HideDesktop -bool true                 # hide desktop items

# ---- com.apple.menuextra.clock -----------------------------------------
defaults write com.apple.menuextra.clock ShowSeconds -bool false              # seconds in the menu bar clock
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false            # day of week in the clock

# ---- com.apple.universalaccess -----------------------------------------
defaults write com.apple.universalaccess reduceMotion -bool true              # reduce motion
defaults write com.apple.universalaccess reduceTransparency -bool false       # reduce transparency

# ---- com.apple.ActivityMonitor -----------------------------------------
defaults write com.apple.ActivityMonitor ShowCategory -int 100                # Activity Monitor default view

# ---- hot corner reference ----------------------------------------------
# corner values:  0 disabled · 2 Mission Control · 3 App Windows · 4 Desktop
#                 5 Screen Saver · 6 Disable Screen Saver · 10 Display Sleep
#                 11 Launchpad · 12 Notification Centre · 13 Lock Screen
#                 14 Quick Note
# modifier flags: 0 none · 131072 shift · 262144 control · 524288 option
#                 1048576 command
# So this machine: top-left = Quick Note (⌥), bottom-left = Screen Saver,
# bottom-right = Quick Note (⌥). Top-right is unset.
#
# ---- other opaque values used above ------------------------------------
# FXPreferredViewStyle: icnv icon · Nlsv list · clmv column · Flwv gallery
# NewWindowTarget:      PfHm home · PfDe desktop · PfDo documents · PfLo other
# mineffect:            genie · scale · suck

if (( DRY )); then
    echo
    echo "dry run — nothing was changed."
    exit 0
fi

echo
echo "restarting affected UI processes..."
for app in Dock Finder SystemUIServer; do
    killall "$app" >/dev/null 2>&1 && echo "  restarted $app"
done

echo
echo "done. Note: tap-to-click and keyboard repeat rates need a logout to apply."
