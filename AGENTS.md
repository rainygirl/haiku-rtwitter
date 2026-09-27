# R Twitter - development notes

R Twitter opens `https://x.com/home` in R Chromium, the Qt-free Chromium port
for Haiku, with the browser toolbar turned off and the window titled
"R Twitter".

There are two R Chromium builds now and the launcher takes either. The 87 port
(https://github.com/rainygirl/haiku-rchromium-x86) is what the `rchromium_x86`
package installs. The 114 port, in `../rchromium-native-x86/chromium114_port`,
is newer in every way that matters here -- it parses what x.com serves today,
and with `--data-path` it keeps cookies *and* an HTTP cache on disk, which 87
cannot. R Twitter prefers it when it is installed.

## History

The first version was a QtWebEngine app (`rtwitter.pro`, qmake). It was
replaced by a native launcher so the app no longer needs Qt; the Qt sources were
removed.

## How the launcher works (`src/RTwitter.sh`)

A shell script, and a short one. It looks for R Chromium in six places --
`/boot/system/apps`, `~/config/non-packaged/apps` and `~`, each with
`RChromium114` before `RChromium` -- and execs the first `content_shell` it
finds at `https://x.com/home` with

	RCH_NO_TOOLBAR=1                skips AttachBrowserChrome()
	RCH_APP_NAME="R Twitter"        the window's title
	--content-shell-host-window-size=1000x700
	--data-path=~/config/settings/RTwitter
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

## x.com serves two web apps, and 87 runs only the older one (2026-09-23)

  - `/` (logged out) is a Vite build under `abs.twimg.com/x-web/x-web/` whose
    entry module uses **top-level await**. ES modules got that in Chrome 89;
    the 87 port is Chromium 87. V8 stops at `SyntaxError: Unexpected reserved
    word`, the app never starts, and what renders is x.com's no-JavaScript
    fallback: a plain page with a login form that leads nowhere. This is
    deterministic, and the user agent makes no difference -- spoofing Chrome 87
    gets the same bundle as the Chrome 999 the port claims.
  - `/home` is the older `responsive-web/client-web` React app. It parses and
    runs on 87, logged out as well as in.

Verified end to end on the real launcher with `scripts/sendkeys.cpp` from the
R Chromium repo: handle `rainygirl_`, then a deliberately wrong password, and
x.com answered "The password you entered is incorrect" -- so the form reaches
the server and the flow is intact. No password needed to test this.

### The 114 port runs both (2026-09-28)

`/` works on 114, and it was worth checking rather than assuming, because a
login form renders either way and the fallback looks much like the app. What
distinguishes them is the bundle:

    module script    https://abs.twimg.com/x-web/x-web/entry-client-logged-out-*.js
    noscript count   0
    window globals   __xClientTextFormatters
    DOM nodes        213 right after load, 515 once the app has built the page
    buttons          "Continue with phone", "Google 계정으로 계속하기", ...

The entry module ran: it set its own global, it built the page, and it loaded
Google's GSI client, which then localised its own button. None of that happens
in a `<noscript>` fallback.

A caveat about how that was tested. The synthetic check --
`await import('data:text/javascript,await 0;...')` -- comes back
`TypeError: Failed to fetch dynamically imported module`, because x.com's CSP
blocks `data:` module imports. That is not a top-level-await failure and it is
not evidence either way; the evidence is the real bundle above.

**`START_URL` stays `https://x.com/home` anyway**, and the reason is not the
one it used to be. The launcher has to keep working on 87, where `/` is still
the dead fallback -- but on 114 the choice is a real trade, because the two
routes are not the same speed:

    https://x.com/        4-7 s     the Vite app
    https://x.com/home    53-66 s   the responsive-web app

Ten times, measured on renku with a warm profile both times, so this is the
app and not the cache. `/home` keeps it anyway because signed in is the case
that matters and `/home` is the one that can be relied on there: it is the
same server-side app the 87 port was signed into and verified against.
Signed-in `/` on 114 has not been tested and cannot be without an account. A
start page ten times faster that might not carry a session is a bad trade for
an app whose job is to show a timeline.

`RTWITTER_URL` overrides it, which is how to try the other one.

If a future x.com stops serving the old app at `/home`, the 87 port stops
working and the fix is not on this side.

## Known limitations

- ~~**Sign-in does not persist.**~~ **Fixed 2026-09-23.** The reasoning here
  was half right and the conclusion was wrong. R Chromium does force an
  off-the-record context on Haiku (`shell_browser_main_parts.cc`) to avoid a
  single-process crash, and that does keep web storage in memory -- but the
  cookie store is not part of the storage partition. It lives in the network
  context, it is sqlite rather than `disk_cache`, and setting `cookie_path`
  there gives persistent cookies without touching the subsystem that crashes.
  R Chromium now does that, and `--data-path` (not `--user-data-dir`, which is
  Chrome's switch and content_shell ignores) puts R Twitter's cookies in
  `~/config/settings/RTwitter`. A sign-in survives closing the window.
  Needs the `rchromium_x86` package at 87.0.4280.144-4 or newer.
- **Every launch is a cold start on 87.** The HTTP cache is in memory, on
  purpose: `disk_cache` is one of the subsystems named in the crash above. On
  the VAIO x.com takes around two minutes to appear, every time.

  **Not so on 114** (2026-09-28). Stock content_shell leaves the network
  context entirely in memory -- it sets no `file_paths` and no
  `http_cache_directory` -- so the 114 port sets them from `--data-path`, the
  way the 87 port set 87's flatter `cookie_path` and `http_cache_path`. The
  profile then carries `Network/Cookies`, `Network Persistent State` and a
  `Cache` directory, and none of it crashes: after one x.com load the cache
  was 11.9 MB and the browser was still running. 114 does not force the
  off-the-record context that 87 needs, so web storage lands on disk too --
  `Local Storage/leveldb`, `Session Storage`, `Code Cache`.

  The cookie store commits on a timer, roughly every 30 s. A `kill -9` inside
  that window loses the most recent cookies, which is how the first attempt at
  measuring this came back negative; closing the window does not.
- **Navigation is not restricted to x.com**, and there are no back/forward
  buttons.
- **Deskbar's task list still shows `content_shell`.** Deskbar names a running
  team after its executable, and the executable is R Chromium's. The *window*
  is titled "R Twitter" now (RCH_APP_NAME), and the Applications menu entry
  carries R Twitter's name and icon, but the team in the tray does not.
  Renaming it would mean a copy of the binary per app, which is 219 MB each.
- **Relaunching opens a second window** rather than raising the first. The C++
  launcher used `B_SINGLE_LAUNCH` for that; a script cannot.
- X accepted Chromium 87's default user agent; no override is set. The 114
  port reports `Linux x86_64` for `navigator.platform` rather than
  `Haiku BePC`, because its `navigator_base.cc` edit joins the Linux arm. X
  does not appear to care. It is still wrong and is recorded in the port's own
  notes.
- Login popups (Google/Apple) were not verified: a synthetic mouse click did not
  reach the page.
- arm64 is untested; that port may ignore `RCH_NO_TOOLBAR`.
- Chromium 87 gets no upstream security updates.

## Testing

### VAIO P, x86_gcc2, the 87 port

x.com takes 60-80 s to render on the 1.33 GHz Atom. The X sign-in page showed
without a toolbar and with the title "R Twitter"; quitting the browser quit the
launcher; relaunching brought the window forward.

### renku, x86_gcc2, the 114 port (2026-09-28)

renku is not the VAIO and these numbers are not comparable to the ones above.
Nothing here has been run on the Atom yet.

    window title          "R Twitter"   (hey content_shell GET Title OF Window 0)
    x.com/ render         4-7 s, 24 runs
    x.com/home render     53-66 s, 3 runs   <- the launcher's own start page
    cookie round trip     set, wait 60 s, kill, restart -> cookie is back
    stock libnetwork      24 of 25 loads finished inside the limit

Launched from the installed Desktop copy, not a test script: the window came
up titled "R Twitter" with no toolbar and x.com's sign-in modal rendered.

The window title is the one thing the 114 port had to be taught. It is stock
content_shell with `toolkit_views` off, which has no browser chrome and never
pushes a page title down to the platform window -- so the name a `BWindow` is
born with is the name it keeps, and `haiku_beapi_views.cc` now reads
`RCH_APP_NAME` in the constructor. `HaikuWindow::SetTitle()` honours it too,
for whatever path might call it later. `RCH_NO_TOOLBAR` is moot on 114:
`AttachBrowserChrome()` is compiled but nothing calls it, because the caller
lived in the 87 overlay's `shell_platform_delegate_aura.cc`.

**The launcher does not need a patched libnetwork.** Haiku's
`res_ndestroy()` closing fd 0 (see the port repo's
`haiku_kernel_patches/K0002`) reaches 114 as it reached 108 -- the probe fires
0 to 10 times per load -- but it no longer breaks the load: the 114 tree carries
the `scoped_file.cc` workaround that stops a close of fd 0, 1 or 2 being fatal,
and with the stock system library 24 of 25 x.com loads finished. The one that
did not showed **zero** fd-0 events and no crash, so whatever it was, it was
not that bug; 15 loads in five minutes may simply be more than x.com wants.
The probe's logging is now behind `RCH_FD0_PROBE=1` -- it used to print on
every load, which is noise a user cannot act on.

## Icon and attributes

`tools/make_icon.py` projects Wikimedia Commons' `Logo of Twitter.svg`
(`assets/`, Apache 2.0, see `assets/NOTICE`) onto the lid of a thin isometric
box, writes the `vector_icon` in `RTwitter.rdef` and `assets/RTwitter.hvif`.
The Makefile writes BEOS:TYPE, BEOS:APP_SIG and BEOS:ICON as attributes after
`xres`: `mimeset` only copies resources into attributes when the registrar
sniffs the file as an application, which did not happen on the test machine,
and Tracker shows a generic icon without them.

## Packaging

There is none in this repository any more -- the recipe was removed on request.
`make install` puts the launcher in `~/config/non-packaged/apps/RTwitter` with
Desktop and Deskbar copies, and that is the whole install story.

The 114 port is also not packaged yet. It is run from `~/RChromium114`, whose
shape the launcher already accepts, with its three libraries in
`RChromium114/lib/` so Haiku's default `LIBRARY_PATH` (`%A/lib`) finds them
without the launcher setting anything.
