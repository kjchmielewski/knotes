namespace Knotes {

    [GtkTemplate(ui = "/com/knotes/app/main_window.ui")]
    public class MainWindow : Adw.ApplicationWindow {
        private const int DEFAULT_SIDEBAR_WIDTH = 250;
        private const int COMPACT_SIDEBAR_WIDTH = 64;
        private const int MIN_EXPANDED_SIDEBAR_WIDTH = 160;
        private const string SIDEBAR_TOGGLE_ICON_NAME = "sidebar-show-symbolic";

        [GtkChild]
        private unowned Gtk.Paned main_paned;
        [GtkChild]
        private unowned Gtk.Button header_new_button;
        [GtkChild]
        private unowned Gtk.Button header_new_folder_button;
        [GtkChild]
        private unowned Gtk.Button header_rename_folder_button;
        [GtkChild]
        private unowned Gtk.Button header_delete_folder_button;
        [GtkChild]
        private unowned Gtk.ToggleButton sidebar_toggle_button;
        [GtkChild]
        private unowned Gtk.MenuButton header_menu_button;

        private NoteService note_service;
        private NoteListBox note_list;
        private NoteEditorPane editor_pane;
        private Gtk.Box sidebar;
        private int expanded_sidebar_width = DEFAULT_SIDEBAR_WIDTH;
        private bool is_sidebar_expanded = true;

        public MainWindow(
            Gtk.Application app,
            NotebookWorkspace workspace,
            NoteService note_service,
            FolderService folder_service,
            NoteAssetService asset_service,
            bool tray_enabled
        ) {
            Object(application: app);
            this.note_service = note_service;
            hide_on_close = tray_enabled;
            build_ui(workspace, folder_service, asset_service);
            connect_signals();
        }

        public void restore_from_tray() {
            set_visible(true);
            unminimize();
            present();
        }

        public bool should_hide_to_tray() {
            return visible && !is_suspended();
        }

        public void force_close() {
            hide_on_close = false;
            close();
        }

        private void build_ui(
            NotebookWorkspace workspace,
            FolderService folder_service,
            NoteAssetService asset_service
        ) {
            var menu = new GLib.Menu();
            menu.append(_("Quit"), "app.quit");
            header_menu_button.menu_model = menu;

            sidebar = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            sidebar.add_css_class("navigation-sidebar");
            sidebar.set_size_request(DEFAULT_SIDEBAR_WIDTH, -1);
            note_list = new NoteListBox(workspace, note_service, folder_service);
            sidebar.append(note_list);

            editor_pane = new NoteEditorPane(note_service, asset_service);
            main_paned.set_start_child(sidebar);
            main_paned.set_end_child(editor_pane);
            main_paned.position = DEFAULT_SIDEBAR_WIDTH;
        }

        private void connect_signals() {
            note_list.note_selected.connect(editor_pane.select_note);
            note_list.folder_selection_changed.connect((has_folder_selection) => {
                header_rename_folder_button.sensitive = has_folder_selection;
                header_delete_folder_button.sensitive = has_folder_selection;
            });
            editor_pane.note_changed.connect(note_list.refresh_note);
            editor_pane.note_duplicated.connect(note_list.show_created_note);
            editor_pane.note_deleted.connect(note_list.refresh_after_note_deletion);
            sidebar_toggle_button.toggled.connect(on_sidebar_toggle);
            main_paned.notify["position"].connect(on_sidebar_position_changed);
            header_new_button.clicked.connect(on_new_note);
            header_new_folder_button.clicked.connect(note_list.show_new_folder_dialog);
            header_rename_folder_button.clicked.connect(note_list.show_rename_folder_dialog);
            header_delete_folder_button.clicked.connect(note_list.show_delete_folder_dialog);
        }

        private void on_new_note() {
            var note = note_service.create_note(
                _("Untitled"),
                "",
                note_list.folder_id_for_new_note()
            );
            if (note != null) {
                note_list.show_created_note(note);
            }
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
            sidebar.set_size_request(
                expanded ? MIN_EXPANDED_SIDEBAR_WIDTH : COMPACT_SIDEBAR_WIDTH,
                -1
            );
            main_paned.position = expanded ? expanded_sidebar_width : COMPACT_SIDEBAR_WIDTH;
            sidebar_toggle_button.icon_name = SIDEBAR_TOGGLE_ICON_NAME;
            sidebar_toggle_button.tooltip_text = expanded
                ? _("Collapse sidebar")
                : _("Expand sidebar");
        }

        private void on_sidebar_position_changed() {
            if (is_sidebar_expanded) {
                remember_expanded_sidebar_width();
            } else if (main_paned.position != COMPACT_SIDEBAR_WIDTH) {
                main_paned.position = COMPACT_SIDEBAR_WIDTH;
            }
        }

        private void remember_expanded_sidebar_width() {
            if (main_paned.position >= MIN_EXPANDED_SIDEBAR_WIDTH) {
                expanded_sidebar_width = main_paned.position;
            }
        }
    }
}
