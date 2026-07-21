namespace Knotes.Tests {

    private string render_markdown(string markdown) {
        return new MarkdownRenderer().render(markdown);
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

    private void test_renders_https_html_image() {
        var html = render_markdown(
            "<img alt=\"Swifty Notes\" src=\"https://arm1.ru/img/uploaded/swift-notes-1.0.0.webp\">"
        );

        assert("<img src=\"https://arm1.ru/img/uploaded/swift-notes-1.0.0.webp\"" in html);
        assert("alt=\"Swifty Notes\"" in html);
    }

    private void test_keeps_unsafe_html_blocked() {
        var html = render_markdown("<script>alert(1)</script>");

        assert(!("<script>" in html));
        assert("&lt;script>" in html);
    }

    private void test_renders_allowed_break_and_link_tags() {
        var html = render_markdown(
            "First<br>Second <a href=\"https://example.com\">link</a>"
        );

        assert("First  <br/>" in html);
        assert("<a href=\"https://example.com\">link</a>" in html);
    }

    private void test_keeps_unsafe_link_html_blocked() {
        var html = render_markdown("<a href=\"javascript:alert(1)\">unsafe</a>");

        assert(!("<a href=" in html));
    }

    private void test_renders_images_nested_in_links() {
        var html = render_markdown(
            "<a href=\"https://flathub.org/en/apps/me.spaceinbox.swiftynotes\">" +
            "<img height=\"56\" alt=\"Get it on Flathub\" " +
            "src=\"https://flathub.org/api/badge?locale=en\"/></a> " +
            "<a href=\"https://snapcraft.io/swifty-notes\">" +
            "<img alt=\"Get it from the Snap Store\" " +
            "src=https://snapcraft.io/en/dark/install.svg /></a>"
        );

        assert("<a href=\"https://flathub.org/en/apps/me.spaceinbox.swiftynotes\">" in html);
        assert("src=\"https://flathub.org/api/badge?locale=en\"" in html);
        assert("alt=\"Get it on Flathub\"" in html);
        assert("<a href=\"https://snapcraft.io/swifty-notes\">" in html);
        assert("src=\"https://snapcraft.io/en/dark/install.svg\"" in html);
        assert("alt=\"Get it from the Snap Store\"" in html);
        assert(!("&lt;img" in html));
    }

    public static int main(string[] args) {
        Test.init(ref args);
        Test.add_func("/markdown-rendering/gfm-table", test_renders_gfm_table);
        Test.add_func("/markdown-rendering/raw-html", test_blocks_raw_html);
        Test.add_func("/markdown-rendering/empty-document", test_renders_empty_document);
        Test.add_func("/markdown-rendering/html-image", test_renders_https_html_image);
        Test.add_func("/markdown-rendering/unsafe-html", test_keeps_unsafe_html_blocked);
        Test.add_func("/markdown-rendering/allowed-break-and-link", test_renders_allowed_break_and_link_tags);
        Test.add_func("/markdown-rendering/unsafe-link", test_keeps_unsafe_link_html_blocked);
        Test.add_func("/markdown-rendering/image-link", test_renders_images_nested_in_links);
        return Test.run();
    }
}
