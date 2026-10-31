project('claude-agents-indicator', 'vala', 'c', version: '0.2.1')

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
    'src/core/TerminalFocus.vala',
    'src/core/Usage.vala',
    dependencies: glib_deps,
    pic: true,
)
core_dep = declare_dependency(link_with: core, dependencies: glib_deps)

wingpanel_dep = dependency('wingpanel')
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

test('core', executable(
    'core-test',
    'tests/CoreTest.vala',
    dependencies: [core_dep, meson.get_compiler('vala').find_library('posix')],
))
