# R Twitter is a small launcher for R Chromium, so it has no toolkit
# dependency: the default compiler builds it (gcc2 on an x86_gcc2 hybrid).
CXX ?= g++
CXXFLAGS ?= -O2 -Wall

BUILD_DIR ?= build
APP := $(BUILD_DIR)/RTwitter
RESOURCE := $(BUILD_DIR)/RTwitter.rsrc
INSTALL_DIR ?= $(HOME)/config/non-packaged/apps/RTwitter
DESKTOP_DIR ?= $(HOME)/Desktop
DESKBAR_DIR ?= $(HOME)/config/settings/deskbar/menu/Applications

.PHONY: all install run clean

all: $(APP)

$(APP): src/main.cpp RTwitter.rdef assets/RTwitter.hvif
	mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -o $(APP) src/main.cpp -lbe
	rc -o $(RESOURCE) RTwitter.rdef
	xres -o $(APP) $(RESOURCE)
	mimeset -f $(APP)
	@# mimeset only copies resources into attributes when the registrar sniffs
	@# the file as an application, which is not reliable; write them directly.
	addattr -t mime BEOS:TYPE application/x-vnd.Be-elfexecutable $(APP)
	addattr -t mime BEOS:APP_SIG application/x-vnd.rainygirl-RTwitter $(APP)
	addattr -f assets/RTwitter.hvif -c VICN BEOS:ICON $(APP)

install: $(APP)
	mkdir -p $(INSTALL_DIR)
	cp $(APP) $(INSTALL_DIR)/RTwitter
	mimeset -f $(INSTALL_DIR)/RTwitter
	mkdir -p $(DESKTOP_DIR) $(DESKBAR_DIR)
	rm -f "$(DESKTOP_DIR)/R Twitter" "$(DESKBAR_DIR)/R Twitter"
	cp $(INSTALL_DIR)/RTwitter "$(DESKTOP_DIR)/R Twitter"
	cp $(INSTALL_DIR)/RTwitter "$(DESKBAR_DIR)/R Twitter"
	mimeset -f "$(DESKTOP_DIR)/R Twitter"
	mimeset -f "$(DESKBAR_DIR)/R Twitter"

run: $(APP)
	./$(APP)

clean:
	rm -rf $(BUILD_DIR)
