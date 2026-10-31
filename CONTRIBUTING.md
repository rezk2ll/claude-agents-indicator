# Contributing

Bug reports, fixes and small features are welcome. For anything bigger, open an issue first so we can agree on the approach before you write it.

## Build and try your change

Install the build dependencies listed in the [README](README.md#build-from-source), then:

```sh
meson setup build --prefix=/usr
ninja -C build
meson test -C build
```

The code shared by both front ends lives in `src/core` and has no GTK dependency. `src/pantheon` is the Wingpanel indicator, `src/tray` the tray app.

To try the indicator, install your build and restart the panel. To see its log messages, run the panel from a terminal:

```sh
sudo ninja -C build install
killall io.elementary.wingpanel; G_MESSAGES_DEBUG=all io.elementary.wingpanel
```

To try the tray app, install your build too, since the tray finds its icons through the icon theme:

```sh
sudo ninja -C build install
killall claude-agents-tray; G_MESSAGES_DEBUG=all claude-agents-tray
```

You don't need the desktop you're changing it for. `tests/tray-smoke.sh build/claude-agents-tray` starts the tray against a fake `claude` and a simulated tray host and checks the menu the host sees. It needs Xvfb, `dbus-run-session` and python3-gi, and runs on any distro or in a container.

`tests/tray-xfce.sh OUTPUT_DIR` goes one step further: it runs the installed tray app inside a real XFCE panel on Xvfb, opens the menu and saves screenshots. CI runs it in an Ubuntu container and attaches the screenshots to the run.

`tests/tray-raise.sh x11|sway|kwin|gnome` starts a headless compositor, opens two terminals, clicks the session in the menu and checks that its terminal came to the front. The script header lists what each mode needs.

To check the Debian package the way CI does:

```sh
dpkg-buildpackage -b -us -uc
```

## Code style

- Follow the [elementary Vala code style](https://docs.elementary.io/develop/writing-apps/code-style): 4 spaces, a space before the opening parenthesis of a call, `PascalCase` for classes and `snake_case` for everything else.
- Keep it light. The indicator runs inside the panel, so avoid blocking I/O on the main loop.
- Anything desktop specific goes behind the `Desktop` interface, not in `src/core`.
- One change per pull request, with a commit message that says why.

## Pull requests

- CI builds the `.deb` packages in an elementary OS 8 container and installs them, builds the tray app on Ubuntu, Debian, Fedora and Arch, and runs the smoke, XFCE and raise tests. It must pass.
- For a visible change, attach a screenshot.
- Say which distro, desktop and terminal you tried it on.

## Releases

The maintainer bumps the version in `meson.build` and `debian/changelog`, then pushes a `v<version>` tag. CI attaches both `.deb` packages to the GitHub release, and the same version is uploaded to the PPA.

## Code of conduct

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md).
