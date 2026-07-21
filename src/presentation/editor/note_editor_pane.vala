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
        private unowned Gtk.Button duplicate_button;
        [GtkChild]
        private unowned Gtk.Button delete_button;

        private NoteEditingSession editing_session;
        private MarkdownEditorView editor;
        private MarkdownPreviewPane preview;
        private NoteAssetImportController asset_import;
        private bool is_loading_note = false;

        public NoteEditorPane(
            NoteEditingSession editing_session,
            NoteAssetService asset_service
        ) {
            Object();
            this.editing_session = editing_session;
            editor = new MarkdownEditorView();
            preview = new MarkdownPreviewPane(asset_service);
            asset_import = new NoteAssetImportController(editor, asset_service);
            build_content_stack();
            connect_signals();
            update_highlighting_icon();
        }

        public void select_note(string? id) {
            var note = editing_session.select_note(id);
            asset_import.current_note_id = editing_session.current_note_id;
            if (note == null) {
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
            duplicate_button.clicked.connect(on_duplicate_note);
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
            if (is_loading_note) {
                return;
            }
            editing_session.update_draft(title_entry.text, editor.buffer.text);
        }

        private void on_preview_toggled() {
            if (preview_toggle_button.active) {
                preview.render(editing_session.current_note_id, editor.buffer.text);
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

        private void on_duplicate_note() {
            if (!editing_session.has_selected_note) {
                return;
            }

            var duplicate_title = _("%s (copy)").printf(editing_session.title);
            var result = editing_session.duplicate_current_note(duplicate_title);
            if (result.status == DuplicateNoteStatus.DUPLICATED) {
                return;
            }
            show_duplicate_error(result.status);
        }

        private void show_duplicate_error(DuplicateNoteStatus status) {
            var message = status == DuplicateNoteStatus.SOURCE_NOT_FOUND
                ? _("The selected note no longer exists.")
                : _("The copy could not be saved. The original note was left unchanged.");
            var dialog = new Adw.AlertDialog(_("Unable to duplicate note"), message);
            dialog.add_response("close", _("Close"));
            dialog.close_response = "close";
            dialog.present(this);
        }

        private void on_delete_note() {
            if (!editing_session.has_selected_note) {
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
                    if (dialog.choose.end(result) != 1) {
                        return;
                    }
                    if (!editing_session.delete_current_note()) {
                        return;
                    }
                    asset_import.current_note_id = null;
                    editor_stack.set_visible_child_name("empty");
                } catch (GLib.Error error) {
                    warning("Dialog failed: %s", error.message);
                }
            });
        }
    }
}
