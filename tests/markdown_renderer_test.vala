namespace Knotes.Tests {

    private void test_renders_table() {
        var html = MarkdownRenderer.render("Name | Count\n--- | ---\nApples | 3");

        assert("<table>" in html);
        assert("<th>Name</th>" in html);
        assert("<th>Count</th>" in html);
        assert("<td>Apples</td>" in html);
        assert("<td>3</td>" in html);
    }

    private void test_renders_alignment_and_inline_markdown() {
        var html = MarkdownRenderer.render(
            "| Name | Count |\n| :--- | ---: |\n| **Apples** | `3` |"
        );

        assert("<th align=\"left\">Name</th>" in html);
        assert("<th align=\"right\">Count</th>" in html);
        assert("<strong>Apples</strong>" in html);
        assert("<code>3</code>" in html);
    }

    private void test_handles_escaped_pipes_and_missing_cells() {
        var html = MarkdownRenderer.render(
            "| Value | Description |\n| --- | --- |\n| A\\|B |\n"
        );

        assert("<td>A|B</td>" in html);
        assert("<td></td>" in html);
    }

    private void test_does_not_render_table_inside_fenced_code() {
        var html = MarkdownRenderer.render(
            "```\n```not a closing fence\nName | Count\n--- | ---\nApples | 3\n```"
        );

        assert(!("<table>" in html));
        assert("Name | Count" in html);
    }

    private void test_does_not_allow_raw_html_from_cells() {
        var html = MarkdownRenderer.render(
            "Value | Description\n--- | ---\n<script>alert(1)</script> | Safe"
        );

        assert(!("<script>" in html));
        assert("raw HTML omitted" in html);
    }

    private void test_preserves_surrounding_markdown() {
        var html = MarkdownRenderer.render(
            "# Inventory\n\nName | Count\n--- | ---\nApples | 3\n\nAfter table."
        );

        assert("<h1>Inventory</h1>" in html);
        assert("<table>" in html);
        assert("<p>After table.</p>" in html);
    }

    public static int main(string[] args) {
        Test.init(ref args);
        Test.add_func("/markdown-renderer/table", test_renders_table);
        Test.add_func("/markdown-renderer/alignment-and-inline", test_renders_alignment_and_inline_markdown);
        Test.add_func("/markdown-renderer/escaped-pipe-and-missing-cell", test_handles_escaped_pipes_and_missing_cells);
        Test.add_func("/markdown-renderer/fenced-code", test_does_not_render_table_inside_fenced_code);
        Test.add_func("/markdown-renderer/raw-html-safety", test_does_not_allow_raw_html_from_cells);
        Test.add_func("/markdown-renderer/surrounding-markdown", test_preserves_surrounding_markdown);
        return Test.run();
    }
}
