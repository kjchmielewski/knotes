namespace Knotes {

    public class NoteAssetImportController : GLib.Object {
        private MarkdownEditorView editor;
        private NoteAssetService asset_service;

        public string? current_note_id { get; set; }

        public NoteAssetImportController(
            MarkdownEditorView editor,
            NoteAssetService asset_service
        ) {
            this.editor = editor;
            this.asset_service = asset_service;
            connect_drop_target();
            editor.paste_clipboard.connect(on_paste_clipboard);
        }

        private void connect_drop_target() {
            var drop_target = new Gtk.DropTarget(typeof(Gdk.FileList), Gdk.DragAction.COPY);
            drop_target.drop.connect((value, x, y) => {
                var file_list = (Gdk.FileList) value.get_boxed();
                if (file_list == null || current_note_id == null) {
                    return false;
                }
                import_image_files(current_note_id, file_list.get_files());
                return true;
            });
            editor.add_controller(drop_target);
        }

        private void on_paste_clipboard() {
            if (current_note_id == null) {
                return;
            }

            var clipboard = editor.get_clipboard();
            if (clipboard.formats.contain_gtype(typeof(Gdk.Texture))) {
                Signal.stop_emission_by_name(editor, "paste-clipboard");
                import_clipboard_texture(clipboard, current_note_id);
                return;
            }
            if (clipboard.formats.contain_gtype(typeof(Gdk.FileList))) {
                Signal.stop_emission_by_name(editor, "paste-clipboard");
                import_clipboard_files(clipboard, current_note_id);
            }
        }

        private void import_clipboard_texture(Gdk.Clipboard clipboard, string note_id) {
            clipboard.read_texture_async.begin(null, (object, result) => {
                try {
                    var texture = clipboard.read_texture_async.end(result);
                    if (texture == null || current_note_id != note_id) {
                        return;
                    }
                    insert_imported_asset(
                        asset_service.import_png_bytes(note_id, texture.save_to_png_bytes()),
                        "",
                        note_id
                    );
                } catch (GLib.Error error) {
                    warning("Failed to read image from clipboard: %s", error.message);
                    present_error(_("Could not read the image from the clipboard."));
                }
            });
        }

        private void import_clipboard_files(Gdk.Clipboard clipboard, string note_id) {
            clipboard.read_value_async.begin(
                typeof(Gdk.FileList),
                Priority.DEFAULT,
                null,
                (object, result) => {
                    try {
                        unowned GLib.Value? value = clipboard.read_value_async.end(result);
                        if (value == null || current_note_id != note_id) {
                            return;
                        }
                        var file_list = (Gdk.FileList) value.get_boxed();
                        if (file_list != null) {
                            import_image_files(note_id, file_list.get_files());
                        }
                    } catch (GLib.Error error) {
                        warning("Failed to read files from clipboard: %s", error.message);
                        present_error(_("Could not read files from the clipboard."));
                    }
                }
            );
        }

        private void import_image_files(string note_id, GLib.SList<weak GLib.File> files) {
            var snippets = new Gee.ArrayList<string>();
            var errors = new Gee.ArrayList<string>();
            foreach (var file in files) {
                var result = asset_service.import_image_file(note_id, file);
                if (result.status == AssetImportStatus.IMPORTED && result.relative_path != null) {
                    snippets.add("![%s](%s)".printf(
                        markdown_alt_text(file.get_basename() ?? ""),
                        result.relative_path
                    ));
                } else {
                    errors.add(import_error_message(result.status, file.get_basename() ?? ""));
                }
            }

            if (current_note_id == note_id && !snippets.is_empty) {
                insert_text_at_cursor(join_lines(snippets));
            }
            if (!errors.is_empty) {
                present_errors(errors);
            }
        }

        private void insert_imported_asset(
            AssetImportResult result,
            string alt_text,
            string note_id
        ) {
            if (current_note_id != note_id) {
                return;
            }
            if (result.status == AssetImportStatus.IMPORTED && result.relative_path != null) {
                insert_text_at_cursor("![%s](%s)".printf(alt_text, result.relative_path));
                return;
            }
            present_error(import_error_message(result.status, ""));
        }

        private void insert_text_at_cursor(string text) {
            Gtk.TextIter selection_start;
            Gtk.TextIter selection_end;
            if (editor.buffer.get_selection_bounds(out selection_start, out selection_end)) {
                editor.buffer.delete(ref selection_start, ref selection_end);
            }
            Gtk.TextIter cursor;
            editor.buffer.get_iter_at_mark(out cursor, editor.buffer.get_insert());
            editor.buffer.insert(ref cursor, text, -1);
        }

        private string markdown_alt_text(string filename) {
            var dot_index = filename.last_index_of_char('.');
            var stem = dot_index > 0 ? filename.substring(0, dot_index) : filename;
            return stem.replace("\\", "\\\\").replace("[", "\\[").replace("]", "\\]");
        }

        private string import_error_message(AssetImportStatus status, string filename) {
            var display_name = filename.length > 0 ? " “%s”".printf(filename) : "";
            switch (status) {
                case AssetImportStatus.NOTE_NOT_FOUND:
                    return _("The selected note no longer exists.");
                case AssetImportStatus.UNSUPPORTED_TYPE:
                    return _("Unsupported image type%s.").printf(display_name);
                case AssetImportStatus.INVALID_SOURCE:
                    return _("The image%s could not be read.").printf(display_name);
                default:
                    return _("The image%s could not be saved.").printf(display_name);
            }
        }

        private string join_lines(Gee.List<string> lines) {
            var joined = new StringBuilder();
            foreach (var line in lines) {
                if (joined.len > 0) {
                    joined.append_c('\n');
                }
                joined.append(line);
            }
            return joined.str;
        }

        private void present_error(string message) {
            var messages = new Gee.ArrayList<string>();
            messages.add(message);
            present_errors(messages);
        }

        private void present_errors(Gee.List<string> messages) {
            var dialog = new Adw.AlertDialog(
                _("Some images could not be added"),
                join_lines(messages)
            );
            dialog.add_response("close", _("Close"));
            dialog.close_response = "close";
            var root = editor.get_root() as Gtk.Widget;
            if (root != null) {
                dialog.present(root);
            }
        }
    }
}
