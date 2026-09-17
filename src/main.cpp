// R Twitter - opens x.com in R Chromium, the Qt-free Chromium port for Haiku.
//
// It finds an installed R Chromium and starts it as a separate team with the
// toolbar turned off (RCH_NO_TOOLBAR=1) and x.com as the start page. The
// browser is started with load_image() rather than exec'd in place: Tracker
// pre-registers this team under R Twitter's signature, and content_shell
// registers its own BApplication under another, which would clash inside one
// team.
//
// R Chromium names every window "R Chromium" and there is no switch to change
// that, so this app stays alive in the background (B_BACKGROUND_APP, no
// Deskbar entry of its own) and renames the browser's windows through BWindow
// scripting until the browser exits. Launching R Twitter again while it runs
// brings the browser window to the front.
//
// The code is kept gcc2-compatible so the default compiler builds it on an
// x86_gcc2 hybrid; it has no dependency beyond libbe.

#include <Alert.h>
#include <Application.h>
#include <Messenger.h>
#include <MessageRunner.h>

#include <image.h>
#include <OS.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define APP_SIGNATURE	"application/x-vnd.rainygirl-RTwitter"
#define APP_TITLE		"R Twitter"
#define START_URL		"https://x.com/"
// content_shell opens 800x600 otherwise; this fits a 1600x768 VAIO P screen.
#define WINDOW_SIZE		"--content-shell-host-window-size=1000x700"

static const uint32 kMsgWatch = 'wtch';
static const bigtime_t kWatchInterval = 1000000;
static const bigtime_t kScriptTimeout = 500000;

extern char** environ;

static bool
IsExecutable(const char* path)
{
	return access(path, X_OK) == 0;
}


static bool
IsReadable(const char* path)
{
	return access(path, R_OK) == 0;
}


// Starts `argv` as a new team with the current environment.
static team_id
Spawn(const char** argv)
{
	int argc = 0;
	while (argv[argc] != NULL)
		argc++;

	thread_id team = load_image(argc, argv, (const char**)environ);
	if (team < 0) {
		fprintf(stderr, "R Twitter: cannot start %s: %s\n", argv[0],
			strerror(team));
		return team;
	}
	resume_thread(team);
	return team;
}


// The packaged install (x86 and arm64) ships an "R Chromium" launcher script
// that already carries the flags its architecture needs, so prefer running
// that; it execs content_shell, which keeps the team id. A hand-installed
// build without the script gets the x86 port's flags.
static team_id
LaunchFrom(const char* dir)
{
	char script[B_PATH_NAME_LENGTH];
	snprintf(script, sizeof(script), "%s/R Chromium", dir);
	if (IsExecutable(script)) {
		const char* argv[] = { "/bin/sh", script, WINDOW_SIZE, START_URL,
			NULL };
		return Spawn(argv);
	}

	char shell[B_PATH_NAME_LENGTH];
	snprintf(shell, sizeof(shell), "%s/content_shell", dir);
	if (!IsExecutable(shell))
		return B_ENTRY_NOT_FOUND;

	// content_shell finds its .pak and locales next to itself, but Blink
	// aborts without a fontconfig file and Haiku installs no /etc/fonts.
	char fonts[B_PATH_NAME_LENGTH];
	snprintf(fonts, sizeof(fonts), "%s/rchromium-fonts.conf", dir);
	if (!IsReadable(fonts))
		strcpy(fonts, "/boot/home/rchromium-fonts.conf");
	if (getenv("FONTCONFIG_FILE") == NULL && IsReadable(fonts))
		setenv("FONTCONFIG_FILE", fonts, 1);

	const char* argv[] = { shell, "--ozone-platform=haiku",
		"--single-process", "--disable-gpu", "--in-process-gpu",
		"--disable-gpu-compositing", WINDOW_SIZE, START_URL, NULL };
	return Spawn(argv);
}


