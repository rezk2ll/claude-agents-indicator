public class ClaudeAgents.Preferences : Object {
    public bool notifications { get; set; default = true; }

    private string path;

    construct {
        path = Path.build_filename (Environment.get_user_config_dir (), "claude-agents-indicator", "settings.ini");
        var file = new KeyFile ();
        try {
            file.load_from_file (path, KeyFileFlags.NONE);
            notifications = file.get_boolean ("indicator", "notifications");
        } catch (Error e) {
            // First run: keep defaults.
        }
        notify["notifications"].connect (save);
    }

    private void save () {
        var file = new KeyFile ();
        file.set_boolean ("indicator", "notifications", notifications);
        try {
            DirUtils.create_with_parents (Path.get_dirname (path), 0755);
            FileUtils.set_contents (path, file.to_data ());
        } catch (Error e) {
            warning ("Cannot save preferences: %s", e.message);
        }
    }
}
