files := $(wildcard *.lisp)
names := $(files:.lisp=)

.PHONY: all clean $(names)

LISP ?= sbcl
MAN_SECTION ?= man1
QUIET_REDIR :=
ifdef QUIET
QUIET_REDIR := 2>/dev/null 1>/dev/null
endif

all: $(names)

$(names): %: bin/% man/$(MAN_SECTION)/%.1

bin/%: %.lisp scripts/build-binary.sh Makefile
	$(info ===> Making executable for '$<')
	./scripts/build-binary.sh $< $@ $(QUIET_REDIR)
	mkdir -p bin
	mv $(@F) bin/

man/man1/%.1: %.lisp scripts/build-manual.sh Makefile
	$(info ===> Making man page for '$<')
	./scripts/build-manual.sh $< $@ $(QUIET_REDIR)
	mkdir -p man/$(MAN_SECTION)
	mv $(@F) man/$(MAN_SECTION)/

clean:
	$(info ===> Cleaning binary files)
	@rm -f bin/*
	$(info ===> Cleaning man pages)
	@rm -f man/$(MAN_SECTION)/*

