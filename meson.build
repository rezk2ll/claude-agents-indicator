project('claude-agents-indicator', 'vala', 'c', version: '0.3.0')

gnome = import('gnome')

glib_deps = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('json-glib-1.0'),
]

# Session polling, usage and notifications, shared by every front end. No GTK.
core = static_library(
    'claude-agents-core',
    'src/core/Agents.vala',
    'src/core/Desktop.vala',
    'src/core/Format.vala',
    'src/core/Notifier.vala',
    'src/core/Preferences.vala',
    'src/core/Session.vala',
    'src/core/SessionMonitor.vala',
    'src/core/Summary.vala',
    'src/core/TerminalFocus.vala',
    'src/core/Usage.vala',
    'src/core/Windows.vala',
    dependencies: glib_deps,
    pic: true,
)
core_dep = declare_dependency(link_with: core, dependencies: glib_deps)

# Needs no toolkit, so status bars get it without the tray app. The tray package ships it.
executable('claude-agents-status', 'src/cli/Status.vala', dependencies: core_dep, install: true)
install_man('data/man/claude-agents-status.1')

wingpanel_dep = dependency('wingpanel', required: get_option('wingpanel'))
if wingpanel_dep.found()
    indicators_dir = wingpanel_dep.get_variable(
        'indicatorsdir',
        pkgconfig_define: ['libdir', get_option('prefix') / get_option('libdir')],
    )

    resources = gnome.compile_resources(
        'claude-agents-resources',
        'data/claude-agents.gresource.xml',
        source_dir: 'data',
    )

    shared_module(
        meson.project_name(),
        'src/pantheon/Indicator.vala',
        'src/pantheon/PantheonDesktop.vala',
        'src/pantheon/Widgets/UsageWidget.vala',
        'src/pantheon/Widgets/PanelWidget.vala',
        'src/pantheon/Widgets/PopoverWidget.vala',
        'src/pantheon/Widgets/SessionRow.vala',
        'src/pantheon/Widgets/SwitchModelButton.vala',
        resources,
        dependencies: [
            core_dep,
            dependency('gtk+-3.0'),
            wingpanel_dep,
        ],
        install: true,
        install_dir: indicators_dir,
    )
endif

appindicator_dep = dependency('ayatana-appindicator3-0.1', required: get_option('tray'))
if appindicator_dep.found()
    executable(
        'claude-agents-tray',
        'src/tray/Tray.vala',
        'src/tray/GenericDesktop.vala',
        dependencies: [core_dep, dependency('gtk+-3.0'), appindicator_dep],
        install: true,
    )
    install_man('data/man/claude-agents-tray.1')
    install_data('data/claude-agents-tray.desktop', install_dir: get_option('datadir') / 'applications')
    install_data('data/claude-agents-tray.desktop', install_dir: get_option('sysconfdir') / 'xdg' / 'autostart')
    install_data(
        'data/icons/tray/claude-agents-tray.svg',
        'data/icons/tray/claude-agents-tray-attention.svg',
        install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
    )
    gnome.post_install(gtk_update_icon_cache: true)
endif

test('core', executable(
    'core-test',
    'tests/CoreTest.vala',
    dependencies: [core_dep, meson.get_compiler('vala').find_library('posix')],
))
