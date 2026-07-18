[CCode (cheader_filename = "mkdio.h")]
namespace Markdown {

    [Compact]
    [CCode (cname = "mkd_flag_t", free_function = "mkd_free_flags")]
    public class DocumentFlags {
        [CCode (cname = "mkd_flags")]
        public DocumentFlags ();

        [CCode (cname = "mkd_set_flag_num")]
        public void enable (Option option);
    }

    [CCode (cprefix = "MKD_", has_type_id = false)]
    public enum Option {
        NOHTML,
        SAFELINK
    }

    [Compact]
    [CCode (cname = "MMIOT", cprefix = "mkd_", free_function = "mkd_cleanup")]
    public class Document {
        [CCode (cname = "gfm_string")]
        public Document.from_gfm_string (
            string markdown,
            int length,
            DocumentFlags flags
        );

        public bool compile (DocumentFlags flags);
        public int document (out char* html);
    }
}
