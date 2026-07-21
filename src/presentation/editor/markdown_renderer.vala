namespace Knotes {

    public class MarkdownRenderer : Object {
        private const string ALLOWED_TAG_PATTERN = "(?is)<img\\b[^>]*>|<br\\s*/?>|<a\\b[^>]*>.*?</a\\s*>";
        private const string IMAGE_TAG_PATTERN = "(?is)^<img\\b[^>]*>$";
        private const string IMAGE_ATTRIBUTE_PATTERN = "(?is)(?:^|\\s)(src|alt)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))";
        private const string LINK_ATTRIBUTE_PATTERN = "(?is)(?:^|\\s)href\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))";

        public string render(string markdown) {
            var normalized_markdown = normalize_allowed_html(markdown);
            var flags = new Markdown.DocumentFlags();
            flags.enable(Markdown.Option.NOHTML);
            flags.enable(Markdown.Option.SAFELINK);
            var document = new Markdown.Document.from_gfm_string(
                normalized_markdown,
                normalized_markdown.length,
                flags
            );
            if (!document.compile(flags)) {
                warning("Failed to compile Markdown preview");
                return "";
            }

            char* rendered_markdown;
            var rendered_length = document.document(out rendered_markdown);
            return rendered_length > 0 && rendered_markdown != null
                ? ((string) rendered_markdown).dup()
                : "";
        }

        private string normalize_allowed_html(string markdown) {
            try {
                var allowed_tag_regex = new Regex(ALLOWED_TAG_PATTERN);
                MatchInfo? matches;
                if (!allowed_tag_regex.match(markdown, 0, out matches)) {
                    return markdown;
                }

                var normalized = new StringBuilder();
                var source_end = 0;
                do {
                    int source_start;
                    int image_end;
                    matches.fetch_pos(0, out source_start, out image_end);
                    normalized.append(markdown.substring(source_end, source_start - source_end));

                    var allowed_tag = matches.fetch(0);
                    var normalized_tag = convert_allowed_tag(allowed_tag);
                    normalized.append(normalized_tag ?? allowed_tag);
                    source_end = image_end;
                } while (matches.next());

                normalized.append(markdown.substring(source_end));
                return normalized.str;
            } catch (RegexError error) {
                warning("Failed to normalize allowed HTML: %s", error.message);
                return markdown;
            }
        }

        private string? convert_allowed_tag(string tag) {
            var normalized_tag = tag.down();
            if (normalized_tag.has_prefix("<br")) {
                return "  \n";
            }
            if (normalized_tag.has_prefix("<img")) {
                return convert_image_tag(tag);
            }
            return convert_link_tag(tag);
        }

        private string? convert_image_tag(string image_tag) {
            try {
                string? source = null;
                string? alt = null;
                var attribute_regex = new Regex(IMAGE_ATTRIBUTE_PATTERN);
                MatchInfo? attributes;
                if (!attribute_regex.match(image_tag, 0, out attributes)) {
                    return null;
                }

                do {
                    var name = attributes.fetch(1).down();
                    var value = first_attribute_value(attributes);
                    if (name == "src") {
                        source = value;
                    } else if (name == "alt") {
                        alt = value;
                    }
                } while (attributes.next());

                if (!is_supported_image_source(source)) {
                    return null;
                }

                return "![%s](<%s>)".printf(
                    escape_markdown_alt_text(alt ?? ""),
                    source
                );
            } catch (RegexError error) {
                warning("Failed to parse HTML image attributes: %s", error.message);
                return null;
            }
        }

        private string? convert_link_tag(string link_tag) {
            try {
                var link_regex = new Regex("(?is)^<a\\b[^>]*>(.*?)</a\\s*>$");
                MatchInfo? link_match;
                if (!link_regex.match(link_tag, 0, out link_match)) {
                    return null;
                }

                var href = extract_link_href(link_tag);
                if (!is_supported_link_source(href)) {
                    return null;
                }

                var link_content = normalize_link_content(link_match.fetch(1));
                if (link_content == null) {
                    return null;
                }

                return "[%s](<%s>)".printf(
                    link_content,
                    href
                );
            } catch (RegexError error) {
                warning("Failed to parse HTML link: %s", error.message);
                return null;
            }
        }

        private string? normalize_link_content(string content) throws RegexError {
            var trimmed_content = content.strip();
            var image_tag_regex = new Regex(IMAGE_TAG_PATTERN);
            MatchInfo? image_match;
            if (image_tag_regex.match(trimmed_content, 0, out image_match)) {
                return convert_image_tag(trimmed_content);
            }
            return escape_markdown_link_text(content);
        }

        private string? extract_link_href(string link_tag) throws RegexError {
            var attribute_regex = new Regex(LINK_ATTRIBUTE_PATTERN);
            MatchInfo? attributes;
            if (!attribute_regex.match(link_tag, 0, out attributes)) {
                return null;
            }
            return first_matched_value(attributes, 1, 3);
        }

        private string? first_attribute_value(MatchInfo attributes) {
            return first_matched_value(attributes, 2, 4);
        }

        private string? first_matched_value(
            MatchInfo matches,
            int first_group,
            int last_group
        ) {
            for (var group = first_group; group <= last_group; group++) {
                int start;
                int end;
                if (matches.fetch_pos(group, out start, out end) &&
                    start >= 0 && end >= start) {
                    return matches.fetch(group);
                }
            }
            return null;
        }

        private bool is_supported_image_source(string? source) {
            return source != null &&
                source.has_prefix("https://") &&
                !source.contains("<") &&
                !source.contains(">") &&
                !source.contains("\n") &&
                !source.contains("\r");
        }

        private bool is_supported_link_source(string? source) {
            return source != null &&
                (source.has_prefix("https://") || source.has_prefix("http://")) &&
                !source.contains("<") &&
                !source.contains(">") &&
                !source.contains("\n") &&
                !source.contains("\r");
        }

        private string escape_markdown_alt_text(string alt) {
            return alt
                .replace("\\", "\\\\")
                .replace("[", "\\[")
                .replace("]", "\\]");
        }

        private string escape_markdown_link_text(string text) {
            return text
                .replace("\\", "\\\\")
                .replace("[", "\\[")
                .replace("]", "\\]");
        }
    }
}
