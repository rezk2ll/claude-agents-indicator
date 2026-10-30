public enum ClaudeAgents.Category {
    ATTENTION,
    READY,
    WORKING;

    public static Category from_status (string status) {
        switch (status) {
            case "waiting":
            case "blocked":
            case "failed":
            case "error":
            case "crashed":
                return ATTENTION;
            case "idle":
            case "done":
            case "completed":
            case "stopped":
                return READY;
            default:
                return WORKING;
        }
    }

    public string to_title () {
        switch (this) {
            case ATTENTION:
                return "Needs You";
            case READY:
                return "Your Turn";
            default:
                return "Working";
        }
    }

    public string to_style_class () {
        switch (this) {
            case ATTENTION:
                return "attention";
            case READY:
                return "ready";
            default:
                return "working";
        }
    }
}

public class ClaudeAgents.Session : Object {
    public string key;
    public string id = "";
    public string session_id = "";
    public string name = "";
    public string cwd = "";
    public bool background;
    public string status = "";
    public Category category = Category.WORKING;
    public string? ai_title;
    public string? last_prompt;
    public int64 started_at;
    public int64 last_activity;
    public uint64 window_uid;
    public int pid;
    public string? terminal_id;

    public string? transcript_path;
    public int64 transcript_mtime = -1;
    public int64 transcript_searched_at;

    public Session (string key) {
        this.key = key;
    }

    public string project {
        owned get {
            return Path.get_basename (cwd);
        }
    }

    public string title {
        owned get {
            // Background sessions carry a name set at dispatch; interactive names are derived from the folder.
            if (background || ai_title == null) {
                return name != "" ? name : project;
            }
            return ai_title;
        }
    }

    public bool reachable {
        get {
            return background || terminal_id != null || window_uid != 0;
        }
    }

    public string describe_status () {
        switch (status) {
            case "waiting":
                return "waiting for you";
            case "idle":
                return "your turn";
            case "busy":
                return "working";
            default:
                return status;
        }
    }
}
