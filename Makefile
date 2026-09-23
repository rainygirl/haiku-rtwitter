# R Twitter is a launcher script for R Chromium, so there is nothing to
# compile: `make` copies the script, makes it executable, and gives it the
# icon and type attributes Tracker and Deskbar read.
#
# It used to be 267 lines of C++ whose job was mostly renaming the browser's
# windows through BWindow scripting, because R Chromium named every window
# "R Chromium". The browser takes RCH_APP_NAME now and does it itself, which
# left a launcher with nothing to launch from.

BUILD_DIR ?= build
APP := $(BUILD_DIR)/RTwitter
INSTALL_DIR ?= $(HOME)/config/non-packaged/apps/RTwitter
DESKTOP_DIR ?= $(HOME)/Desktop
DESKBAR_DIR ?= $(HOME)/config/settings/deskbar/menu/Applications

.PHONY: all install run clean

all: $(APP)

$(APP): src/RTwitter.sh assets/RTwitter.hvif
	mkdir -p $(BUILD_DIR)
	cp src/RTwitter.sh $(APP)
	chmod +x $(APP)
	@# A script has no resource fork to mimeset, so write the attributes
	@# directly. BEOS:ICON is what Tracker and Deskbar draw; the type makes
	@# Tracker run it on a double-click rather than open it in an editor.
	addattr -t mime BEOS:TYPE text/x-shellscript $(APP)
	addattr -f assets/RTwitter.hvif -c VICN BEOS:ICON $(APP)

install: $(APP)
	mkdir -p $(INSTALL_DIR)
	cp -a $(APP) $(INSTALL_DIR)/RTwitter
	mkdir -p $(DESKTOP_DIR) $(DESKBAR_DIR)
	rm -f "$(DESKTOP_DIR)/R Twitter" "$(DESKBAR_DIR)/R Twitter"
	@# -a to carry the icon attribute across; a plain cp drops it.
	cp -a $(INSTALL_DIR)/RTwitter "$(DESKTOP_DIR)/R Twitter"
	cp -a $(INSTALL_DIR)/RTwitter "$(DESKBAR_DIR)/R Twitter"

run: $(APP)
	./$(APP)

clean:
	rm -rf $(BUILD_DIR)
