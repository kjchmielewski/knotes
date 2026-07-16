using Gee;

namespace Knotes {

    [GtkTemplate(ui = "/com/knotes/app/note_row.ui")]
    public class NoteRow : Gtk.ListBoxRow {
        [GtkChild]
        private unowned Gtk.Label title_label;
        [GtkChild]
        private unowned Gtk.Label preview_label;

        public string note_id { get; construct; }

        public NoteRow(Note note) {
            Object(note_id: note.id);
            update(note);
        }

        public void update(Note note) {
            title_label.label = note.title;
            preview_label.label = note.preview(60);
        }
    }

    public class CompactNoteRow : Gtk.ListBoxRow {
        private Gtk.Label avatar_label;

        public string note_id { get; construct; }

        public CompactNoteRow(Note note) {
            Object(note_id: note.id);

            avatar_label = new Gtk.Label(avatar_text_for_title(note.title));
            avatar_label.add_css_class("compact-note-avatar");
            avatar_label.halign = Gtk.Align.CENTER;
            avatar_label.valign = Gtk.Align.CENTER;

            var row_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            row_box.halign = Gtk.Align.CENTER;
            row_box.append(avatar_label);
            child = row_box;

            update(note);
        }

        public void update(Note note) {
            avatar_label.label = avatar_text_for_title(note.title);
            tooltip_text = note.title;
        }

        private static string avatar_text_for_title(string title) {
            var trimmed_title = title.strip();
            if (trimmed_title.length == 0) {
                return "?";
            }

            var avatar_text = new StringBuilder();
            var cursor = trimmed_title;
            for (var i = 0; i < 2 && cursor.length > 0; i++) {
                var character = cursor.get_char(0);
                avatar_text.append_unichar(character.toupper());
                cursor = cursor.next_char();
            }

            return avatar_text.str;
        }
    }

    [GtkTemplate(ui = "/com/knotes/app/note_list_box.ui")]
    public class NoteListBox : Gtk.Box {
        private const string FOLDER_ICON_NAME = "folder-symbolic";
        private const int FOLDER_ICON_SIZE = 16;

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
        private NoteRepository repository;
        private HashMap<string, Note> notes_map;
        private HashMap<string, NoteRow> rows_map;
        private HashMap<string, CompactNoteRow> compact_rows_map;
        private HashMap<string, Folder> folders_map;
        private HashMap<string, Gtk.Button> folder_buttons;
        private HashMap<string, Gtk.Widget> folder_widgets;
        private ArrayList<Gtk.ListBox> expanded_note_lists;
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

        public NoteListBox(NoteRepository repository) {
            Object();
            this.repository = repository;
            configure_folder_button(all_notes_button, _("All notes"));
            this.notes_map = new HashMap<string, Note>();
            this.rows_map = new HashMap<string, NoteRow>();
            this.compact_rows_map = new HashMap<string, CompactNoteRow>();
            this.folders_map = new HashMap<string, Folder>();
            this.folder_buttons = new HashMap<string, Gtk.Button>();
            this.folder_widgets = new HashMap<string, Gtk.Widget>();
            this.expanded_note_lists = new ArrayList<Gtk.ListBox>();
            load_folders();
            load_notes();
            connect_signals();
        }

        private void connect_signals() {
            search_entry.changed.connect(on_search_changed);
            compact_list_box.row_activated.connect(on_compact_row_activated);
            all_notes_button.clicked.connect(() => select_folder(null));
            repository.note_updated.connect(on_external_note_updated);
            repository.note_deleted.connect(on_external_note_deleted);
        }

        private void load_notes() {
            notes_map.clear();
            rows_map.clear();
            compact_list_box.remove_all();
            compact_rows_map.clear();
            selected_id = null;

            var notes = repository.list_all();
            notes.sort((a, b) => {
                return a.created_at.compare(b.created_at);
            });

            foreach (var note in notes) {
                notes_map[note.id] = note;
            }
            rebuild_tree_views();
        }

        private void load_folders() {
            folders_map.clear();
            foreach (var folder in repository.list_folders()) {
                folders_map[folder.id] = folder;
            }
            rebuild_tree_views();
        }

        private void rebuild_tree_views() {
            remove_all_children(note_tree_box);
            rows_map.clear();
            expanded_note_lists.clear();
            compact_list_box.remove_all();
            compact_rows_map.clear();
            folder_buttons.clear();
            folder_widgets.clear();

            append_notes_for_folder("", note_tree_box);

            var root_folders = child_folders(null);
            foreach (var folder in root_folders) {
                append_folder(folder, note_tree_box);
            }

            var notes = new ArrayList<Note>();
            notes.add_all(notes_map.values);
            notes.sort((a, b) => a.created_at.compare(b.created_at));
            foreach (var note in notes) {
                add_compact_note_row(note);
            }

            on_search_changed();
            select_visible_row(selected_id);
            update_folder_selection();
        }

