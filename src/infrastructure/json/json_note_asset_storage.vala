namespace Knotes {

    public class JsonNoteAssetStorage : GLib.Object {
        private const string ASSETS_DIRECTORY_NAME = "assets";

        private JsonStorageLayout layout;

        public JsonNoteAssetStorage(JsonStorageLayout layout) {
            this.layout = layout;
            prune_staged_orphaned_assets();
        }

        public string import_image_file(string note_id, GLib.File source_file) throws GLib.Error {
            ensure_note_exists(note_id);
            var basename = source_file.get_basename();
            if (basename == null || basename.length == 0) {
                throw new AssetStorageError.INVALID_SOURCE("Image has no filename");
            }

            var extension = normalized_image_extension(basename);
            if (extension == null) {
                throw new AssetStorageError.UNSUPPORTED_TYPE("Unsupported image type");
            }

            GLib.Bytes bytes;
            try {
                var info = source_file.query_info(FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
                if (info.get_file_type() != FileType.REGULAR) {
                    throw new AssetStorageError.INVALID_SOURCE("Source is not a regular image file");
                }
                bytes = source_file.load_bytes();
            } catch (AssetStorageError error) {
                throw error;
            } catch (GLib.Error error) {
                throw new AssetStorageError.INVALID_SOURCE("Image source could not be read");
            }
            if (!has_valid_image_signature(bytes, extension)) {
                throw new AssetStorageError.INVALID_SOURCE("Source is not a readable image file");
            }
            return persist_image(note_id, basename, bytes, extension);
        }

        public string import_image_bytes(
            string note_id,
            string suggested_filename,
            GLib.Bytes bytes
        ) throws GLib.Error {
            ensure_note_exists(note_id);
            var extension = normalized_image_extension(suggested_filename);
            if (extension == null) {
                throw new AssetStorageError.UNSUPPORTED_TYPE("Unsupported image type");
            }
            if (bytes.get_size() == 0 || !has_valid_image_signature(bytes, extension)) {
                throw new AssetStorageError.INVALID_SOURCE("Image data has an invalid signature");
            }
            return persist_image(note_id, suggested_filename, bytes, extension);
        }

        public AssetContent? load_asset(string note_id, string relative_path) throws GLib.Error {
            ensure_note_exists(note_id);
            var filename = validated_asset_filename(relative_path);
            var asset = GLib.File.new_for_path(
                Path.build_filename(layout.assets_directory_path(note_id), filename)
            );
            if (!asset.query_exists()) {
                return null;
            }

            var extension = normalized_image_extension(filename);
            if (extension == null) {
                throw new AssetStorageError.UNSUPPORTED_TYPE("Unsupported image type");
            }
            return new AssetContent(asset.load_bytes(), mime_type_for_extension(extension));
        }

        public void copy_referenced_assets(
            string source_note_id,
            string destination_note_id,
            string content
        ) throws GLib.Error {
            ensure_note_exists(source_note_id);
            ensure_note_exists(destination_note_id);

            var source_directory = GLib.File.new_for_path(
                layout.assets_directory_path(source_note_id)
            );
            var destination_directory = GLib.File.new_for_path(
                layout.assets_directory_path(destination_note_id)
            );
            try {
                foreach (var relative_path in referenced_asset_paths(content)) {
                    var filename = validated_asset_filename(relative_path);
                    var source = source_directory.get_child(filename);
                    if (!source.query_exists()) {
                        continue;
                    }
                    var info = source.query_info(
                        FileAttribute.STANDARD_TYPE,
                        FileQueryInfoFlags.NOFOLLOW_SYMLINKS
                    );
                    if (info.get_file_type() != FileType.REGULAR) {
                        throw new AssetStorageError.INVALID_SOURCE(
                            "Referenced asset is not a regular file"
                        );
                    }
                    if (!destination_directory.query_exists()) {
                        destination_directory.make_directory_with_parents();
                    }
                    source.copy(
                        destination_directory.get_child(filename),
                        FileCopyFlags.NONE
                    );
                }
            } catch (GLib.Error error) {
                remove_assets(destination_note_id);
                throw error;
            }
        }

        public void stage_orphaned_assets(Note note) throws GLib.Error {
            var existing_paths = list_existing_asset_paths(note.id);
            var referenced_paths = referenced_asset_paths(note.content);
            var staged_paths = load_staged_orphaned_assets(note.id);

            foreach (var relative_path in existing_paths) {
                if (referenced_paths.contains(relative_path)) {
                    staged_paths.remove(relative_path);
                } else {
                    staged_paths.add(relative_path);
                }
            }
            staged_paths.retain_all(existing_paths);
            persist_staged_orphaned_assets(note.id, staged_paths);
        }

        public void remove_assets(string note_id) {
            var root = GLib.File.new_for_path(layout.note_asset_root_path(note_id));
            if (!root.query_exists()) {
                return;
            }
            try {
                delete_recursively(root);
            } catch (GLib.Error error) {
                warning("Failed to remove assets for deleted note '%s': %s", note_id, error.message);
            }
        }

        private string persist_image(
            string note_id,
            string suggested_filename,
            GLib.Bytes bytes,
            string extension
        ) throws GLib.Error {
            var assets_directory = GLib.File.new_for_path(layout.assets_directory_path(note_id));
            if (!assets_directory.query_exists()) {
                assets_directory.make_directory_with_parents();
            }

            var basename = suggested_filename.substring(
                0,
                suggested_filename.length - extension.length - 1
            );
            var filename = unique_asset_filename(
                sanitize_filename_stem(basename),
                extension,
                assets_directory
            );
            var relative_path = ASSETS_DIRECTORY_NAME + "/" + filename;
            var destination = assets_directory.get_child(filename);
            unowned uint8[]? contents = bytes.get_data();
            if (contents == null) {
                throw new AssetStorageError.INVALID_SOURCE("Image data is unavailable");
            }

            string? etag;
            destination.replace_contents(
                contents,
                null,
                false,
                FileCreateFlags.REPLACE_DESTINATION,
                out etag
            );
            try {
                var staged_paths = load_staged_orphaned_assets(note_id);
                staged_paths.add(relative_path);
                persist_staged_orphaned_assets(note_id, staged_paths);
            } catch (GLib.Error error) {
                try {
                    destination.delete();
                } catch (GLib.Error cleanup_error) {
                    warning("Failed to roll back asset '%s': %s", relative_path, cleanup_error.message);
                }
                throw error;
            }
            return relative_path;
        }

        private void ensure_note_exists(string note_id) throws GLib.Error {
            if (!Uuid.string_is_valid(note_id) ||
                !GLib.File.new_for_path(layout.note_path(note_id)).query_exists()) {
                throw new AssetStorageError.NOT_FOUND("Note does not exist");
            }
        }

        private string validated_asset_filename(string relative_path) throws GLib.Error {
            var prefix = ASSETS_DIRECTORY_NAME + "/";
            if (!relative_path.has_prefix(prefix)) {
                throw new AssetStorageError.INVALID_SOURCE("Invalid asset path");
            }
            var filename = relative_path.substring(prefix.length);
            if (filename.length == 0 || filename == "." || filename == ".." ||
                filename.contains("/") || filename.contains("\\")) {
                throw new AssetStorageError.INVALID_SOURCE("Invalid asset path");
            }
            return filename;
        }

        private string? normalized_image_extension(string filename) {
            var dot_index = filename.last_index_of_char('.');
            if (dot_index <= 0 || dot_index == filename.length - 1) {
                return null;
            }
            var extension = filename.substring(dot_index + 1).down();
            switch (extension) {
                case "png":
                case "jpg":
                case "jpeg":
                case "gif":
                case "webp":
                case "svg":
                case "bmp":
                case "tif":
                case "tiff":
                    return extension;
                default:
                    return null;
            }
        }

        private bool has_valid_image_signature(GLib.Bytes bytes, string extension) {
            switch (extension) {
                case "png":
                    return starts_with_bytes(bytes, { 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a });
                case "jpg":
                case "jpeg":
                    return starts_with_bytes(bytes, { 0xff, 0xd8, 0xff });
                case "gif":
                    return starts_with_ascii(bytes, "GIF87a") || starts_with_ascii(bytes, "GIF89a");
                case "webp":
                    return starts_with_ascii(bytes, "RIFF") && contains_ascii_at(bytes, "WEBP", 8);
                case "svg":
                    return contains_ascii_ignoring_case(bytes, "<svg", 1024);
                case "bmp":
                    return starts_with_ascii(bytes, "BM");
                case "tif":
                case "tiff":
                    return starts_with_bytes(bytes, { 0x49, 0x49, 0x2a, 0x00 }) ||
                        starts_with_bytes(bytes, { 0x4d, 0x4d, 0x00, 0x2a });
                default:
                    return false;
            }
        }

        private bool starts_with_bytes(GLib.Bytes bytes, uint8[] signature) {
            if (bytes.get_size() < signature.length) {
                return false;
            }
            for (var index = 0; index < signature.length; index++) {
                if (bytes[index] != signature[index]) {
                    return false;
                }
            }
            return true;
        }

        private bool starts_with_ascii(GLib.Bytes bytes, string signature) {
            return contains_ascii_at(bytes, signature, 0);
        }

        private bool contains_ascii_at(GLib.Bytes bytes, string sequence, int offset) {
            if (offset < 0 || bytes.get_size() < offset + sequence.length) {
                return false;
            }
            for (var index = 0; index < sequence.length; index++) {
                if (bytes[offset + index] != sequence[index]) {
                    return false;
                }
            }
            return true;
        }

        private bool contains_ascii_ignoring_case(GLib.Bytes bytes, string needle, int max_bytes) {
            var limit = int.min((int) bytes.get_size(), max_bytes);
            for (var offset = 0; offset <= limit - needle.length; offset++) {
                var matches = true;
                for (var index = 0; index < needle.length; index++) {
                    var value = bytes[offset + index];
                    if (value >= 'A' && value <= 'Z') {
                        value += 'a' - 'A';
                    }
                    if (value != needle[index]) {
                        matches = false;
                        break;
                    }
                }
                if (matches) {
                    return true;
                }
            }
            return false;
        }

        private string sanitize_filename_stem(string raw_stem) {
            var lowercase = raw_stem.down();
            var sanitized = new StringBuilder();
            var separator_pending = false;
            for (var index = 0; index < lowercase.length; index++) {
                var character = lowercase[index];
                var is_ascii_letter = character >= 'a' && character <= 'z';
                var is_digit = character >= '0' && character <= '9';
                if (is_ascii_letter || is_digit) {
                    if (separator_pending && sanitized.len > 0) {
                        sanitized.append_c('-');
                    }
                    sanitized.append_c(character);
                    separator_pending = false;
                } else {
                    separator_pending = sanitized.len > 0;
                }
            }
            return sanitized.len > 0 ? sanitized.str : "image";
        }

        private string unique_asset_filename(
            string stem,
            string extension,
            GLib.File assets_directory
        ) {
            var index = 1;
            while (true) {
                var suffix = index == 1 ? "" : "-%d".printf(index);
                var filename = "%s%s.%s".printf(stem, suffix, extension);
                if (!assets_directory.get_child(filename).query_exists()) {
                    return filename;
                }
                index++;
            }
        }

        private string mime_type_for_extension(string extension) {
            switch (extension) {
                case "jpg":
                case "jpeg":
                    return "image/jpeg";
                case "svg":
                    return "image/svg+xml";
                case "tif":
                case "tiff":
                    return "image/tiff";
                default:
                    return "image/" + extension;
            }
        }

        private Gee.HashSet<string> list_existing_asset_paths(string note_id) throws GLib.Error {
            var paths = new Gee.HashSet<string>();
            var directory = GLib.File.new_for_path(layout.assets_directory_path(note_id));
            if (!directory.query_exists()) {
                return paths;
            }

            var enumerator = directory.enumerate_children(
                FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
                FileQueryInfoFlags.NONE
            );
            FileInfo info;
            while ((info = enumerator.next_file()) != null) {
                if (info.get_file_type() == FileType.REGULAR) {
                    paths.add(ASSETS_DIRECTORY_NAME + "/" + info.get_name());
                }
            }
            return paths;
        }

        private Gee.HashSet<string> referenced_asset_paths(string content) {
            var paths = new Gee.HashSet<string>();
            try {
                var expression = new Regex("assets/[A-Za-z0-9._-]+");
                MatchInfo matches;
                if (!expression.match(content, 0, out matches)) {
                    return paths;
                }
                do {
                    paths.add(matches.fetch(0));
                } while (matches.next());
            } catch (RegexError error) {
                warning("Failed to inspect note asset references: %s", error.message);
            }
            return paths;
        }

        private Gee.HashSet<string> load_staged_orphaned_assets(string note_id) throws GLib.Error {
            var paths = new Gee.HashSet<string>();
            var manifest_path = layout.orphaned_assets_path(note_id);
            var manifest = GLib.File.new_for_path(manifest_path);
            if (!manifest.query_exists()) {
                return paths;
            }

            var parser = new Json.Parser();
            parser.load_from_file(manifest_path);
            foreach (var element in parser.get_root().get_array().get_elements()) {
                var relative_path = element.get_string();
                if (relative_path != null) {
                    paths.add(relative_path);
                }
            }
            return paths;
        }

        private void persist_staged_orphaned_assets(
            string note_id,
            Gee.HashSet<string> relative_paths
        ) throws GLib.Error {
            var manifest = GLib.File.new_for_path(layout.orphaned_assets_path(note_id));
            if (relative_paths.is_empty) {
                if (manifest.query_exists()) {
                    manifest.delete();
                }
                remove_empty_asset_root(note_id);
                return;
            }

            var asset_root = GLib.File.new_for_path(layout.note_asset_root_path(note_id));
            if (!asset_root.query_exists()) {
                asset_root.make_directory_with_parents();
            }
            var sorted_paths = new Gee.ArrayList<string>();
            sorted_paths.add_all(relative_paths);
            sorted_paths.sort((left, right) => strcmp(left, right));
            var array = new Json.Array();
            foreach (var relative_path in sorted_paths) {
                array.add_string_element(relative_path);
            }

            var root = new Json.Node(Json.NodeType.ARRAY);
            root.set_array(array);
            var generator = new Json.Generator();
            generator.set_root(root);
            generator.pretty = true;
            size_t length;
            var data = generator.to_data(out length);
            string? etag;
            manifest.replace_contents(
                data.data,
                null,
                false,
                FileCreateFlags.REPLACE_DESTINATION,
                out etag
            );
        }

        private void prune_staged_orphaned_assets() {
            try {
                var enumerator = layout.notes_directory_file.enumerate_children(
                    FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
                    FileQueryInfoFlags.NONE
                );
                FileInfo info;
                while ((info = enumerator.next_file()) != null) {
                    var note_id = info.get_name();
                    if (info.get_file_type() != FileType.DIRECTORY || !Uuid.string_is_valid(note_id)) {
                        continue;
                    }
                    try {
                        prune_assets_for_note(note_id);
                    } catch (GLib.Error error) {
                        warning("Failed to prune assets for note '%s': %s", note_id, error.message);
                    }
                }
            } catch (GLib.Error error) {
                warning("Failed to inspect staged note assets: %s", error.message);
            }
        }

        private void prune_assets_for_note(string note_id) throws GLib.Error {
            var staged_paths = load_staged_orphaned_assets(note_id);
            if (staged_paths.is_empty) {
                return;
            }

            var referenced_paths = new Gee.HashSet<string>();
            var note_path = layout.note_path(note_id);
            if (GLib.File.new_for_path(note_path).query_exists()) {
                var parser = new Json.Parser();
                parser.load_from_file(note_path);
                var note = NoteJsonMapper.from_json(parser.get_root().get_object());
                if (note != null) {
                    referenced_paths = referenced_asset_paths(note.content);
                }
            }
            foreach (var relative_path in staged_paths) {
                if (referenced_paths.contains(relative_path)) {
                    continue;
                }
                try {
                    var filename = validated_asset_filename(relative_path);
                    var asset = GLib.File.new_for_path(
                        Path.build_filename(layout.assets_directory_path(note_id), filename)
                    );
                    if (asset.query_exists()) {
                        asset.delete();
                    }
                } catch (AssetStorageError error) {
                    warning("Ignoring invalid staged asset path for note '%s': %s", note_id, error.message);
                }
            }
            persist_staged_orphaned_assets(note_id, new Gee.HashSet<string>());
        }

        private void remove_empty_asset_root(string note_id) throws GLib.Error {
            remove_directory_if_empty(GLib.File.new_for_path(layout.assets_directory_path(note_id)));
            remove_directory_if_empty(GLib.File.new_for_path(layout.note_asset_root_path(note_id)));
        }

        private void remove_directory_if_empty(GLib.File directory) throws GLib.Error {
            if (!directory.query_exists()) {
                return;
            }
            var enumerator = directory.enumerate_children(
                FileAttribute.STANDARD_NAME,
                FileQueryInfoFlags.NONE
            );
            if (enumerator.next_file() == null) {
                directory.delete();
            }
        }

        private void delete_recursively(GLib.File file) throws GLib.Error {
            var info = file.query_info(FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            if (info.get_file_type() == FileType.DIRECTORY) {
                var enumerator = file.enumerate_children(
                    FileAttribute.STANDARD_NAME,
                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS
                );
                FileInfo child_info;
                while ((child_info = enumerator.next_file()) != null) {
                    delete_recursively(file.get_child(child_info.get_name()));
                }
            }
            file.delete();
        }
    }
}
