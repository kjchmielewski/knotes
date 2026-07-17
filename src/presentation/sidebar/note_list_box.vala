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
        private NotebookService notebook_service;
        private NotebookCatalog catalog;
        private FolderTreeView folder_tree;
        private FolderDialogs folder_dialogs;
        private HashMap<string, CompactNoteRow> compact_rows_map;
        private string? selected_id = null;
        private string? selected_folder_id = null;
        private bool is_compact = false;

        public bool compact {
            get {
                return is_compact;
            }
            set {
                if (is_compact == value) return;

                is_compact = value;
                view_stack.set_visible_child_name(is_compact ? "compact" : "expanded");
                select_visible_row(selected_id);
            }
        }

        public signal void note_selected(string? id);
        public signal void folder_selection_changed(bool can_delete);

        public NoteListBox(NotebookService notebook_service) {
            Object();
            this.notebook_service = notebook_service;
            configure_folder_button(all_notes_button, _("All notes"));
            this.catalog = notebook_service.catalog;
            this.compact_rows_map = new HashMap<string, CompactNoteRow>();
            this.folder_tree = new FolderTreeView(catalog);
            this.folder_dialogs = new FolderDialogs();
            note_tree_box.append(folder_tree);
            rebuild_tree_views();
            connect_signals();
        }

        private void connect_signals() {
            search_entry.changed.connect(on_search_changed);
            compact_list_box.row_activated.connect(on_compact_row_activated);
            all_notes_button.clicked.connect(() => select_folder(null));
            folder_tree.note_activated.connect(select_note);
            folder_tree.folder_activated.connect(select_folder);
            folder_dialogs.folder_creation_requested.connect(on_folder_creation_requested);
            folder_dialogs.folder_deletion_requested.connect(delete_folder);
            notebook_service.external_note_updated.connect(on_external_note_updated);
            notebook_service.external_note_deleted.connect(on_external_note_deleted);
        }

        private void rebuild_tree_views() {
            compact_list_box.remove_all();
            compact_rows_map.clear();
            folder_tree.rebuild();

            foreach (var note in catalog.notes_sorted_by_creation()) {
                add_compact_note_row(note);
            }

            on_search_changed();
            select_visible_row(selected_id);
            update_folder_selection();
        }

        private void configure_folder_button(Gtk.Button button, string name) {
            var icon = new Gtk.Image.from_icon_name("folder-symbolic");
            icon.pixel_size = 16;

            var label = new Gtk.Label(name);
            label.halign = Gtk.Align.START;
            label.hexpand = true;
            label.ellipsize = Pango.EllipsizeMode.END;
            label.xalign = 0;

            var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            content.append(icon);
            content.append(label);

            button.child = content;
            button.halign = Gtk.Align.FILL;
            button.hexpand = true;
            button.add_css_class("flat");
            button.add_css_class("folder-tree-row");
        }

        private void select_folder(string? folder_id) {
            selected_folder_id = folder_id;
            update_folder_selection();
            folder_selection_changed(folder_id != null);
            if (!selected_note_belongs_to_folder(folder_id)) {
                select_note(null);
            }
        }

        private bool selected_note_belongs_to_folder(string? folder_id) {
            if (selected_id == null) {
                return true;
            }

            var note = catalog.find_note(selected_id);
            return note != null && catalog.normalized_folder_id(note) == folder_id;
        }

        private void update_folder_selection() {
            all_notes_button.remove_css_class(SELECTED_FOLDER_CSS_CLASS);
            if (selected_folder_id == null) {
                all_notes_button.add_css_class(SELECTED_FOLDER_CSS_CLASS);
            }
            folder_tree.select_folder(selected_folder_id);
        }

        private void add_compact_note_row(Note note) {
            var compact_row = new CompactNoteRow(note);
            compact_rows_map[note.id] = compact_row;
            compact_list_box.append(compact_row);
        }

        private void select_note(string? id) {
            selected_id = id;
            if (id != null) {
                select_folder_for_note(id);
            }
            select_visible_row(id);
            note_selected(id);
        }

        private void select_folder_for_note(string note_id) {
            var note = catalog.find_note(note_id);
            if (note == null) {
                return;
            }

            select_folder(catalog.normalized_folder_id(note));
        }

        private void select_visible_row(string? id) {
            if (id == null) {
                folder_tree.select_note(null);
                compact_list_box.select_row(null);
                return;
            }

            var compact_row = compact_rows_map[id];
            folder_tree.select_note(id);
            compact_list_box.select_row(compact_row);
        }

        private void on_search_changed() {
            var query = search_entry.text.down();
            folder_tree.filter(query);
            foreach (var entry in compact_rows_map.entries) {
                var note = catalog.find_note(entry.key);
                if (note == null) continue;
                entry.value.visible = query.length == 0 || catalog.note_matches_query(note, query);
            }
        }

        private void on_compact_row_activated(Gtk.ListBoxRow row) {
            var compact_note_row = row as CompactNoteRow;
            if (compact_note_row != null) {
                select_note(compact_note_row.note_id);
            }
        }

        public void show_created_note(Note note) {
            rebuild_tree_views();
            select_note(note.id);
        }

        public void refresh_note(Note note) {
            folder_tree.update_note(note);

            var compact_note_row = compact_rows_map[note.id];
            if (compact_note_row != null) {
                compact_note_row.update(note);
            }
            on_search_changed();
        }

        public void refresh_after_note_deletion() {
            rebuild_tree_views();
        }

        private void on_external_note_updated(string id) {
            var note = notebook_service.find_note(id);
            if (note == null) return;

            if (folder_tree.contains_note(note.id)) {
                refresh_note(note);
            } else {
                rebuild_tree_views();
            }

            if (selected_id == id) {
                note_selected(id);
            }
        }

        private void on_external_note_deleted(string id) {
            if (selected_id == id) {
                select_note(null);
            }
            refresh_after_note_deletion();
        }

        public string folder_id_for_new_note() {
            return selected_folder_id ?? "";
        }

        public void show_new_folder_dialog() {
            folder_dialogs.show_new_folder(this, selected_folder_id);
        }

        public void show_delete_folder_dialog() {
            if (selected_folder_id == null) {
                return;
            }

            var folder = catalog.find_folder(selected_folder_id);
            if (folder == null) {
                select_folder(null);
                return;
            }

            folder_dialogs.show_delete_folder(this, folder);
        }

        private void on_folder_creation_requested(string name, string? parent_id) {
            var folder = notebook_service.create_folder(name, parent_id);
            if (folder == null) {
                return;
            }
            rebuild_tree_views();
            select_folder(folder.id);
        }

        private void delete_folder(Folder folder) {
            string? parent_id = folder.parent_id != null && catalog.contains_folder(folder.parent_id)
                ? folder.parent_id
                : null;
            if (!notebook_service.delete_folder(folder.id)) {
                select_folder(null);
                return;
            }
            select_folder(parent_id);
            rebuild_tree_views();
        }
    }
}
