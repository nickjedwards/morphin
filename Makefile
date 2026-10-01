# The shell is plain QML: installing it is copying the tree and stamping the
# name and paths into the launcher, the systemd unit and common/Meta.qml.
#
#   make install                        to /usr/local
#   make install PREFIX=/usr DESTDIR=…  for a package
#   make install PREFIX=~/.local        just for you
#   make install NAME=other             under another name
#   make check                          stage an install and start it briefly

NAME ?= morphin
PREFIX ?= /usr/local
QS ?= qs

BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share
PKGDATADIR ?= $(DATADIR)/$(NAME)
DOCDIR ?= $(DATADIR)/doc/$(NAME)
LICENSEDIR ?= $(DATADIR)/licenses/$(NAME)
SYSTEMDUSERUNITDIR ?= $(PREFIX)/lib/systemd/user

# The shell itself lives in quickshell/; everything in it is installed, with
# paths relative to that folder.
SRC := quickshell
QML_FILES := $(shell cd $(SRC) && find . -type f \( -name '*.qml' -o -name '*.js' \) | sed 's|^\./||' | sort)

SUBST = sed \
	-e 's|@NAME@|$(NAME)|g' \
	-e 's|@PKGDATADIR@|$(PKGDATADIR)|g' \
	-e 's|@BINDIR@|$(BINDIR)|g' \
	-e 's|@DOCDIR@|$(DOCDIR)|g' \
	-e 's|@QS@|$(QS)|g'

.PHONY: all install uninstall check clean

all:
	@echo "Nothing to build. Try: make install, make check"

install:
	@for f in $(QML_FILES); do \
		install -Dm644 "$(SRC)/$$f" "$(DESTDIR)$(PKGDATADIR)/$$f" || exit 1; \
	done
	# The installed copy knows its name, and that it's installed.
	sed -i \
		-e 's|readonly property string name: ".*"|readonly property string name: "$(NAME)"|' \
		-e 's|readonly property bool installed: .*|readonly property bool installed: true|' \
		"$(DESTDIR)$(PKGDATADIR)/common/Meta.qml"
	install -d "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(SYSTEMDUSERUNITDIR)"
	$(SUBST) dist/launcher.in > "$(DESTDIR)$(BINDIR)/$(NAME)"
	chmod 755 "$(DESTDIR)$(BINDIR)/$(NAME)"
	$(SUBST) dist/service.in > "$(DESTDIR)$(SYSTEMDUSERUNITDIR)/$(NAME).service"
	chmod 644 "$(DESTDIR)$(SYSTEMDUSERUNITDIR)/$(NAME).service"
	install -Dm644 README.md "$(DESTDIR)$(DOCDIR)/README.md"
	install -Dm644 LICENSE "$(DESTDIR)$(LICENSEDIR)/LICENSE"

uninstall:
	rm -rf "$(DESTDIR)$(PKGDATADIR)" "$(DESTDIR)$(DOCDIR)" "$(DESTDIR)$(LICENSEDIR)"
	rm -f "$(DESTDIR)$(BINDIR)/$(NAME)" "$(DESTDIR)$(SYSTEMDUSERUNITDIR)/$(NAME).service"

# Needs a running Wayland session. Starts the staged copy under its own
# name for a few seconds (a second island appears briefly) and fails if the
# configuration doesn't load. Notification/polkit "already registered"
# warnings are expected while another shell is running.
CHECKDIR := .check
check:
	rm -rf $(CHECKDIR)
	$(MAKE) --no-print-directory install DESTDIR=$(CURDIR)/$(CHECKDIR) PREFIX=/usr NAME=$(NAME)-check
	@log=$(CHECKDIR)/qs.log; root=$(CURDIR)/$(CHECKDIR); \
	XDG_CONFIG_HOME=$$root/config XDG_STATE_HOME=$$root/state \
	XDG_CACHE_HOME=$$root/cache XDG_DATA_HOME=$$root/data \
	timeout 8 $(QS) -p $$root/usr/share/$(NAME)-check > $$log 2>&1 || true; \
	rm -rf "$${XDG_RUNTIME_DIR:-/nonexistent}/$(NAME)-check"; \
	if grep -q "Configuration Loaded" $$log && ! grep -qE "ERROR|TypeError|ReferenceError" $$log; then \
		echo "check: loaded cleanly"; \
	else \
		echo "check: FAILED"; grep -E "ERROR|WARN|Error" $$log; exit 1; \
	fi
	rm -rf $(CHECKDIR)

clean:
	rm -rf $(CHECKDIR)
