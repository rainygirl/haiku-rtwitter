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
# /home, not /, and it stays that way whichever browser answers.
#
# x.com serves two web apps. The logged-out landing page at / is a Vite build
# whose entry module uses top-level await -- ES modules got that in Chrome 89,
# so on R Chromium 87 V8 stops at "SyntaxError: Unexpected reserved word", the
# app never starts, and what renders is x.com's no-JavaScript fallback: a page
# whose login form leads nowhere. /home is served by the older responsive-web
# app, which parses and runs on 87 as well as on 114.
#
# On the 114 build / does work -- verified 2026-09-28: the entry module runs,
# the app sets its own globals and the DOM it builds is the real landing page,
# not the fallback. That removes the reason / was avoided, but not the reason
# /home is right: /home is the timeline, which is where a signed-in user wants
# to land. So this URL is no longer a workaround, it is just the start page.
#
# It is also the slow one, and that is worth knowing before changing it.
# Measured on renku, 114, warm profile both times:
#
#     https://x.com/        4-7 s     the Vite app
#     https://x.com/home    53-66 s   the responsive-web app
#
# Ten times. The difference is the app and not the cache. So why keep the slow
# one? Because signed in is the case that matters, and /home is the one that
# can be relied on there: it is the same server-side app the 87 port was
# signed into and verified against. Signed-in / on 114 has not been tested and
# cannot be without an account. A start page ten times faster that might not
# carry a session is a bad trade for an app whose job is to show a timeline.
#
# RTWITTER_URL overrides it, which is how to try the other one.
START_URL="${RTWITTER_URL:-https://x.com/home}"
# content_shell opens 800x600 otherwise; this fits a 1600x768 VAIO P screen.
WINDOW_SIZE="--content-shell-host-window-size=1000x700"

# Where R Chromium may be, most specific first: the package, a hand-installed
# copy under ~/config, and a build installed straight into the home directory.
#
# The 114 directories come first, because a machine with both installed has
# them for a reason. 114 is the newer port -- it parses what x.com serves
# today, and with --data-path it keeps cookies and an HTTP cache on disk,
# which 87 cannot. 87 stays in the list and stays working; nothing here
# requires 114.
for dir in \
	"/boot/system/apps/RChromium114" \
	"$HOME/config/non-packaged/apps/RChromium114" \
	"$HOME/RChromium114" \
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
