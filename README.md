# cl-utilitools

***Handy CLI Utilities written in [Common Lisp][commonlisp]**

This repository contains some miscellaneous command-line utilities written in
Common Lisp, as well as the scaffolding to compile them to executables.

It's inspired by [this blog post][blogpost] by Steve Losh, from whom I borrowed
much of it. I've added a template file and simplified the [Makefile](./Makefile)
somewhat. Over time, I'll be adding my own utilities to this project as well.

## Compiling and using the tools

To compile the tools in the repo, you'll need [sbcl][sbcl] to be present on
your system. If it's not in your path, provide an argument for the `LISP`
environment variable when invoking `make`.

To build the tools into the `bin/` and `man/` folders, simply run the command:

```shell
make
```

To install them to a system-wide folder (by default `$HOME/.local`), run the
command:

```shell
make install
```

To override the install folder, provide a prefix to the `make` comamnd, like so:

```shell
prefix=/usr/local make install
```

To uninstall the things installed by the `make install` command, run `make uninstall`
as above (if you supplied a `prefix=` argument to `make install`, you'll need to
provide the same to the `make uninstall`.)

## Contributing

I value your feedback. Share your criticisms or complaints constructively to help
the project improve.

- For urgent matters, contact [@tammymakesthings][tammy].
- This project is licensed under the [MIT License][license].
- This project follows the [Contributor Covenant][cc] for all interactions
  in the project's ecosystem.

[blogpost]: <https://stevelosh.com/blog/2021/03/small-common-lisp-cli-programs/>
[cc]: <https://www.contributor-covenant.org/version/2/1/code_of_conduct/>
[commonlisp]: <https://en.wikipedia.org/wiki/Common_Lisp>
[license]: <https://opensource.org/license/mit/>
[sbcl]: <https://sbcl.org/>
[tammy]: <https://github.com/tammymakesthings>
