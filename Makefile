files := $(wildcard *.lisp)
names := $(files:.lisp=)

.PHONY: all clean $(names)

LISP ?= sbcl
MAN_SECTION ?= man1

all: $(names)

$(names): %: bin/% man/$(MAN_SECTION)/%.1

bin/%: %.lisp build-binary.sh Makefile
	$(info ===> Making executable for '$<')
	./build-binary.sh $<
	mkdir -p bin
	mv $(@F) bin/

man/man1/%.1: %.lisp build-manual.sh Makefile
	$(info ===> Making man page for '$<')
	./build-manual.sh $<
	mkdir -p man/$(MAN_SECTION)
	mv $(@F) man/$(MAN_SECTION)/

clean:
	$(info ===> Cleaning binary files)
	@rm -f bin/*
	$(info ===> Cleaning man pages)
	@rm -f man/$(MAN_SECTION)/*

