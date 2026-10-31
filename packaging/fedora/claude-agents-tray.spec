Name:           claude-agents-tray
Version:        0.3.0
Release:        1%{?dist}
Summary:        Claude Code sessions in the system tray
License:        GPL-3.0-or-later
URL:            https://github.com/rezk2ll/claude-agents-indicator
Source0:        %{url}/archive/v%{version}/claude-agents-indicator-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  meson
BuildRequires:  vala
BuildRequires:  pkgconfig(gtk+-3.0)
BuildRequires:  pkgconfig(json-glib-1.0)
BuildRequires:  pkgconfig(ayatana-appindicator3-0.1)
BuildRequires:  desktop-file-utils
Requires:       hicolor-icon-theme
Recommends:     xdg-terminal-exec
Suggests:       tmux
Suggests:       kitty
Suggests:       wezterm
Suggests:       konsole
Suggests:       xdotool

%description
Lists live Claude Code sessions in a tray menu on any desktop with
StatusNotifierItem support, shows usage and sends notifications. A click
selects the session's terminal tab and raises its window. Includes
claude-agents-status for status bars.

%prep
%autosetup -n claude-agents-indicator-%{version}

%build
%meson -Dwingpanel=disabled -Dtray=enabled
%meson_build

%install
%meson_install

%check
%meson_test
desktop-file-validate %{buildroot}%{_datadir}/applications/claude-agents-tray.desktop

%files
%license LICENSE
%doc README.md
%{_bindir}/claude-agents-tray
%{_bindir}/claude-agents-status
%{_mandir}/man1/claude-agents-*.1*
%{_datadir}/gnome-shell/extensions/claude-agents@rezk2ll.github.io/
%{_datadir}/applications/claude-agents-tray.desktop
%{_datadir}/icons/hicolor/scalable/apps/claude-agents-tray*.svg
%config(noreplace) %{_sysconfdir}/xdg/autostart/claude-agents-tray.desktop

%changelog
* Sat Oct 31 2026 rezk2ll <6764881+rezk2ll@users.noreply.github.com> - 0.3.0-1
- First Fedora package
