# -*- Makefile; encoding: utf-8; lexical-binding: t; fill-column: 80; -*-
##############################################################################
# Makefile for Common Lisp CLI utiltiies
# Adapted from https://stevelosh.com/blog/2021/03/small-common-lisp-cli-programs/
# Tammy Cravit, tammy@tammymakesthings.com, 2023-12-01
##############################################################################

# Locate necessary command line utilites
LISP			?= $(shell which sbcl | cut -d' ' -f1)
LISP_FORMAT		?= $(shell which lisp-format | cut -d' ' -f1)
EMACS			?= $(shell which emacs | cut -d' ' -f1)

# Where the install and uninstall comamnds should operate
prefix			?= $(HOME)/.local/bin

# Which man section should generated docs go in?
MAN_SECTION		?= 1

# =================== NO USER SERVICABLE PARTS BELOW THIS LINE ===================

# If make is involed with QUIET defined, suppress output from the build scripts
ifdef QUIET
QUIET_REDIR		:= 2>/dev/null 1>/dev/null
else
QUIET_REDIR		:=
endif

# Find all of the lisp files and generate our binary/manpage targets
LISP_FILES				:= $(wildcard *.lisp)
BIN_FILE_NAMES			:= $(subst .lisp,,$(LISP_FILES))
BIN_FILES				:= $(patsubst %.lisp,bin/%,$(LISP_FILES))
MAN_FILES				:= $(patsubst %.lisp,man/man$(MAN_SECTION)/%.$(MAN_SECTION),$(LISP_FILES))
INSTALLED_BIN_FILES		:= $(patsubst %.lisp,$(prefix)/bin/%,$(LISP_FILES))
INSTALLED_MAN_FILES		:= $(patsubst %.lisp,$(prefix)/man/man$(MAN_SECTION)/%.$(MAN_SECTION),$(LISP_FILES))

# Makefile pseudotargets
all: $(BIN_FILES) $(MAN_FILES)					## build all executables

format: $(LISP_FILES)							## format Lisp source files
ifeq ($(LISP_FORMAT),lisp-format)
	$(error lisp-format not found - formatting is disabled)
else
	$(LISP_FORMAT) -i $(LISP_FILES)
endif

clean:											## Clean build artifacts
	$(info Cleaning binary files: $(BIN_FILES))
	@rm -f $(BIN_FILES)
	$(info Cleaning man pages: $(MAN_FILES))
	@rm -f $(MAN_FILES)

help:											## Show this help
	@echo "=============================| Makefile Targets |============================="
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo "=============================================================================="
	@echo "NOTE: The 'install' and 'uninstall' targets operate on the directory tree at"
	@echo "      '$(prefix)'."
	@echo "      To change this, provide a 'prefix' argument when invoking the Makefile,"
	@echo "      such as 'make prefix=/my/other/directory'."
	@echo "=============================================================================="

config:											## Display Makefile configuration
	@echo "==========================| Makefile Configuration |=========================="
	@echo "          LISP_FILES: $(LISP_FILES)"
	@echo "           BIN_FILES: $(BIN_FILES)"
	@echo "           MAN_FILES: $(MAN_FILES)"
	@echo "      BIN_FILE_NAMES: $(BIN_FILE_NAMES)"
	@echo ""
	@echo "         LISP_FORMAT: $(LISP_FORMAT)"
	@echo "                LISP: $(LISP)"
	@echo "               EMACS: $(EMACS)"
	@echo ""
	@echo "              prefix: $(prefix)"
	@echo "         MAN_SECTION: man$(MAN_SECTION)"
	@echo " INSTALLED_BIN_FILES: $(INSTALLED_BIN_FILES)"
	@echo " INSTALLED_MAN_FILES: $(INSTALLED_MAN_FILES)"
	@echo "=============================================================================="

install: $(BIN_FILES) $(MAN_FILES)				## Install the binaries and man pages to the system
	mkdir -p "$(prefix)/bin" "$(prefix)/man/man$(MAN_SECTION)"
	$(foreach tool,$(BIN_FILE_NAMES),install -c bin/$(tool) $(prefix)/bin/$(tool) ; )
	$(foreach tool,$(BIN_FILE_NAMES),install -c man/man$(MAN_SECTION)/$(tool).$(MAN_SECTION) $(prefix)/man/man$(MAN_SECTION)/$(tool).$(MAN_SECTION) ; )

uninstall:										## Uninstall the installed binaries and man pages
	rm -f $(INSTALLED_BIN_FILES)
	rm -f $(INSTALLED_MAN_FILES)

# Make ru;es for generating a binary and manpage from a Lisp file
bin/%: %.lisp scripts/build-binary.sh Makefile
	$(info ===> Making executable for '$<')
	./scripts/build-binary.sh $< $@ $(QUIET_REDIR)
	mkdir -p bin
	mv $(@F) $@

man/man1/%.1: %.lisp scripts/build-manual.sh Makefile
	$(info ===> Making man page for '$<')
	./scripts/build-manual.sh $< $@ $(QUIET_REDIR)
	mkdir -p man/man$(MAN_SECTION)
	mv $(@F) $@

# Declare the pseudotargets as phony (not associated with source files)
.PHONY: all format clean help config install uninstall

