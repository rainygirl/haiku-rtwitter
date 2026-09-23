# R Twitter - development notes

R Twitter opens `https://x.com/` in R Chromium (the Qt-free Chromium 87 port,
https://github.com/rainygirl/haiku-rchromium-x86) with the browser toolbar
turned off and the window titled "R Twitter".

## History

The first version was a QtWebEngine app (`rtwitter.pro`, qmake). It was
replaced by a native launcher so the app no longer needs Qt; the Qt sources were
removed.

## How the launcher works (`src/RTwitter.sh`)

A shell script, and a short one. It finds R Chromium in
`/boot/system/apps/RChromium`, `~/config/non-packaged/apps/RChromium`, then
`~/RChromium`, and execs its `content_shell` at `https://x.com/` with

	RCH_NO_TOOLBAR=1                skips AttachBrowserChrome()
	RCH_APP_NAME="R Twitter"        the window's title
	--content-shell-host-window-size=1000x700
	--user-data-dir=~/config/settings/RTwitter
	--ozone-platform=haiku --single-process --disable-gpu
	--in-process-gpu --disable-gpu-compositing

If no R Chromium is installed it shows an `alert` naming the package
(`rchromium_x86` on 32-bit x86, `rchromium` elsewhere) and exits 1.

`make` copies the script, marks it executable and writes two attributes:
`BEOS:TYPE` so Tracker runs it on a double-click, and `BEOS:ICON` from
`assets/RTwitter.hvif`. **The icon is R Twitter's own**, not the X mark from
x.com's web app manifest -- this repository ships its own launcher rather than
going through R Chromium's install button, precisely so the name and icon stay
R Twitter's.

### It used to be 267 lines of C++, and that is worth recording

`src/main.cpp` existed almost entirely to work around two things the browser
has since grown:

- R Chromium named every window "R Chromium" with no way to change it, so the
  launcher stayed resident as a `B_BACKGROUND_APP` and renamed the browser's
  windows through BWindow scripting once a second until the browser quit.
  `RCH_APP_NAME` (2026-09-23) does that inside the browser, where it belongs.
- It used `load_image()` rather than exec, because Tracker pre-registers the
  team under R Twitter's signature and content_shell registers its own
  BApplication, which would clash in one team. A script has no BApplication,
  so there is nothing to clash.

What is left is what was always the point: find R Chromium and point it at
x.com. It is now the same shape of launcher R Chromium writes when you press
the install button on a site with a web app manifest, which means one thing to
maintain instead of two.

**One behaviour was lost.** `B_SINGLE_LAUNCH` brought the existing window to
the front when R Twitter was launched again; a script opens a second window.
Every installed web app on this system behaves that way, so this is
consistency rather than a special case -- but it is a regression and should be
named as one.

## Known limitations

- **Sign-in does not persist.** On Haiku R Chromium forces an off-the-record
  (in-memory) browser context to avoid a single-process crash
  (`shell_browser_main_parts.cc`), so `--content-shell-data-path` would not
  help. Cookies are gone when the window closes.
- **Navigation is not restricted to x.com**, and there are no back/forward
  buttons.
- **Deskbar's task list still shows `content_shell`.** Deskbar names a running
  team after its executable, and the executable is R Chromium's. The *window*
  is titled "R Twitter" now (RCH_APP_NAME), and the Applications menu entry
  carries R Twitter's name and icon, but the team in the tray does not.
  Renaming it would mean a copy of the binary per app, which is 219 MB each.
- **Relaunching opens a second window** rather than raising the first. The C++
  launcher used `B_SINGLE_LAUNCH` for that; a script cannot.
- X accepted Chromium 87's default user agent; no override is set.
- Login popups (Google/Apple) were not verified: a synthetic mouse click did not
  reach the page.
- arm64 is untested; that port may ignore `RCH_NO_TOOLBAR`.
- Chromium 87 gets no upstream security updates.

## Testing (VAIO P, x86_gcc2)

x.com takes 60-80 s to render on the 1.33 GHz Atom. The X sign-in page showed
without a toolbar and with the title "R Twitter"; quitting the browser quit the
launcher; relaunching brought the window forward.

## Icon and attributes

`tools/make_icon.py` projects Wikimedia Commons' `Logo of Twitter.svg`
(`assets/`, Apache 2.0, see `assets/NOTICE`) onto the lid of a thin isometric
box, writes the `vector_icon` in `RTwitter.rdef` and `assets/RTwitter.hvif`.
The Makefile writes BEOS:TYPE, BEOS:APP_SIG and BEOS:ICON as attributes after
`xres`: `mimeset` only copies resources into attributes when the registrar
sniffs the file as an application, which did not happen on the test machine,
and Tracker shows a generic icon without them.

## Packaging

`pkgman-repo/recipes/rtwitter.recipe`: x86_gcc2 (requires `rchromium_x86`) and
arm64 (requires `rchromium`), installs `apps/R Twitter` with a Deskbar link.
