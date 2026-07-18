namespace Knotes {

    [GtkTemplate(ui = "/com/knotes/app/note_editor_pane.ui")]
    public class NoteEditorPane : Gtk.Box {
        private const string PLAIN_TEXT_ICON_LIGHT_RESOURCE =
            "/com/knotes/app/icons/format-text-rich-symbolic-light.svg";
        private const string PLAIN_TEXT_ICON_DARK_RESOURCE =
            "/com/knotes/app/icons/format-text-rich-symbolic-dark.svg";

        [GtkChild]
        private unowned Gtk.Stack editor_stack;
        [GtkChild]
        private unowned Gtk.Entry title_entry;
        [GtkChild]
        private unowned Gtk.Stack content_stack;
        [GtkChild]
        private unowned Gtk.ToggleButton markdown_highlighting_toggle_button;
        [GtkChild]
        private unowned Gtk.Image markdown_highlighting_icon;
        [GtkChild]
        private unowned Gtk.ToggleButton preview_toggle_button;
        [GtkChild]
        private unowned Gtk.Button delete_button;

        private NoteService note_service;
        private MarkdownEditorView editor;
        private MarkdownPreviewPane preview;
        private NoteAssetImportController asset_import;
        private AutosaveCoordinator autosave;
        private string? current_note_id;
        private bool is_loading_note = false;

        public signal void note_changed(Note note);
        public signal void note_deleted();

        public NoteEditorPane(NoteService note_service, NoteAssetService asset_service) {
            Object();
            this.note_service = note_service;
            editor = new MarkdownEditorView();
            preview = new MarkdownPreviewPane(asset_service);
            asset_import = new NoteAssetImportController(editor, asset_service);
            autosave = new AutosaveCoordinator(save_current_note);
            build_content_stack();
            connect_signals();
            update_highlighting_icon();
        }

        public void select_note(string? id) {
            if (current_note_id != id) {
                autosave.flush();
            }
            current_note_id = id;
            asset_import.current_note_id = id;
            if (id == null) {
                editor_stack.set_visible_child_name("empty");
                return;
            }

            var note = note_service.find_note(id);
            if (note == null) {
                current_note_id = null;
                asset_import.current_note_id = null;
                editor_stack.set_visible_child_name("empty");
                return;
            }
            show_note(note);
        }

        private void build_content_stack() {
            var editor_scroll = new Gtk.ScrolledWindow();
            editor_scroll.child = editor;
            content_stack.add_named(editor_scroll, "editor");
            content_stack.add_named(preview, "preview");
            content_stack.set_visible_child_name("editor");
        }

        private void connect_signals() {
            title_entry.changed.connect(on_note_modified);
            editor.buffer.changed.connect(on_note_modified);
            delete_button.clicked.connect(on_delete_note);
            preview_toggle_button.toggled.connect(on_preview_toggled);
            markdown_highlighting_toggle_button.toggled.connect(on_highlighting_toggled);
            Adw.StyleManager.get_default().notify["dark"].connect(update_highlighting_icon);
        }

        private void show_note(Note note) {
            is_loading_note = true;
            title_entry.text = note.title;
            editor.buffer.text = note.content;
            is_loading_note = false;
            if (preview_toggle_button.active) {
                preview.render(note.id, note.content);
            }
            editor_stack.set_visible_child_name("editor");
        }

        private void on_note_modified() {
            if (current_note_id == null || is_loading_note) {
                return;
            }
            autosave.schedule();
        }

        private void save_current_note() {
            if (current_note_id == null) {
                return;
            }
            var note = note_service.find_note(current_note_id);
            if (note == null) {
                return;
            }

            var new_title = title_entry.text;
            var new_content = editor.buffer.text;
            if (note.title == new_title && note.content == new_content) {
                return;
            }
            note.title = new_title;
            note.content = new_content;
            note.updated_at = new DateTime.now_utc();
            if (note_service.save_note(note)) {
                note_changed(note);
            }
        }

        private void on_preview_toggled() {
            if (preview_toggle_button.active) {
                preview.render(current_note_id, editor.buffer.text);
                content_stack.set_visible_child_name("preview");
                preview_toggle_button.tooltip_text = _("Edit Markdown");
                return;
            }
            content_stack.set_visible_child_name("editor");
            preview_toggle_button.tooltip_text = _("Preview Markdown");
            editor.grab_focus();
        }

        private void on_highlighting_toggled() {
            editor.markdown_highlighting_enabled = markdown_highlighting_toggle_button.active;
            markdown_highlighting_toggle_button.tooltip_text = markdown_highlighting_toggle_button.active
                ? _("Plain text mode")
                : _("Enable Markdown highlighting");
        }

        private void update_highlighting_icon() {
            markdown_highlighting_icon.resource = Adw.StyleManager.get_default().dark
                ? PLAIN_TEXT_ICON_DARK_RESOURCE
                : PLAIN_TEXT_ICON_LIGHT_RESOURCE;
        }

        private void on_delete_note() {
            if (current_note_id == null) {
                return;
            }
            var dialog = new Gtk.AlertDialog(_("Delete this note?"));
            dialog.detail = _("This action cannot be undone.");
            dialog.buttons = { _("Cancel"), _("Delete") };
            dialog.cancel_button = 0;
            dialog.default_button = 1;
            var root = get_root() as Gtk.Window;
            dialog.choose.begin(root, null, (object, result) => {
                try {
                    if (dialog.choose.end(result) != 1 || current_note_id == null) {
                        return;
                    }
                    var id = current_note_id;
                    if (!note_service.delete_note(id)) {
                        return;
                    }
                    autosave.cancel();
                    current_note_id = null;
                    asset_import.current_note_id = null;
                    editor_stack.set_visible_child_name("empty");
                    note_deleted();
                } catch (GLib.Error error) {
                    warning("Dialog failed: %s", error.message);
                }
            });
        }
    }
}
