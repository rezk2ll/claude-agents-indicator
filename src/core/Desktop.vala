// What each desktop provides to find, raise and badge sessions. Every front end brings its own.
public interface ClaudeAgents.Desktop : Object {
    // Called once per poll, before any session is located.
    public abstract async void refresh_windows ();

    // Sets the session's terminal_id and window_uid, or leaves them unset when it cannot be reached.
    public abstract void locate (Session session);

    public abstract void activate (Session session, string claude_path);

    public abstract void open_agent_view (string claude_path);

    public abstract void set_dock_badge (int count);
}
