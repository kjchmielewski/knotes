namespace Knotes {

    public class MarkdownEditorView : GtkSource.View {
        private const string SOURCE_STYLE_SCHEME_LIGHT = "Adwaita";
        private const string SOURCE_STYLE_SCHEME_DARK = "Adwaita-dark";

        public MarkdownEditorView() {
            var source_buffer = new GtkSource.Buffer(null);
            Object(buffer: source_buffer);
            hexpand = true;
            vexpand = true;
            wrap_mode = Gtk.WrapMode.WORD_CHAR;
            top_margin = 8;
            right_margin = 8;
            bottom_margin = 8;
            left_margin = 8;

            var language = GtkSource.LanguageManager.get_default().get_language("markdown");
            if (language == null) {
                warning("GtkSourceView Markdown language definition is unavailable");
            } else {
                source_buffer.language = language;
            }
            source_buffer.highlight_syntax = false;

            Adw.StyleManager.get_default().notify["dark"].connect(update_style_scheme);
            update_style_scheme();
        }

        public bool markdown_highlighting_enabled {
            get {
                return ((GtkSource.Buffer) buffer).highlight_syntax;
            }
            set {
                ((GtkSource.Buffer) buffer).highlight_syntax = value;
            }
        }

        private void update_style_scheme() {
            var is_dark = Adw.StyleManager.get_default().dark;
            var scheme_id = is_dark ? SOURCE_STYLE_SCHEME_DARK : SOURCE_STYLE_SCHEME_LIGHT;
            var scheme = GtkSource.StyleSchemeManager.get_default().get_scheme(scheme_id);
            if (scheme == null) {
                warning("GtkSourceView style scheme '%s' is unavailable", scheme_id);
                return;
            }
            ((GtkSource.Buffer) buffer).style_scheme = scheme;
        }
    }
}
