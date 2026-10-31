# Contributing

Bug reports, fixes and small features are welcome. For anything bigger, open an issue first so we can agree on the approach before you write it.

## Build and try your change

Install the build dependencies listed in the [README](README.md#build-from-source), then:

```sh
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
killall io.elementary.wingpanel
```

Wingpanel restarts and loads your build. To see the indicator's log messages, run the panel from a terminal:

```sh
killall io.elementary.wingpanel; G_MESSAGES_DEBUG=all io.elementary.wingpanel
```

To check the Debian package the way CI does:

```sh
dpkg-buildpackage -b -us -uc
```

## Code style

- Follow the [elementary Vala code style](https://docs.elementary.io/develop/writing-apps/code-style): 4 spaces, a space before the opening parenthesis of a call, `PascalCase` for classes and `snake_case` for everything else.
- Keep the indicator light. It runs inside the panel, so avoid blocking I/O on the main loop.
- One change per pull request, with a commit message that says why.

## Pull requests

- CI builds the `.deb` in an elementary OS 8 container and installs it. It must pass.
- For a visible change, attach a screenshot of the panel or the popover.
- Only elementary OS 8 is tested. If you run Pantheon on another distro, say which one in the PR.

## Releases

The maintainer bumps the version in `meson.build` and `debian/changelog`, then pushes a `v<version>` tag. CI attaches the `.deb` to the GitHub release, and the same version is uploaded to the PPA.

## Code of conduct

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md).
