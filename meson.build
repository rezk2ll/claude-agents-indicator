project('claude-agents-indicator', 'vala', 'c', version: '0.2.1')

gnome = import('gnome')

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
    'src/Indicator.vala',
    'src/Session.vala',
    'src/SessionMonitor.vala',
    'src/Desktop.vala',
    'src/Notifier.vala',
    'src/Preferences.vala',
    'src/Usage.vala',
    'src/Widgets/UsageWidget.vala',
    'src/Widgets/PanelWidget.vala',
    'src/Widgets/PopoverWidget.vala',
    'src/Widgets/SessionRow.vala',
    'src/Widgets/SwitchModelButton.vala',
    resources,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('gio-2.0'),
        dependency('gtk+-3.0'),
        dependency('json-glib-1.0'),
        wingpanel_dep,
    ],
    install: true,
    install_dir: indicators_dir,
)
