namespace Knotes.Tests {

    private string render_markdown(string markdown) {
        var flags = new Markdown.DocumentFlags();
        flags.enable(Markdown.Option.NOHTML);
        flags.enable(Markdown.Option.SAFELINK);
        var document = new Markdown.Document.from_gfm_string(
            markdown,
            markdown.length,
            flags
        );
        assert(document.compile(flags));

        char* rendered_markdown;
        var rendered_length = document.document(out rendered_markdown);
        return rendered_length > 0 && rendered_markdown != null
            ? ((string) rendered_markdown).dup()
            : "";
    }

    private void test_renders_gfm_table() {
        var html = render_markdown("Name | Count\n--- | ---\nApples | 3");

        assert("<table>" in html);
        assert("<th>Name" in html);
        assert("<td>Apples" in html);
    }

    private void test_blocks_raw_html() {
        var html = render_markdown(
            "Value | Description\n--- | ---\n<script>alert(1)</script> | Safe"
        );

        assert(!("<script>" in html));
        assert("&lt;script>" in html);
    }

    private void test_renders_empty_document() {
        assert(render_markdown("") == "");
    }

    public static int main(string[] args) {
        Test.init(ref args);
        Test.add_func("/markdown-rendering/gfm-table", test_renders_gfm_table);
        Test.add_func("/markdown-rendering/raw-html", test_blocks_raw_html);
        Test.add_func("/markdown-rendering/empty-document", test_renders_empty_document);
        return Test.run();
    }
}
