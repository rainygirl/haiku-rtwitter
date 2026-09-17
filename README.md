# R Twitter

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

Opens X (x.com) in its own window on Haiku, using
[R Chromium](https://github.com/rainygirl/haiku-rchromium-x86) without the
browser toolbar. No Qt needed.

![R Twitter on Haiku](docs/screenshot.png)

## Install with pkgman

On 32-bit x86 Haiku (x86_gcc2):

```sh
pkgman add-repo https://pkgman.rainygirl.com/x86_gcc2
pkgman install rtwitter        # also installs rchromium_x86 (~200 MB)
```

Then start **R Twitter** from Deskbar -> Applications.

If `pkgman add-repo` fails with `Operation not supported`, the network kit of
that image has no TLS; use `http://pkgman.rainygirl.com/x86_gcc2` instead.

## Install from source

R Chromium must already be installed. On the Haiku machine:

```sh
make
make install        # R Twitter on the Desktop and in Deskbar -> Applications
```

Note: sign-in to x.com is not kept after the window closes.

## AI disclosure

Parts of R Twitter were developed with the assistance of AI coding tools
(Anthropic's Claude). All code has been reviewed and tested by the author.

## License

MIT. The Twitter logo in `assets/` is Apache 2.0 (see `assets/NOTICE`); Twitter
and its bird logo are trademarks of their owner. Development notes are in
[AGENTS.md](AGENTS.md).