static team_id
LaunchBrowser()
{
	setenv("RCH_NO_TOOLBAR", "1", 1);

	const char* home = getenv("HOME");
	if (home == NULL)
		home = "/boot/home";

	char nonPackaged[B_PATH_NAME_LENGTH];
	snprintf(nonPackaged, sizeof(nonPackaged),
		"%s/config/non-packaged/apps/RChromium", home);
	char homeDir[B_PATH_NAME_LENGTH];
	snprintf(homeDir, sizeof(homeDir), "%s/RChromium", home);

	const char* dirs[] = { "/boot/system/apps/RChromium", nonPackaged,
		homeDir, NULL };
	for (int i = 0; dirs[i] != NULL; i++) {
		team_id team = LaunchFrom(dirs[i]);
		if (team >= 0)
			return team;
	}
	return B_ENTRY_NOT_FOUND;
}


class App : public BApplication {
public:
	App()
		:
		BApplication(APP_SIGNATURE),
		fBrowser(-1),
		fRunner(NULL)
	{
	}

	virtual ~App()
	{
		delete fRunner;
	}

	virtual void ReadyToRun()
	{
		fBrowser = LaunchBrowser();
		if (fBrowser < 0) {
#if defined(__i386__)
			const char* package = "rchromium_x86";
#else
			const char* package = "rchromium";
#endif
			char text[256];
			snprintf(text, sizeof(text),
				"R Twitter needs R Chromium, which is not installed.\n\n"
				"pkgman install %s", package);
			BAlert* alert = new BAlert(APP_TITLE, text, "OK", NULL, NULL,
				B_WIDTH_AS_USUAL, B_STOP_ALERT);
			alert->Go();
			Quit();
			return;
		}

		BMessage watch(kMsgWatch);
		fRunner = new BMessageRunner(BMessenger(this), &watch, kWatchInterval);
	}

	virtual void MessageReceived(BMessage* message)
	{
		switch (message->what) {
			case kMsgWatch:
				Watch();
				break;
			case B_SILENT_RELAUNCH:
				Activate();
				break;
			default:
				BApplication::MessageReceived(message);
		}
	}

private:
	void Watch()
	{
		team_info info;
		if (get_team_info(fBrowser, &info) != B_OK) {
			Quit();
			return;
		}

		// Not registered with the roster yet while content_shell starts up.
		BMessenger browser(NULL, fBrowser);
		if (!browser.IsValid())
			return;

		int32 count = WindowCount(browser);
		for (int32 i = 0; i < count; i++) {
			BMessage get(B_GET_PROPERTY);
			get.AddSpecifier("Title");
			get.AddSpecifier("Window", i);
			BMessage reply;
			const char* title;
			if (browser.SendMessage(&get, &reply, kScriptTimeout,
					kScriptTimeout) != B_OK
				|| reply.FindString("result", &title) != B_OK
				|| strcmp(title, "R Chromium") != 0) {
				continue;
			}

			BMessage set(B_SET_PROPERTY);
			set.AddString("data", APP_TITLE);
			set.AddSpecifier("Title");
			set.AddSpecifier("Window", i);
			browser.SendMessage(&set, &reply, kScriptTimeout, kScriptTimeout);
		}
	}

	void Activate()
	{
		BMessenger browser(NULL, fBrowser);
		if (!browser.IsValid() || WindowCount(browser) <= 0)
			return;

		BMessage set(B_SET_PROPERTY);
		set.AddBool("data", true);
		set.AddSpecifier("Active");
		set.AddSpecifier("Window", (int32)0);
		BMessage reply;
		browser.SendMessage(&set, &reply, kScriptTimeout, kScriptTimeout);
	}

	static int32 WindowCount(const BMessenger& browser)
	{
		BMessage count(B_COUNT_PROPERTIES);
		count.AddSpecifier("Window");
		BMessage reply;
		int32 result;
		if (browser.SendMessage(&count, &reply, kScriptTimeout,
				kScriptTimeout) != B_OK
			|| reply.FindInt32("result", &result) != B_OK) {
			return 0;
		}
		return result;
	}

	team_id			fBrowser;
	BMessageRunner*	fRunner;
};


int
main()
{
	App app;
	app.Run();
	return 0;
}
