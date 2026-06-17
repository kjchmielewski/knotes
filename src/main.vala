namespace Knotes {

    public static int main(string[] args) {
        // Check for --tray flag and strip it from args
        // so GTK doesn't complain about unknown options
        bool tray_enabled = false;
        var filtered_args = new List<string>();
        foreach (var arg in args) {
            if (arg == "--tray") {
                tray_enabled = true;
            } else {
                filtered_args.append(arg);
            }
        }

        // Convert back to string[]
        string[] clean_args = new string[filtered_args.length()];
        int i = 0;
        foreach (var arg in filtered_args) {
            clean_args[i] = arg;
            i++;
        }

        var app = new Application(tray_enabled);
        return app.run(clean_args);
    }
}