        private void remove_all_children(Gtk.Box box) {
            Gtk.Widget? child = box.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                box.remove(child);
                child = next;
            }
        }

        private void append_folder(Folder folder, Gtk.Box parent) {
            var children = child_folders(folder.id);
            bool has_contents = children.size > 0 || folder_has_direct_notes(folder.id);

            var folder_button = create_folder_button(folder);
            folder_buttons[folder.id] = folder_button;
            folder_button.clicked.connect(() => select_folder(folder.id));

            var expander = new Gtk.Expander(null);
            expander.expanded = has_contents;
            expander.label_widget = folder_button;
            expander.add_css_class("folder-expander");
            if (!has_contents) {
                expander.add_css_class("empty-folder-expander");
            }

            var child_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            child_box.margin_start = 16;
            append_notes_for_folder(folder.id, child_box);
            foreach (var child in children) {
                append_folder(child, child_box);
            }
            expander.child = child_box;
            folder_widgets[folder.id] = expander;
            parent.append(expander);
        }

        private Gtk.Button create_folder_button(Folder folder) {
            var button = new Gtk.Button();
            configure_folder_button(button, folder.name);
            return button;
        }

        private void configure_folder_button(Gtk.Button button, string name) {
            var icon = new Gtk.Image.from_icon_name(FOLDER_ICON_NAME);
            icon.pixel_size = FOLDER_ICON_SIZE;

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

        private ArrayList<Folder> child_folders(string? parent_id) {
            var children = new ArrayList<Folder>();
            foreach (var candidate in folders_map.values) {
                bool is_child = parent_id == null
                    ? candidate.parent_id == null || !folders_map.has_key(candidate.parent_id)
                    : candidate.parent_id == parent_id;
                if (is_child) {
                    children.add(candidate);
                }
            }
            children.sort((a, b) => a.name.collate(b.name));
            return children;
        }

        private bool folder_has_direct_notes(string folder_id) {
            foreach (var note in notes_map.values) {
                if (note.folder_id == folder_id) {
                    return true;
                }
            }
            return false;
        }

        private void append_notes_for_folder(string folder_id, Gtk.Box parent) {
            var notes = new ArrayList<Note>();
            foreach (var note in notes_map.values) {
                if (note.folder_id == folder_id) {
                    notes.add(note);
                }
            }
            if (notes.size == 0) {
                return;
            }

            notes.sort((a, b) => a.created_at.compare(b.created_at));
            var note_list = new Gtk.ListBox();
            note_list.selection_mode = Gtk.SelectionMode.SINGLE;
            note_list.add_css_class("folder-note-list");
            note_list.row_activated.connect(on_row_activated);
            expanded_note_lists.add(note_list);
            foreach (var note in notes) {
                add_note_row(note, note_list);
            }
            parent.append(note_list);
        }

        private void select_folder(string? folder_id) {
            selected_folder_id = folder_id;
            update_folder_selection();
        }

        private void update_folder_selection() {
            all_notes_button.remove_css_class("suggested-action");
            if (selected_folder_id == null) {
                all_notes_button.add_css_class("suggested-action");
            }
            foreach (var entry in folder_buttons.entries) {
                entry.value.remove_css_class("suggested-action");
            }
            if (selected_folder_id != null && folder_buttons.has_key(selected_folder_id)) {
                folder_buttons[selected_folder_id].add_css_class("suggested-action");
            }
        }

        private void add_note_row(Note note, Gtk.ListBox note_list) {
            var row = new NoteRow(note);
            rows_map[note.id] = row;
            note_list.append(row);
        }

        private void add_compact_note_row(Note note) {
            var compact_row = new CompactNoteRow(note);
            compact_rows_map[note.id] = compact_row;
            compact_list_box.append(compact_row);
        }

        private void insert_note(Note note) {
            notes_map[note.id] = note;
            rebuild_tree_views();
        }

        private void select_note(string? id) {
            selected_id = id;
            select_visible_row(id);
            note_selected(id);
        }

        private void select_visible_row(string? id) {
            if (id == null) {
                foreach (var note_list in expanded_note_lists) {
                    note_list.select_row(null);
                }
                compact_list_box.select_row(null);
                return;
            }

            var row = rows_map[id];
            var compact_row = compact_rows_map[id];
            foreach (var note_list in expanded_note_lists) {
                note_list.select_row(row != null && row.get_parent() == note_list ? row : null);
            }
            compact_list_box.select_row(compact_row);
        }

        private void on_search_changed() {
            var query = search_entry.text.down();
            foreach (var entry in rows_map.entries) {
                var note = notes_map[entry.key];
                if (note == null) continue;
                bool visible = query.length == 0 || note_matches_query(note, query);
                entry.value.visible = visible;

                var compact_row = compact_rows_map[entry.key];
                if (compact_row != null) {
                    compact_row.visible = visible;
                }
            }
            foreach (var entry in folder_widgets.entries) {
                entry.value.visible = query.length == 0 || folder_contains_matching_note(
                    entry.key,
                    query,
                    new HashSet<string>()
                );
            }
        }

        private bool folder_contains_matching_note(
            string folder_id,
            string query,
            HashSet<string> visited_folder_ids
        ) {
            if (visited_folder_ids.contains(folder_id)) {
                return false;
            }
            visited_folder_ids.add(folder_id);

            foreach (var note in notes_map.values) {
                if (note.folder_id == folder_id && note_matches_query(note, query)) {
                    return true;
                }
            }
            foreach (var folder in child_folders(folder_id)) {
                if (folder_contains_matching_note(folder.id, query, visited_folder_ids)) {
                    return true;
                }
            }
            return false;
        }

        private bool note_matches_query(Note note, string query) {
            return note.title.down().contains(query) || note.content.down().contains(query);
        }

        private void on_row_activated(Gtk.ListBoxRow row) {
            var note_row = row as NoteRow;
            if (note_row != null) {
                select_note(note_row.note_id);
            }
        }

        private void on_compact_row_activated(Gtk.ListBoxRow row) {
            var compact_note_row = row as CompactNoteRow;
            if (compact_note_row != null) {
                select_note(compact_note_row.note_id);
            }
        }

        /**
         * Creates a new note and adds it to the list.
         */
        public void create_note(Note note) {
            insert_note(note);

            var row = rows_map[note.id];
            if (row != null) {
                var note_list = row.get_parent() as Gtk.ListBox;
                note_list.select_row(row);
            }

            select_note(note.id);
        }

        /**
         * Updates the note with the given ID.
         */
        public void update_note(Note note) {
            var existing_note = notes_map[note.id];
            notes_map[note.id] = note;
            if (existing_note != null && existing_note.folder_id != note.folder_id) {
                rebuild_tree_views();
                return;
            }

            var note_row = rows_map[note.id];
            if (note_row != null) {
                note_row.update(note);
            }

            var compact_note_row = compact_rows_map[note.id];
            if (compact_note_row != null) {
                compact_note_row.update(note);
            }
            on_search_changed();
        }

        /**
         * Removes the note with the given ID.
         */
        public void remove_note(string id) {
            notes_map.unset(id);
            rebuild_tree_views();
        }

        private void on_external_note_updated(string id) {
            var note = repository.load_note(id);
            if (note == null) return;

            if (rows_map.has_key(note.id)) {
                update_note(note);
            } else {
                insert_note(note);
            }

            if (selected_id == id) {
                note_selected(id);
            }
        }

        private void on_external_note_deleted(string id) {
            if (selected_id == id) {
                select_note(null);
            }
            remove_note(id);
        }

        public string folder_id_for_new_note() {
            return selected_folder_id ?? "";
        }

        public void show_new_folder_dialog() {
            var dialog = new Adw.AlertDialog(
                _("New folder"),
                _("Enter a name for the new folder.")
            );
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("create", _("Create"));
            dialog.close_response = "cancel";
            dialog.default_response = "create";

            var entry = new Gtk.Entry();
            entry.placeholder_text = _("Folder name");
            dialog.set_extra_child(entry);
            dialog.choose.begin(this, null, (obj, result) => {
                if (dialog.choose.end(result) != "create") {
                    return;
                }
                var name = entry.text.strip();
                if (name.length == 0) {
                    return;
                }
                var folder = new Folder(Uuid.string_random(), name, selected_folder_id);
                folders_map[folder.id] = folder;
                save_folders();
                rebuild_tree_views();
                select_folder(folder.id);
            });
        }

        private void save_folders() {
            var folders = new GLib.List<Folder>();
            foreach (var folder in folders_map.values) {
                folders.append(folder);
            }
            repository.save_folders(folders);
        }
    }
}
