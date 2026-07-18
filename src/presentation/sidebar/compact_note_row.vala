namespace Knotes {

    public class CompactNoteRow : Gtk.ListBoxRow {
        private Gtk.Label avatar_label;
        private SidebarItemInteractions interactions;

        public string note_id { get; construct; }

        public signal void move_requested(SidebarDragItem item);

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
            interactions = new SidebarItemInteractions(this, SidebarDragItem.note(note.id));
            interactions.move_requested.connect((item) => move_requested(item));
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
            for (var index = 0; index < 2 && cursor.length > 0; index++) {
                var character = cursor.get_char(0);
                avatar_text.append_unichar(character.toupper());
                cursor = cursor.next_char();
            }

            return avatar_text.str;
        }

    }
}
