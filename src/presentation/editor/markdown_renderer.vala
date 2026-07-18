namespace Knotes {

    [CCode (cname = "cmark_markdown_to_html", cheader_filename = "cmark.h")]
    private static extern string markdown_to_html(string markdown, size_t length, int options);

    public class MarkdownRenderer : Object {
        private class TableRow : Object {
            public string[] cells;
            public bool has_separator;

            public TableRow(string[] cells, bool has_separator) {
                this.cells = cells;
                this.has_separator = has_separator;
            }
        }

        private class RenderPlan : Object {
            public string markdown;
            public string placeholder_prefix;
            public string[] tables;

            public RenderPlan(string markdown, string placeholder_prefix, string[] tables) {
                this.markdown = markdown;
                this.placeholder_prefix = placeholder_prefix;
                this.tables = tables;
            }
        }

        private enum TableAlignment {
            NONE,
            LEFT,
            CENTER,
            RIGHT
        }

        public static string render(string markdown) {
            var plan = replace_tables_with_placeholders(markdown);
            var html = markdown_to_html(plan.markdown, plan.markdown.length, 0);
            for (int table_index = 0; table_index < plan.tables.length; table_index++) {
                var placeholder = "<p>%s%d_END</p>".printf(
                    plan.placeholder_prefix,
                    table_index
                );
                html = html.replace(placeholder, plan.tables[table_index]);
            }
            return html;
        }

        private static RenderPlan replace_tables_with_placeholders(string markdown) {
            var lines = markdown.split("\n");
            var output = new StringBuilder();
            var placeholder_prefix = unique_placeholder_prefix(markdown);
            string[] tables = {};
            char fence_marker = '\0';
            int fence_length = 0;

            for (int line_index = 0; line_index < lines.length;) {
                int marker_length;
                char marker = find_fence_marker(lines[line_index], out marker_length);
                if (marker != '\0') {
                    if (fence_marker == '\0') {
                        fence_marker = marker;
                        fence_length = marker_length;
                    } else if (marker == fence_marker &&
                        marker_length >= fence_length &&
                        is_closing_fence(lines[line_index], marker_length)) {
                        fence_marker = '\0';
                        fence_length = 0;
                    }
                    append_line(output, lines[line_index]);
                    line_index++;
                    continue;
                }

                if (fence_marker == '\0' && line_index + 1 < lines.length) {
                    var header = parse_table_row(lines[line_index]);
                    var delimiter = parse_table_row(lines[line_index + 1]);
                    TableAlignment[] alignments = {};
                    if (header.has_separator &&
                        try_parse_alignments(delimiter, header.cells.length, out alignments)) {
                        var table = new StringBuilder();
                        line_index = append_table(table, lines, line_index, header, alignments);
                        output.append("\n%s%d_END\n\n".printf(
                            placeholder_prefix,
                            tables.length
                        ));
                        tables += table.str;
                        continue;
                    }
                }

                append_line(output, lines[line_index]);
                line_index++;
            }

            return new RenderPlan(output.str, placeholder_prefix, tables);
        }

        private static string unique_placeholder_prefix(string markdown) {
            var prefix = "KNOTES_TABLE_PLACEHOLDER_";
            while (prefix in markdown) {
                prefix += "_";
            }
            return prefix;
        }

        private static int append_table(
            StringBuilder output,
            string[] lines,
            int header_index,
            TableRow header,
            TableAlignment[] alignments
        ) {
            output.append("<table>\n<thead>\n<tr>\n");
            for (int column = 0; column < header.cells.length; column++) {
                append_cell(output, "th", header.cells[column], alignments[column]);
            }
            output.append("</tr>\n</thead>\n");

            var body = new StringBuilder();
            int line_index = header_index + 2;
            while (line_index < lines.length) {
                var row = parse_table_row(lines[line_index]);
                if (!row.has_separator || lines[line_index].strip() == "") {
                    break;
                }
                body.append("<tr>\n");
                for (int column = 0; column < header.cells.length; column++) {
                    var cell = column < row.cells.length ? row.cells[column] : "";
                    append_cell(body, "td", cell, alignments[column]);
                }
                body.append("</tr>\n");
                line_index++;
            }

            if (body.len > 0) {
                output.append("<tbody>\n");
                output.append(body.str);
                output.append("</tbody>\n");
            }
            output.append("</table>");
            return line_index;
        }

        private static void append_cell(
            StringBuilder output,
            string element,
            string markdown,
            TableAlignment alignment
        ) {
            output.append_c('<');
            output.append(element);
            if (alignment != TableAlignment.NONE) {
                output.append(" align=\"");
                output.append(alignment_name(alignment));
                output.append_c('"');
            }
            output.append_c('>');
            output.append(render_inline(markdown));
            output.append("</");
            output.append(element);
            output.append(">\n");
        }

        private static string alignment_name(TableAlignment alignment) {
            switch (alignment) {
                case TableAlignment.LEFT:
                    return "left";
                case TableAlignment.CENTER:
                    return "center";
                case TableAlignment.RIGHT:
                    return "right";
                default:
                    return "";
            }
        }

        private static string render_inline(string markdown) {
            var html = markdown_to_html(markdown, markdown.length, 0).strip();
            if (html.has_prefix("<p>") && html.has_suffix("</p>")) {
                return html.substring(3, html.length - 7);
            }
            return html;
        }

        private static bool try_parse_alignments(
            TableRow delimiter,
            int column_count,
            out TableAlignment[] alignments
        ) {
            alignments = new TableAlignment[column_count];
            if (!delimiter.has_separator || delimiter.cells.length != column_count) {
                return false;
            }

            for (int column = 0; column < delimiter.cells.length; column++) {
                var cell = delimiter.cells[column];
                var marker = cell.strip();
                bool left_aligned = marker.has_prefix(":");
                bool right_aligned = marker.has_suffix(":");
                int dash_start = left_aligned ? 1 : 0;
                int dash_end = marker.length - (right_aligned ? 1 : 0);
                if (dash_start >= dash_end) {
                    return false;
                }
                for (int index = dash_start; index < dash_end; index++) {
                    if (marker[index] != '-') {
                        return false;
                    }
                }

                if (left_aligned && right_aligned) {
                    alignments[column] = TableAlignment.CENTER;
                } else if (left_aligned) {
                    alignments[column] = TableAlignment.LEFT;
                } else if (right_aligned) {
                    alignments[column] = TableAlignment.RIGHT;
                } else {
                    alignments[column] = TableAlignment.NONE;
                }
            }
            return true;
        }

        private static TableRow parse_table_row(string line) {
            if (count_leading_spaces(line) > 3) {
                return new TableRow({}, false);
            }

            var content = line.strip();
            if (content == "" || content.has_prefix(">")) {
                return new TableRow({}, false);
            }

            bool has_leading_pipe = content[0] == '|';
            bool has_trailing_pipe = content[content.length - 1] == '|' &&
                !is_escaped(content, content.length - 1);
            int start = has_leading_pipe ? 1 : 0;
            int end = has_trailing_pipe ? content.length - 1 : content.length;
            int cell_start = start;
            bool has_separator = has_leading_pipe || has_trailing_pipe;
            string[] cells = {};

            for (int index = start; index < end; index++) {
                if (content[index] == '|' && !is_escaped(content, index)) {
                    cells += content.substring(cell_start, index - cell_start).strip();
                    cell_start = index + 1;
                    has_separator = true;
                }
            }
            cells += content.substring(cell_start, end - cell_start).strip();
            return new TableRow(cells, has_separator);
        }

        private static bool is_escaped(string text, int index) {
            int backslash_count = 0;
            for (int preceding = index - 1; preceding >= 0 && text[preceding] == '\\'; preceding--) {
                backslash_count++;
            }
            return backslash_count % 2 == 1;
        }

        private static char find_fence_marker(string line, out int marker_length) {
            marker_length = 0;
            int start = count_leading_spaces(line);
            if (start > 3 || start >= line.length ||
                (line[start] != '`' && line[start] != '~')) {
                return '\0';
            }

            char marker = line[start];
            while (start + marker_length < line.length &&
                line[start + marker_length] == marker) {
                marker_length++;
            }
            return marker_length >= 3 ? marker : '\0';
        }

        private static bool is_closing_fence(string line, int marker_length) {
            int content_start = count_leading_spaces(line) + marker_length;
            return line.substring(content_start).strip() == "";
        }

        private static int count_leading_spaces(string line) {
            int count = 0;
            while (count < line.length && line[count] == ' ') {
                count++;
            }
            return count;
        }

        private static void append_line(StringBuilder output, string line) {
            output.append(line);
            output.append_c('\n');
        }
    }
}
