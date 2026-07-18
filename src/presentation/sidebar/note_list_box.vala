using Gee;

namespace Knotes {

    [GtkTemplate(ui = "/com/knotes/app/note_list_box.ui")]
    public class NoteListBox : Gtk.Box {
        private const string SELECTED_FOLDER_CSS_CLASS = "selected-folder";

        [GtkChild]
        private unowned Gtk.Stack view_stack;
        [GtkChild]
        private unowned Gtk.ListBox compact_list_box;
        [GtkChild]
        private unowned Gtk.Entry search_entry;
        [GtkChild]
        private unowned Gtk.Button all_notes_button;
        [GtkChild]
        private unowned Gtk.Box note_tree_box;

        private NotebookWorkspace workspace;
        private NotebookCatalog catalog;
        private SidebarSelectionModel selection;
        private SidebarCommandController commands;
        private SidebarTreeView sidebar_tree;
        private HashMap<string, CompactNoteRow> compact_rows;
        private bool is_compact = false;

        public bool compact {
            get {
                return is_compact;
            }
            set {
                if (is_compact == value) {
                    return;
                }
                is_compact = value;
                view_stack.set_visible_child_name(is_compact ? "compact" : "expanded");
                select_visible_row(selection.selected_note_id);
            }
        }

        public signal void note_selected(string? id);
        public signal void folder_selection_changed(bool has_folder_selection);

        public NoteListBox(
            NotebookWorkspace workspace,
            NoteService note_service,
            FolderService folder_service
        ) {
            Object();
            this.workspace = workspace;
            catalog = workspace.catalog;
            selection = new SidebarSelectionModel(catalog);
            commands = new SidebarCommandController(catalog, note_service, folder_service);
            sidebar_tree = new SidebarTreeView(catalog);
            compact_rows = new HashMap<string, CompactNoteRow>();

            FolderButtonRenderer.configure(all_notes_button, _("All notes"));
            sidebar_tree.configure_drop_destination(all_notes_button, null);
            note_tree_box.append(sidebar_tree);
            connect_signals();
            rebuild_tree_views();
        }

        private void connect_signals() {
            search_entry.changed.connect(on_search_changed);
            compact_list_box.row_activated.connect(on_compact_row_activated);
            all_notes_button.clicked.connect(() => selection.select_folder(null));

            sidebar_tree.note_activated.connect((id) => selection.select_note(id));
            sidebar_tree.folder_activated.connect((id) => selection.select_folder(id));
            sidebar_tree.move_dialog_requested.connect((item) => {
                commands.show_move_dialog(this, item);
            });
            sidebar_tree.move_requested.connect((item, destination_folder_id) => {
                commands.move_item(this, item, destination_folder_id);
            });

            selection.note_selection_changed.connect(on_note_selection_changed);
            selection.folder_selection_changed.connect(on_folder_selection_changed);
            commands.content_changed.connect(on_content_changed);
            commands.folder_selection_requested.connect((id) => selection.select_folder(id));
            commands.folder_expansion_requested.connect(sidebar_tree.expand_path);
            commands.note_moved.connect(selection.reconcile_note);

            workspace.external_note_updated.connect(on_external_note_updated);
            workspace.external_note_deleted.connect(on_external_note_deleted);
        }

        private void rebuild_tree_views() {
            reconcile_selection();
            compact_list_box.remove_all();
            compact_rows.clear();
            sidebar_tree.rebuild();

            foreach (var note in catalog.notes_sorted_by_creation()) {
                add_compact_note_row(note);
            }

            on_search_changed();
            select_visible_row(selection.selected_note_id);
            update_folder_selection(selection.selected_folder_id);
        }

        private void reconcile_selection() {
            var note_id = selection.selected_note_id;
            if (note_id != null) {
                selection.reconcile_note(note_id);
            }
            var folder_id = selection.selected_folder_id;
            if (folder_id != null && !catalog.contains_folder(folder_id)) {
                selection.select_folder(null);
            }
        }

        private void on_content_changed() {
            sidebar_tree.expand_path(selection.selected_folder_id);
            rebuild_tree_views();
        }

        private void on_note_selection_changed(string? note_id) {
            select_visible_row(note_id);
            note_selected(note_id);
        }

        private void on_folder_selection_changed(string? folder_id) {
            update_folder_selection(folder_id);
            folder_selection_changed(folder_id != null);
        }

        private void update_folder_selection(string? folder_id) {
            all_notes_button.remove_css_class(SELECTED_FOLDER_CSS_CLASS);
            if (folder_id == null) {
                all_notes_button.add_css_class(SELECTED_FOLDER_CSS_CLASS);
            }
            sidebar_tree.select_folder(folder_id);
        }

        private void add_compact_note_row(Note note) {
            var row = new CompactNoteRow(note);
            row.move_requested.connect((item) => commands.show_move_dialog(this, item));
            compact_rows[note.id] = row;
            compact_list_box.append(row);
        }

        private void select_visible_row(string? note_id) {
            if (note_id == null) {
                sidebar_tree.select_note(null);
                compact_list_box.select_row(null);
                return;
            }

            sidebar_tree.select_note(note_id);
            compact_list_box.select_row(compact_rows[note_id]);
        }

        private void on_search_changed() {
            var query = search_entry.text.down();
            sidebar_tree.filter(query);
            foreach (var entry in compact_rows.entries) {
                var note = catalog.find_note(entry.key);
                entry.value.visible = note != null &&
                    (query.length == 0 || catalog.note_matches_query(note, query));
            }
        }

        private void on_compact_row_activated(Gtk.ListBoxRow row) {
            var note_row = row as CompactNoteRow;
            if (note_row != null) {
                selection.select_note(note_row.note_id);
            }
        }

        public void show_created_note(Note note) {
            rebuild_tree_views();
            selection.select_note(note.id);
        }

        public void refresh_note(Note note) {
            sidebar_tree.update_note(note);
            var compact_row = compact_rows[note.id];
            if (compact_row != null) {
                compact_row.update(note);
            }
            selection.reconcile_note(note.id);
            select_visible_row(selection.selected_note_id);
            on_search_changed();
        }

        public void refresh_after_note_deletion() {
            var note_id = selection.selected_note_id;
            if (note_id != null && !catalog.contains_note(note_id)) {
                selection.remove_note(note_id);
            }
            rebuild_tree_views();
        }

        private void on_external_note_updated(string id) {
            var note = workspace.find_note(id);
            if (note == null) {
                return;
            }

            if (sidebar_tree.contains_note(note.id)) {
                refresh_note(note);
            } else {
                rebuild_tree_views();
                selection.reconcile_note(id);
            }
            if (selection.selected_note_id == id) {
                note_selected(id);
            }
        }

        private void on_external_note_deleted(string id) {
            selection.remove_note(id);
            rebuild_tree_views();
        }

        public string folder_id_for_new_note() {
            return selection.selected_folder_id ?? "";
        }

        public void show_new_folder_dialog() {
            commands.show_new_folder(this, selection.selected_folder_id);
        }

        public void show_delete_folder_dialog() {
            commands.show_delete_folder(this, selection.selected_folder_id);
        }

        public void show_rename_folder_dialog() {
            commands.show_rename_folder(this, selection.selected_folder_id);
        }
    }
}
