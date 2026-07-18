namespace Knotes {

    public class MarkdownPreviewPane : Gtk.Box {
        private const string ASSET_URI_SCHEME = "knotes-asset";

        private NoteAssetService asset_service;
        private WebKit.WebView web_view;
        private string? current_note_id;

        public MarkdownPreviewPane(NoteAssetService asset_service) {
            Object(orientation: Gtk.Orientation.VERTICAL);
            this.asset_service = asset_service;
            web_view = new WebKit.WebView();
            web_view.hexpand = true;
            web_view.vexpand = true;
            append(web_view);
            configure_web_view();
        }

        public void render(string? note_id, string markdown) {
            current_note_id = note_id;
            var flags = new Markdown.DocumentFlags();
            flags.enable(Markdown.Option.NOHTML);
            flags.enable(Markdown.Option.SAFELINK);
            var document = new Markdown.Document.from_gfm_string(
                markdown,
                markdown.length,
                flags
            );
            if (!document.compile(flags)) {
                warning("Failed to compile Markdown preview");
                return;
            }

            char* rendered_markdown;
            var rendered_length = document.document(out rendered_markdown);
            var rendered_html = rendered_length > 0 && rendered_markdown != null
                ? (string) rendered_markdown
                : "";
            var base_uri = note_id != null
                ? "%s://note/%s/".printf(
                    ASSET_URI_SCHEME,
                    Uri.escape_string(note_id, null, false)
                )
                : null;
            web_view.load_html(build_document(rendered_html), base_uri);
        }

        private void configure_web_view() {
            web_view.get_settings().enable_javascript = false;
            var context = web_view.get_context();
            context.register_uri_scheme(ASSET_URI_SCHEME, on_asset_uri_requested);
            var security_manager = context.get_security_manager();
            security_manager.register_uri_scheme_as_local(ASSET_URI_SCHEME);
            security_manager.register_uri_scheme_as_secure(ASSET_URI_SCHEME);
            web_view.decide_policy.connect(on_decide_policy);
        }

        private void on_asset_uri_requested(WebKit.URISchemeRequest request) {
            var components = request.get_path().split("/");
            if (components.length != 4 || components[0] != "" || components[2] != "assets") {
                request.finish_error(new GLib.IOError.INVALID_ARGUMENT("Invalid note asset URI"));
                return;
            }

            var note_id = Uri.unescape_string(components[1]);
            var filename = Uri.unescape_string(components[3]);
            if (note_id == null || filename == null || current_note_id != note_id) {
                request.finish_error(new GLib.IOError.INVALID_ARGUMENT("Invalid note asset URI"));
                return;
            }

            var content = asset_service.load_asset(note_id, "assets/" + filename);
            if (content == null) {
                request.finish_error(new GLib.IOError.NOT_FOUND("Note asset was not found"));
                return;
            }
            request.finish(
                new MemoryInputStream.from_bytes(content.bytes),
                (int64) content.bytes.get_size(),
                content.content_type
            );
        }

        private bool on_decide_policy(
            WebKit.PolicyDecision decision,
            WebKit.PolicyDecisionType type
        ) {
            if (type != WebKit.PolicyDecisionType.NAVIGATION_ACTION) {
                return false;
            }
            var navigation_decision = decision as WebKit.NavigationPolicyDecision;
            if (navigation_decision == null ||
                navigation_decision.navigation_action.get_navigation_type() == WebKit.NavigationType.OTHER) {
                return false;
            }
            decision.ignore();
            return true;
        }

        private string build_document(string rendered_markdown) {
            return """
                <!doctype html>
                <html>
                  <head>
                    <meta charset="utf-8">
                    <meta name="color-scheme" content="light dark">
                    <meta http-equiv="Content-Security-Policy"
                          content="default-src 'none'; style-src 'unsafe-inline'; img-src data: knotes-asset:">
                    <style>
                      :root { color-scheme: light dark; }
                      body { box-sizing: border-box; max-width: 52rem; margin: 0 auto; padding: 1rem; font: 1rem/1.55 system-ui, sans-serif; overflow-wrap: anywhere; }
                      pre, code { font-family: monospace; }
                      pre { padding: .75rem; overflow-x: auto; border-radius: .5rem; background: rgba(127, 127, 127, .14); }
                      code { background: rgba(127, 127, 127, .14); }
                      pre code { background: transparent; }
                      blockquote { margin-left: 0; padding-left: 1rem; border-left: .25rem solid rgba(127, 127, 127, .45); }
                      img { max-width: 100%%; }
                      table { border-collapse: collapse; }
                      th, td { padding: .35rem .6rem; border: 1px solid rgba(127, 127, 127, .45); }
                    </style>
                  </head>
                  <body>%s</body>
                </html>
                """.printf(rendered_markdown);
        }
    }
}
