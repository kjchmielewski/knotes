namespace Knotes {

    [CCode (cname = "cmark_markdown_to_html", cheader_filename = "cmark.h")]
    private static extern string markdown_to_html(string markdown, size_t length, int options);

    [GtkTemplate(ui = "/com/knotes/app/main_window.ui")]
    public class MainWindow : Adw.ApplicationWindow {
        private const int DEFAULT_SIDEBAR_WIDTH = 250;
        private const int COMPACT_SIDEBAR_WIDTH = 64;
        private const int MIN_EXPANDED_SIDEBAR_WIDTH = 160;
        private const string SIDEBAR_TOGGLE_ICON_NAME = "sidebar-show-symbolic";
        private const string SOURCE_STYLE_SCHEME_LIGHT = "Adwaita";
        private const string SOURCE_STYLE_SCHEME_DARK = "Adwaita-dark";

        [GtkChild]
        private unowned Gtk.Paned main_paned;
        [GtkChild]
        private unowned Gtk.Button header_new_button;
        [GtkChild]
        private unowned Gtk.ToggleButton sidebar_toggle_button;
        [GtkChild]
        private unowned Gtk.MenuButton header_menu_button;

        [GtkChild]
        private unowned Gtk.Stack editor_stack;
        [GtkChild]
        private unowned Gtk.Entry title_entry;
        [GtkChild]
        private unowned GtkSource.View content_view;
        [GtkChild]
        private unowned Gtk.Stack content_stack;
        [GtkChild]
        private unowned WebKit.WebView markdown_preview;
        [GtkChild]
        private unowned Gtk.ToggleButton preview_toggle_button;
        [GtkChild]
        private unowned Gtk.Button delete_button;

        private NoteRepository repository;
        private NoteListBox note_list;
        private Gtk.Box sidebar;
        private int expanded_sidebar_width = DEFAULT_SIDEBAR_WIDTH;
        private bool is_sidebar_expanded = true;
        private string? current_note_id = null;
        private uint save_timeout_id = 0;

        public MainWindow(Gtk.Application app, NoteRepository repository, bool tray_enabled) {
            Object(application: app);
            this.repository = repository;
            hide_on_close = tray_enabled;
            build_ui();
            connect_signals();
        }

        private void build_ui() {
            setup_header_menu();
            setup_markdown_editor();
            setup_markdown_preview();

            // --- Sidebar ---
            sidebar = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            sidebar.add_css_class("navigation-sidebar");
            sidebar.set_size_request(DEFAULT_SIDEBAR_WIDTH, -1);

            note_list = new NoteListBox(repository);
            sidebar.append(note_list);

            main_paned.set_start_child(sidebar);
            main_paned.position = DEFAULT_SIDEBAR_WIDTH;
        }

        private void setup_markdown_editor() {
            var language = GtkSource.LanguageManager.get_default().get_language("markdown");
            if (language == null) {
                warning("GtkSourceView Markdown language definition is unavailable");
                return;
            }

            var source_buffer = content_view.buffer as GtkSource.Buffer;
            if (source_buffer == null) {
                warning("Markdown editor was created without a GtkSourceBuffer");
                return;
            }

            source_buffer.language = language;
            source_buffer.highlight_syntax = true;

            var style_manager = Adw.StyleManager.get_default();
            style_manager.notify["dark"].connect(() => update_editor_style_scheme());
            update_editor_style_scheme();
        }

        private void update_editor_style_scheme() {
            var source_buffer = content_view.buffer as GtkSource.Buffer;
            if (source_buffer == null) {
                warning("Markdown editor was created without a GtkSourceBuffer");
                return;
            }

            var style_manager = Adw.StyleManager.get_default();
            var scheme_id = style_manager.dark ? SOURCE_STYLE_SCHEME_DARK : SOURCE_STYLE_SCHEME_LIGHT;
            var scheme = GtkSource.StyleSchemeManager.get_default().get_scheme(scheme_id);
            if (scheme == null) {
                warning("GtkSourceView style scheme '%s' is unavailable", scheme_id);
                return;
            }

            source_buffer.style_scheme = scheme;
        }

        private void setup_markdown_preview() {
            markdown_preview.get_settings().enable_javascript = false;
            markdown_preview.decide_policy.connect(on_preview_decide_policy);
        }

        private bool on_preview_decide_policy(WebKit.PolicyDecision decision, WebKit.PolicyDecisionType type) {
            if (type != WebKit.PolicyDecisionType.NAVIGATION_ACTION) {
                return false;
            }

            var navigation_decision = decision as WebKit.NavigationPolicyDecision;
            if (navigation_decision == null ||
                navigation_decision.navigation_action.get_navigation_type() == WebKit.NavigationType.OTHER) {
                return false;
            }

            decision.ignore();
            return true;
        }

        private void connect_signals() {
            note_list.note_selected.connect(on_note_selected);
            sidebar_toggle_button.toggled.connect(on_sidebar_toggle);
            main_paned.notify["position"].connect(on_sidebar_position_changed);
            header_new_button.clicked.connect(on_new_note);
            delete_button.clicked.connect(on_delete_note);
            preview_toggle_button.toggled.connect(on_preview_toggled);
            title_entry.changed.connect(on_note_modified);
            content_view.buffer.changed.connect(on_note_modified);
        }

        private void setup_header_menu() {
            var menu = new GLib.Menu();
            menu.append(_("Quit"), "app.quit");
            header_menu_button.menu_model = menu;
        }

        private void on_sidebar_toggle() {
            set_sidebar_expanded(sidebar_toggle_button.active);
        }

        private void set_sidebar_expanded(bool expanded) {
            if (!expanded && is_sidebar_expanded) {
                remember_expanded_sidebar_width();
            }

            is_sidebar_expanded = expanded;
            note_list.compact = !expanded;
            sidebar.set_size_request(expanded ? MIN_EXPANDED_SIDEBAR_WIDTH : COMPACT_SIDEBAR_WIDTH, -1);
            main_paned.position = expanded ? expanded_sidebar_width : COMPACT_SIDEBAR_WIDTH;
            sidebar_toggle_button.icon_name = SIDEBAR_TOGGLE_ICON_NAME;
            sidebar_toggle_button.tooltip_text = expanded ? _("Collapse sidebar") : _("Expand sidebar");
        }

        private void on_sidebar_position_changed() {
            if (is_sidebar_expanded) {
                remember_expanded_sidebar_width();
                return;
            }

            if (main_paned.position != COMPACT_SIDEBAR_WIDTH) {
                main_paned.position = COMPACT_SIDEBAR_WIDTH;
            }
        }

        private void remember_expanded_sidebar_width() {
            if (main_paned.position >= MIN_EXPANDED_SIDEBAR_WIDTH) {
                expanded_sidebar_width = main_paned.position;
            }
        }

        public void restore_from_tray() {
            set_visible(true);
            unminimize();
            present();
        }

        public bool should_hide_to_tray() {
            return visible && !is_suspended();
        }

        /**
         * Really close the window (called from tray "Quit" action).
         */
        public void force_close() {
            hide_on_close = false;
            close();
        }

        private void on_note_selected(string? id) {
            current_note_id = id;
            if (id == null) {
                editor_stack.set_visible_child_name("empty");
                return;
            }

            var note = repository.load_note(id);
            if (note == null) {
                editor_stack.set_visible_child_name("empty");
                return;
            }

            show_note(note);
        }

        private void show_note(Note note) {
            title_entry.text = note.title;
            content_view.buffer.text = note.content;
            update_markdown_preview();
            editor_stack.set_visible_child_name("editor");
        }

        private void on_preview_toggled() {
            if (preview_toggle_button.active) {
                update_markdown_preview();
                content_stack.set_visible_child_name("preview");
                preview_toggle_button.tooltip_text = _("Edit Markdown");
                return;
            }

            content_stack.set_visible_child_name("editor");
            preview_toggle_button.tooltip_text = _("Preview Markdown");
            content_view.grab_focus();
        }

        private void update_markdown_preview() {
            var markdown = content_view.buffer.text;
            var rendered_markdown = markdown_to_html(markdown, markdown.length, 0);
            markdown_preview.load_html(build_preview_document(rendered_markdown), null);
        }

        private string build_preview_document(string rendered_markdown) {
            return """
                <!doctype html>
                <html>
                  <head>
                    <meta charset="utf-8">
                    <meta name="color-scheme" content="light dark">
                    <meta http-equiv="Content-Security-Policy"
                          content="default-src 'none'; style-src 'unsafe-inline'; img-src data:">
                    <style>
                      :root { color-scheme: light dark; }
                      body {
                        box-sizing: border-box;
                        max-width: 52rem;
                        margin: 0 auto;
                        padding: 1rem;
                        font: 1rem/1.55 system-ui, sans-serif;
                        overflow-wrap: anywhere;
                      }
                      pre, code { font-family: monospace; }
                      pre { padding: .75rem; overflow-x: auto; border-radius: .5rem; background: rgba(127, 127, 127, .14); }
                      code { background: rgba(127, 127, 127, .14); }
                      pre code { background: transparent; }
                      blockquote { margin-left: 0; padding-left: 1rem; border-left: .25rem solid rgba(127, 127, 127, .45); }
                      img { max-width: 100%%; }
                      table { border-collapse: collapse; }
                      th, td { padding: .35rem .6rem; border: 1px solid rgba(127, 127, 127, .45); }
                    </style>
                  </head>
                  <body>%s</body>
                </html>
                """.printf(rendered_markdown);
        }

        private void on_note_modified() {
            if (current_note_id == null)return;

            if (save_timeout_id > 0) {
                Source.remove(save_timeout_id);
            }

            // Debounce saves: 500ms after last keystroke
            save_timeout_id = Timeout.add(500, () => {
                save_current_note();
                save_timeout_id = 0;
                return false;
            });
        }

        private void save_current_note() {
            if (current_note_id == null)return;

            var note = repository.load_note(current_note_id);
            if (note == null)return;

            var new_title = title_entry.text;
            var new_content = content_view.buffer.text;

            // Skip save if nothing actually changed — avoids bumping
            // updated_at on mere note selection (which triggers changed
            // signals when show_note sets the entry text).
            if (note.title == new_title && note.content == new_content) {
                return;
            }

            note.title = new_title;
            note.content = new_content;
            note.updated_at = new DateTime.now_utc();
            repository.save_note(note);
            note_list.update_note(note);
        }

        private void on_delete_note() {
            if (current_note_id == null)return;

            var dialog = new Gtk.AlertDialog(
                                             _("Delete this note?")
            );
            dialog.detail = _("This action cannot be undone.");
            dialog.buttons = { _("Cancel"), _("Delete") };
            dialog.cancel_button = 0;
            dialog.default_button = 1;

            dialog.choose.begin(this, null, (obj, res) => {
                try {
                    var btn = dialog.choose.end(res);
                    if (btn == 1) {
                        var id = current_note_id;
                        current_note_id = null;
                        repository.delete_note(id);
                        note_list.remove_note(id);
                        editor_stack.set_visible_child_name("empty");
                    }
                } catch (GLib.Error e) {
                    warning("Dialog failed: %s", e.message);
                }
            });
        }

        private void on_new_note() {
            var note = new Note.with_new_content(_("Untitled"), "");
            repository.save_note(note);
            note_list.create_note(note);
        }
    }
}
