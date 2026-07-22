using Gee;

namespace Knotes {

    public class SidebarTreeView : Gtk.Box {
        private const string SELECTED_FOLDER_CSS_CLASS = "selected-folder";
        private const string DROP_TARGET_CSS_CLASS = "move-drop-target";
        private const int TREE_LEVEL_INDENT = 8;

        private NotebookCatalog catalog;
        private HashMap<string, NoteRow> note_rows;
        private HashMap<string, Gtk.Button> folder_buttons;
        private HashMap<string, Gtk.Expander> folder_expanders;
        private ArrayList<Gtk.ListBox> note_lists;
        private ArrayList<SidebarItemInteractions> folder_interactions;
        private HashSet<string> expanded_folder_ids;
        private bool has_expansion_state = false;

        public signal void note_activated(string id);
        public signal void folder_activated(string id);
        public signal void move_dialog_requested(SidebarDragItem item);
        public signal void move_requested(
            SidebarDragItem item,
            string? destination_folder_id
        );

        public SidebarTreeView(NotebookCatalog catalog) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 2);
            this.catalog = catalog;
            note_rows = new HashMap<string, NoteRow>();
            folder_buttons = new HashMap<string, Gtk.Button>();
            folder_expanders = new HashMap<string, Gtk.Expander>();
            note_lists = new ArrayList<Gtk.ListBox>();
            folder_interactions = new ArrayList<SidebarItemInteractions>();
            expanded_folder_ids = new HashSet<string>();
            rebuild();
        }

        public void rebuild() {
            if (folder_expanders.size > 0) {
                capture_expansion_state();
                has_expansion_state = true;
            }
            remove_all_children();
            note_rows.clear();
            folder_buttons.clear();
            folder_expanders.clear();
            note_lists.clear();
            folder_interactions.clear();

            append_notes_for_folder("", this);
            foreach (var folder in catalog.child_folders(null)) {
                append_folder(folder, this);
            }
        }

        public void expand_path(string? folder_id) {
            var visited_folder_ids = new HashSet<string>();
            string? current_id = folder_id;
            while (current_id != null && !visited_folder_ids.contains(current_id)) {
                visited_folder_ids.add(current_id);
                expanded_folder_ids.add(current_id);

                var expander = folder_expanders[current_id];
                if (expander != null) {
                    expander.expanded = true;
                }

                var folder = catalog.find_folder(current_id);
                current_id = folder != null ? folder.parent_id : null;
            }
            has_expansion_state = true;
        }

        public void configure_drop_destination(
            Gtk.Widget widget,
            string? destination_folder_id
        ) {
            var drop_target = new Gtk.DropTarget(typeof(string), Gdk.DragAction.MOVE);
            drop_target.preload = true;
            drop_target.enter.connect(() => {
                if (!can_accept_current_drop(drop_target, destination_folder_id)) {
                    return (Gdk.DragAction) 0;
                }
                widget.add_css_class(DROP_TARGET_CSS_CLASS);
                return Gdk.DragAction.MOVE;
            });
            drop_target.motion.connect(() => {
                return can_accept_current_drop(drop_target, destination_folder_id)
                    ? Gdk.DragAction.MOVE
                    : (Gdk.DragAction) 0;
            });
            drop_target.leave.connect(() => widget.remove_css_class(DROP_TARGET_CSS_CLASS));
            drop_target.drop.connect((value, x, y) => {
                widget.remove_css_class(DROP_TARGET_CSS_CLASS);
                var item = SidebarDragItem.parse(value.get_string() ?? "");
                if (item == null || !item.can_drop(catalog, destination_folder_id)) {
                    return false;
                }
                move_requested(item, destination_folder_id);
                return true;
            });
            widget.add_controller(drop_target);
        }

        public bool contains_note(string id) {
            return note_rows.has_key(id);
        }

        public void update_note(Note note) {
            var row = note_rows[note.id];
            if (row == null) {
                return;
            }
            if (row.folder_id != note.folder_id) {
                rebuild();
                return;
            }
            row.update(note);
        }

        public void select_note(string? id) {
            var selected_row = id != null ? note_rows[id] : null;
            foreach (var note_list in note_lists) {
                note_list.select_row(
                    selected_row != null && selected_row.get_parent() == note_list
                        ? selected_row
                        : null
                );
            }
        }

        public void select_folder(string? id) {
            foreach (var button in folder_buttons.values) {
                button.remove_css_class(SELECTED_FOLDER_CSS_CLASS);
            }
            if (id != null && folder_buttons.has_key(id)) {
                folder_buttons[id].add_css_class(SELECTED_FOLDER_CSS_CLASS);
            }
        }

        public void filter(string query) {
            foreach (var entry in note_rows.entries) {
                var note = catalog.find_note(entry.key);
                entry.value.visible = note != null &&
                    (query.length == 0 || catalog.note_matches_query(note, query));
            }
            foreach (var entry in folder_expanders.entries) {
                entry.value.visible = query.length == 0 ||
                    catalog.folder_contains_matching_note(entry.key, query);
            }
        }

        private void remove_all_children() {
            Gtk.Widget? child = get_first_child();
            while (child != null) {
                var next_child = child.get_next_sibling();
                remove(child);
                child = next_child;
            }
        }

        private void capture_expansion_state() {
            expanded_folder_ids.clear();
            foreach (var entry in folder_expanders.entries) {
                if (entry.value.expanded) {
                    expanded_folder_ids.add(entry.key);
                }
            }
        }

        private void append_folder(Folder folder, Gtk.Box parent) {
            var children = catalog.child_folders(folder.id);
            var has_contents = children.size > 0 || catalog.folder_has_direct_notes(folder.id);
            var folder_button = FolderButtonRenderer.create(folder.name);
            folder_buttons[folder.id] = folder_button;
            folder_button.clicked.connect(() => folder_activated(folder.id));

            var interactions = new SidebarItemInteractions(
                folder_button,
                SidebarDragItem.folder(folder.id)
            );
            interactions.move_requested.connect((item) => move_dialog_requested(item));
            folder_interactions.add(interactions);
            configure_drop_destination(folder_button, folder.id);

            var expander = new Gtk.Expander(null);
            expander.expanded = has_expansion_state
                ? expanded_folder_ids.contains(folder.id)
                : has_contents;
            expander.label_widget = folder_button;
            expander.add_css_class("folder-expander");
            if (!has_contents) {
                expander.add_css_class("empty-folder-expander");
            }

            var child_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            child_box.margin_start = TREE_LEVEL_INDENT;
            append_notes_for_folder(folder.id, child_box);
            foreach (var child in children) {
                append_folder(child, child_box);
            }
            expander.child = child_box;
            expander.notify["expanded"].connect(() => {
                if (expander.expanded) {
                    expanded_folder_ids.add(folder.id);
                } else {
                    expanded_folder_ids.remove(folder.id);
                }
                has_expansion_state = true;
            });
            folder_expanders[folder.id] = expander;
            parent.append(expander);
        }

        private bool can_accept_current_drop(
            Gtk.DropTarget drop_target,
            string? destination_folder_id
        ) {
            unowned Value? value = drop_target.get_value();
            if (value == null) {
                return false;
            }
            var item = SidebarDragItem.parse(value.get_string() ?? "");
            return item != null && item.can_drop(catalog, destination_folder_id);
        }

        private void append_notes_for_folder(string folder_id, Gtk.Box parent) {
            var notes = catalog.notes_for_folder(folder_id);
            if (notes.size == 0) {
                return;
            }

            var note_list = new Gtk.ListBox();
            note_list.selection_mode = Gtk.SelectionMode.SINGLE;
            note_list.add_css_class("folder-note-list");
            note_list.row_activated.connect(on_row_activated);
            note_lists.add(note_list);
            foreach (var note in notes) {
                var row = new NoteRow(note);
                row.move_requested.connect((item) => move_dialog_requested(item));
                note_rows[note.id] = row;
                note_list.append(row);
            }
            parent.append(note_list);
        }

        private void on_row_activated(Gtk.ListBoxRow row) {
            var note_row = row as NoteRow;
            if (note_row != null) {
                note_activated(note_row.note_id);
            }
        }
    }
}
