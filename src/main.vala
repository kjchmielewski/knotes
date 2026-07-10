namespace Knotes {

    public static int main(string[] args) {
        GtkSource.init();

        Intl.setlocale(LocaleCategory.ALL, "");
        var locale_dir = Environment.get_variable("KNOTES_LOCALE_DIR") ?? LOCALE_DIR;
        Intl.bindtextdomain(GETTEXT_PACKAGE, locale_dir);
        Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain(GETTEXT_PACKAGE);

        // Check for app-specific flags and strip them from args
        // so GTK doesn't complain about unknown options.
        bool tray_enabled = false;
        bool start_minimized = false;
        var filtered_args = new List<string>();
        foreach (var arg in args) {
            if (arg == "--tray") {
                tray_enabled = true;
            } else if (arg == "--start-minimized") {
                start_minimized = true;
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

        var app = new Application(tray_enabled, start_minimized);
        return app.run(clean_args);
    }
}
