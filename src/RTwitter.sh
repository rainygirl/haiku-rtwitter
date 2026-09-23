#!/bin/sh
# R Twitter - opens x.com in R Chromium, the Qt-free Chromium port for Haiku.
#
# This is the same shape of launcher R Chromium writes when you press the
# install button on a site with a web app manifest: a script that starts
# content_shell at one URL with the toolbar off. R Twitter predates that
# feature and used to be 267 lines of C++, almost all of it working around
# something the browser has since grown:
#
#   - The browser named every window "R Chromium" with no way to change it, so
#     the old launcher stayed resident as a B_BACKGROUND_APP and renamed the
#     windows through BWindow scripting once a second until the browser quit.
#     RCH_APP_NAME does that properly now, inside the browser.
#   - It used load_image() rather than exec so that Tracker's pre-registration
#     of this team's signature would not clash with content_shell's own
#     BApplication. A script has no BApplication, so there is nothing to clash.
#
# What is left is the part that was always the point: find R Chromium, and
# start it pointed at x.com.
#
# One thing the C++ version did that this does not: relaunching brought the
# existing window to the front (B_SILENT_RELAUNCH). A script gets a second
# window instead. Every installed web app on this system behaves that way.

APP_TITLE="R Twitter"
# /home, not /. x.com serves two different web apps, and only one of them runs
# here. The logged-out landing page at / is a Vite build whose entry module
# uses top-level await -- ES modules got that in Chrome 89 and this is
# Chromium 87, so V8 stops at "SyntaxError: Unexpected reserved word", the app
# never starts, and what is left is x.com's no-JavaScript fallback: a page
# whose login form leads nowhere. /home is served by the older
# responsive-web app, which parses and runs, logged out as well as in. The
# user agent makes no difference; this is per route.
START_URL="https://x.com/home"
# content_shell opens 800x600 otherwise; this fits a 1600x768 VAIO P screen.
WINDOW_SIZE="--content-shell-host-window-size=1000x700"

# Where R Chromium may be, most specific first: the package, a hand-installed
# copy under ~/config, and a build installed straight into the home directory.
for dir in \
	"/boot/system/apps/RChromium" \
	"$HOME/config/non-packaged/apps/RChromium" \
	"$HOME/RChromium"
do
	if [ -x "$dir/content_shell" ]; then
		APPDIR="$dir"
		break
	fi
done

if [ -z "$APPDIR" ]; then
	# 32-bit x86 Haiku calls the package rchromium_x86; everywhere else it is
	# rchromium.
	case "$(uname -m)" in
		BePC|i*86) package="rchromium_x86" ;;
		*)         package="rchromium" ;;
	esac
	alert --stop "$APP_TITLE needs R Chromium, which is not installed.

pkgman install $package" "OK" > /dev/null
	exit 1
fi

# Blink aborts without a fontconfig file and Haiku ships no /etc/fonts.
if [ -z "$FONTCONFIG_FILE" ]; then
	if [ -r "$APPDIR/rchromium-fonts.conf" ]; then
		FONTCONFIG_FILE="$APPDIR/rchromium-fonts.conf"
	else
		FONTCONFIG_FILE="/boot/home/rchromium-fonts.conf"
	fi
	export FONTCONFIG_FILE
fi

# No toolbar, and the window carries this app's name rather than the page's.
RCH_NO_TOOLBAR=1
RCH_APP_NAME="$APP_TITLE"
export RCH_NO_TOOLBAR RCH_APP_NAME

# --disable-gpu-compositing is not optional on this backend: without it the
# renderer blocks at startup waiting for a GPU channel that never comes.
# --data-path, not --user-data-dir: that is Chrome's switch and content_shell
# does not read it, so R Twitter had been sharing R Chromium's profile all
# along. content_shell's own switch is in shell_browser_context.cc.
exec "$APPDIR/content_shell" \
	--ozone-platform=haiku \
	--single-process \
	--disable-gpu \
	--in-process-gpu \
	--disable-gpu-compositing \
	"$WINDOW_SIZE" \
	--data-path="$HOME/config/settings/RTwitter" \
	"$START_URL" "$@"
