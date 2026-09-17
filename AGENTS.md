# R Twitter - development notes

R Twitter opens `https://x.com/` in R Chromium (the Qt-free Chromium 87 port,
https://github.com/rainygirl/haiku-rchromium-x86) with the browser toolbar
turned off and the window titled "R Twitter".

## History

The first version was a QtWebEngine app (`rtwitter.pro`, qmake). It was
replaced by a native launcher so the app no longer needs Qt; the Qt sources were
removed.

## How the launcher works (`src/main.cpp`)

- Finds R Chromium in `/boot/system/apps/RChromium`,
  `~/config/non-packaged/apps/RChromium`, then `~/RChromium`. If none exists it
  shows a BAlert naming the package to install (`rchromium_x86` or
  `rchromium`) and exits.
- Starts the browser with `load_image()` as a separate team, preferring the
  package's own `R Chromium` launcher script so each architecture keeps its
  flags; without the script it runs `content_shell` with the x86 flags
  (`--ozone-platform=haiku --single-process --disable-gpu --in-process-gpu
  --disable-gpu-compositing`). It is not exec'd in place: Tracker registers the
  team under R Twitter's signature and content_shell registers its own
  BApplication, which would clash in one team.
- Environment: `RCH_NO_TOOLBAR=1` skips `AttachBrowserChrome()` (see
  rchromium-native-x86 `shell_platform_delegate_aura.cc`), and
  `--content-shell-host-window-size=1000x700` (800x600 cut off the X sign-in
  page on a 1600x768 VAIO P).
- R Chromium hardcodes the window title "R Chromium"
  (`haiku_beapi_views.cc`). R Twitter stays alive as a `B_BACKGROUND_APP` and
  renames the browser windows through BWindow scripting once a second, quits
  when the browser quits, and brings the window to the front when launched
  again (`B_SINGLE_LAUNCH`).
- Builds with the default compiler (gcc2 on an x86_gcc2 hybrid); libbe only.

## Known limitations

- **Sign-in does not persist.** On Haiku R Chromium forces an off-the-record
  (in-memory) browser context to avoid a single-process crash
  (`shell_browser_main_parts.cc`), so `--content-shell-data-path` would not
  help. Cookies are gone when the window closes.
- **Navigation is not restricted to x.com**, and there are no back/forward
  buttons.
- **Deskbar lists the team as `content_shell`.** Deskbar names a team after its
  executable, which is read-only inside the R Chromium package; a symlink named
  "R Twitter" is resolved and does not help. Only copying the 188 MB binary or
  rebuilding Chromium would.
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
