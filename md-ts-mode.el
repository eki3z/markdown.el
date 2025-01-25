;;; md-ts-mode.el --- Major mode for editing MARKDOWN files using tree-sitter -*- lexical-binding: t; -*-

;; This file is not a part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; This file is not a part of GNU Emacs.

;;; Commentary:

;; SEE https://www.markdownguide.org/cheat-sheet/

;; TODO supports more md features
;; * highlight
;; * heading ID
;; * definition list
;; * emoji
;; * subscript
;; * superscript

;; TODO supports more functions
;; * md-indent-function
;; * nested imenu
;; * navigation, reference,footnote jump
;; * markdown view mode

;; BUG
;; * escape delimiter parsed failed in code inline
;; * html parsed failed sometimes in code inline

;;; Code:

(require 'seq)
(require 'pcase)
(require 'crm)
(require 'treesit)

(declare-function xwidget-webkit-browse-url "xwidget")
(declare-function treesit-parser-create "treesit.c")

;;; Install tree-sitter language parser
(defvar md-ts-mode--language-source-alist
  '((markdown . ("https://github.com/tree-sitter-grammars/tree-sitter-markdown" "split_parser" "tree-sitter-markdown/src"))
    (markdown-inline . ("https://github.com/tree-sitter-grammars/tree-sitter-markdown" "split_parser" "tree-sitter-markdown-inline/src"))
    (html . ("https://github.com/tree-sitter/tree-sitter-html" "master"))
    (yaml . ("https://github.com/tree-sitter-grammars/tree-sitter-yaml" "master"))
    (toml . ("https://github.com/tree-sitter-grammars/tree-sitter-toml" "master")))
  "Tree-sitter language parsers required by `md-ts-mode'.
You can customize this variable if you want to stick to a specific
commit and/or use different parsers.")

(defun md-ts-mode-install-parsers ()
  "Install all the required tree-sitter parsers.
`md-ts-mode-language-source-alist' defines which parsers to install."
  (interactive)
  (let ((treesit-language-source-alist md-ts-mode--language-source-alist)
        (parsers (mapcar #'car md-ts-mode--language-source-alist)))
    (when-let* ((to-install (completing-read-multiple
                             "Install parsers: "
                             (mapcar #'symbol-name parsers))))
      (mapcar #'treesit-install-language-grammar
              (mapcar #'intern to-install)))))

;;; Custom variables

(defcustom md-ts-mode-enable-extensions nil
  "If non-nil, enable all features provided by tree-sitter extensions.
Wiki_link and tags are included."
  :type 'boolean
  :group 'md)

(defcustom md-ts-mode-indent-offset 4
  "Number of spaces for each indentation step in `md-ts-mode'."
  :version "29.1"
  :type 'natnum
  :safe 'natnump
  :group 'md)


;;; Syntax table

(defvar md-ts-mode--syntax-table
  (let ((st (make-syntax-table text-mode-syntax-table)))
    ;; Inherit from text-mode syntax table as a base
    (modify-syntax-entry ?\" "." st)  ; Treat " as punctuation (not string delimiter)
    (modify-syntax-entry ?\' "." st)  ; Treat ' as punctuation
    ;; Word constituents (letters, numbers, etc. are inherited)
    (modify-syntax-entry ?- "w" st)   ; Hyphens are part of words (e.g., "well-known")
    (modify-syntax-entry ?_ "w" st)   ; Underscores are part of words (e.g., "_emphasis_")
    ;; Markdown-specific markers
    (modify-syntax-entry ?* "." st)   ; Emphasis (*bold*, *italic*) as punctuation
    (modify-syntax-entry ?# "." st)   ; Heading marker (#) as punctuation
    (modify-syntax-entry ?` "\"" st)  ; Backtick (`) as string delimiter for inline code
    (modify-syntax-entry ?< "." st)   ; < for HTML tags or links as punctuation
    (modify-syntax-entry ?> "." st)   ; > for blockquotes or HTML tags as punctuation
    (modify-syntax-entry ?\[ "(" st)   ; [ for links as open parenthesis
    (modify-syntax-entry ?\] ")" st)   ; ] for links as close parenthesis
    (modify-syntax-entry ?\( "(" st)   ; ( for link URLs as open parenthesis
    (modify-syntax-entry ?\) ")" st)   ; ) for link URLs as close parenthesis
    (modify-syntax-entry ?| "." st)   ; | for tables as punctuation
    (modify-syntax-entry ?+ "." st)   ; + for lists as punctuation
    (modify-syntax-entry ?\n ">" st)  ; Newline as comment-end (for paragraph breaks)
    st)
  "Syntax table for `md-ts-mode'.")


;;; Indent

(defvar md-ts-mode--indent-rules
  `((markdown
     ((node-is "minus_metadata") column-0 0)
     ((node-is "plus_metadata") column-0 0)
     ((node-is "atx_heading") column-0 0)
     ((node-is "list_item") parent-bol 0)
     ((parent-is "list_item") parent-bol md-ts-mode-indent-offset)
     ((node-is "fenced_code_block") parent-bol 0)
     ((node-is "indented_code_block") parent-bol md-ts-mode-indent-offset)
     ((node-is "paragraph") parent-bol 0)))
  "Tree-sitter indent rules for `md-ts-mode'.")


;;; Font-lock

(defgroup md-ts-faces nil
  "Faces used in `md-ts-mode'."
  :group 'md
  :group 'faces)

(defface md-header
  '((t (:weight extra-bold)))
  "Face for base header."
  :group 'md-ts-faces)

(defface md-header-1
  '((t (:inherit md-header
        :foreground "#9cdbfb")))
  "Face for header 1st level."
  :group 'md-ts-faces)

(defface md-header-2
  '((t (:inherit md-header
        :foreground "#78bbed")))
  "Face for header 2nd level."
  :group 'md-ts-faces)

(defface md-header-3
  '((t (:inherit md-header
        :foreground "#82a1f1")))
  "Face for header 3rd level."
  :group 'md-ts-faces)

(defface md-header-4
  '((t (:inherit md-header
        :foreground "#6881C2")))
  "Face for header 4th level."
  :group 'md-ts-faces)

(defface md-header-5
  '((t (:inherit md-header
        :foreground "#9ca5cb")))
  "Face for header 5th level."
  :group 'md-ts-faces)

(defface md-header-6
  '((t (:inherit md-header
        :foreground "#757c9e")))
  "Face for header 6th level."
  :group 'md-ts-faces)

(defface md-strikethrough
  '((t (:strike-through t)))
  "Face for strikethrough text."
  :group 'md-ts-faces)

(defface md-delimiter
  '((t (:inherit font-lock-delimiter-face)))
  "Face for delimiters."
  :group 'md-ts-faces)

(defface md-ordered-list
  '((t (:inherit font-lock-string-face)))
  "Face for order list item markers."
  :group 'md-ts-faces)

(defface md-unordered-list
  '((t (:inherit font-lock-builtin-face)))
  "Face for unordered list item markers."
  :group 'md-ts-faces)

(defface md-task-list
  '((t (:inherit md-unordered-list)))
  "Face for task list item markers."
  :group 'md-ts-faces)

(defface md-blockquote
  '((t (:inherit (italic default))))
  "Face for blockquote sections."
  :group 'md-ts-faces)

(defface md-blockquote-marker
  '((t (:inherit (font-lock-keyword-face italic bold))))
  "Face for blockquote markers."
  :group 'md-ts-faces)

(defface md-code-block
  '((t (:inherit secondary-selection)))
  "Face for code block section."
  :group 'md-ts-faces)

(defface md-code-inline
  '((t (:inherit (md-code-block font-lock-string-face))))
  "Face for code inline section."
  :group 'md-ts-faces)

(defface md-code-delimiter
  '((t (:inherit (md-delimiter bold))))
  "Face for code block delimiters."
  :group 'md-ts-faces)

(defface md-code-language
  '((t (:inherit font-lock-constant-face)))
  "Face for code block language info strings."
  :group 'md-ts-faces)

(defface md-table-header
  '((t (:inherit font-lock-builtin-face)))
  "Face for table headers."
  :group 'md-ts-faces)

(defface md-table-content
  '((t (:inherit default)))
  "Face for table content."
  :group 'md-ts-faces)

(defface md-table-delimiter
  '((t (:inherit (md-delimiter bold))))
  "Face for tables delimiter."
  :group 'md-ts-faces)

(defface md-link-text
  '((t (:inherit font-lock-function-name-face)))
  "Face for link text."
  :group 'md-ts-faces)

(defface md-link-url
  '((t (:inherit link)))
  "Face for link url."
  :group 'md-ts-faces)

(defface md-link-title
  '((t (:inherit font-lock-doc-face)))
  "Face for link title."
  :group 'md-ts-faces)

(defface md-link-label
  '((t (:inherit font-lock-constant-face)))
  "Face for link label."
  :group 'md-ts-faces)

(defface md-wiki-link
  '((t (:inherit (md-link-text bold))))
  "Face for wiki link."
  :group 'md-ts-faces)

(defface md-tag
  '((t (:inherit font-lock-type-face)))
  "Face for tag section."
  :group 'md-ts-faces)

(defface md-image-marker
  '((t (:inherit (font-lock-string-face bold))))
  "Face for image link marker."
  :group 'md-ts-faces)

(defface md-footnote-label
  '((t (:inherit md-link-label)))
  "Face for footnote label."
  :group 'md-ts-faces)

(defface md-footnote-text
  '((t (:inherit md-link-text)))
  "Face for footnote text."
  :group 'md-ts-faces)

(defface md-comment
  '((t (:inherit (font-lock-comment-face italic))))
  "Face for HTML comments."
  :group 'md-ts-faces)

(defface md-horizontal-rule
  '((t (:inherit (md-delimiter bold))))
  "Face for horizontal rules."
  :group 'md-ts-faces)

(defface md-escape
  '((t (:inherit font-lock-escape-face)))
  "Face for escape characters."
  :group 'md-ts-faces)

(defface md-reference
  '((t (:inherit font-lock-number-face)))
  "Face for HTML comments."
  :group 'md-ts-faces)

(defface md-html-tag-name
  '((t (:inherit font-lock-function-name-face)))
  "Face for HTML tag names."
  :group 'md-ts-faces)

(defface md-html-tag-delimiter
  '((t (:inherit font-lock-number-face)))
  "Face for HTML tag delimiters."
  :group 'md-ts-faces)

(defface md-html-attr-name
  '((t (:inherit font-lock-variable-name-face)))
  "Face for HTML attribute names."
  :group 'md-ts-faces)
;;
(defface md-html-attr-value
  '((t (:inherit font-lock-string-face)))
  "Face for HTML attribute values."
  :group 'md-ts-faces)

(defface md-line-break
  '((t (:inherit default)))
  "Face for hard line breaks."
  :group 'md-ts-faces)

(defvar md-ts-mode--markdown-font-lock-settings
  (treesit-font-lock-rules
   :language 'markdown
   :feature 'horizontal_rule
   '((thematic_break) @md-horizontal-rule)

   :language 'markdown
   :feature 'heading
   '((atx_heading (atx_h1_marker)) @md-header-1
     (atx_heading (atx_h2_marker)) @md-header-2
     (atx_heading (atx_h3_marker)) @md-header-3
     (atx_heading (atx_h4_marker)) @md-header-4
     (atx_heading (atx_h5_marker)) @md-header-5
     (atx_heading (atx_h6_marker)) @md-header-6
     (setext_h1_underline) @md-header-1
     (setext_h2_underline) @md-header-2
     (setext_heading (paragraph) @md-header-1))

   :language 'markdown
   :feature 'blockquote
   :override t
   '((block_quote) @md-blockquote
     (block_quote_marker) @md-blockquote-marker
     ((block_continuation) @cap (:match "^>[> ]*$" @cap)) @md-blockquote-marker)

   :language 'markdown
   :feature 'table
   '((pipe_table_header (pipe_table_cell) @md-table-header)
     (pipe_table_row (pipe_table_cell) @md-table-content)
     (pipe_table (_ "|" @md-table-delimiter))
     (pipe_table_delimiter_cell "-" @md-table-delimiter))

   :language 'markdown
   :feature 'list
   '([(list_marker_dot)
      (list_marker_parenthesis)]
     @md-ordered-list
     [(list_marker_plus)
      (list_marker_minus)
      (list_marker_star)]
     @md-unordered-list
     [(task_list_marker_checked)
      (task_list_marker_unchecked)]
     @md-task-list)

   :language 'markdown
   :feature 'link_reference
   '((link_reference_definition
      (link_label) @md-link-label
      (link_destination) @md-link-url
      (link_title) :? @md-link-title))

   :language 'markdown
   :feature 'code_block
   :override 'append
   '((indented_code_block) @md-blockquote
     (fenced_code_block) @md-code-block
     (fenced_code_block_delimiter) @md-code-delimiter
     (info_string) @md-code-language
     ;; TODO rewrite codeblock with indirect-buffer
     ;; (code_fence_content) @md-fontify-codeblock
     (code_fence_content) @font-lock-string-face))
  "Tree-sitter Font-lock settings for markdown and inline part.")

(defvar md-ts-mode--markdown-inline-font-lock-settings
  (append
   (treesit-font-lock-rules
    :language 'markdown-inline
    :feature 'escape
    '((backslash_escape) @md-escape)

    :language 'markdown-inline
    :feature 'footnote
    '((shortcut_link
       (link_text) @text
       (:match "^\\^" @text))
      @md-footnote-label)

    :language 'markdown-inline
    :feature 'emphasis
    :override 'append
    '((strong_emphasis) @bold
      (emphasis) @italic
      (strikethrough) @md-strikethrough)

    :language 'markdown-inline
    :feature 'code_inline
    :override t
    '(
      ;; TODO rewrite inline
      ;; (code_span
      ;;  :anchor (code_span_delimiter) @md-delimiter
      ;;  ;; _ @md-code-inline
      ;;  (code_span_delimiter) @md-delimiter :anchor)
      (code_span) @md-code-inline
      (code_span_delimiter) @md-delimiter)

    :language 'markdown-inline
    :feature 'delimiter
    :override t
    '((emphasis_delimiter) @md-delimiter
      (hard_line_break) @md-line-break)

    :language 'markdown-inline
    :feature 'reference
    '([(entity_reference)
       (numeric_character_reference)]
      @md-reference)

    :language 'markdown-inline
    :feature 'link
    '((inline_link
       (link_text) @md-link-text
       (link_destination) :? @md-link-url
       (link_title) :? @md-link-title)
      (inline_link ["[" "]" "(" ")"] @md-delimiter)

      (full_reference_link
       (link_text) @md-link-text
       (link_label) @md-link-label)
      (full_reference_link ["[" "]"] @md-delimiter)

      (collapsed_reference_link
       (link_text) @md-link-text)
      (collapsed_reference_link ["[" "]"] @md-delimiter)

      [(uri_autolink) (email_autolink)] @md-link-url)

    :language 'markdown-inline
    :feature 'image
    '((image
       "!" @md-image-marker
       (image_description) @md-link-text
       (link_destination) :? @md-link-url
       (link_title) :? @md-link-title
       (link_label) :? @md-link-label)
      (image ["[" "]" "(" ")"] @md-delimiter)))

   (when md-ts-mode-enable-extensions
     (treesit-font-lock-rules
      :language 'markdown-inline
      :feature 'wiki_link
      '((wiki_link (link_destination) @md-link-url
                   (link_text) :? @md-wiki-link)
        (wiki_link ["[" "|" "]"] @md-delimiter))

      :language 'markdown-inline
      :feature 'tag
      '((tag) @md-tag))))
  "Tree-sitter Font-lock settings for markdown-inline parser.")

(defvar md-ts-mode--html-font-lock-settings
  (treesit-font-lock-rules
   :language 'html
   :feature 'comment
   '((comment) @md-comment)

   :language 'html
   :feature 'html_tag
   '((tag_name) @md-html-tag-name
     (attribute_name) @md-html-attr-name
     (attribute_value) @md-html-attr-value
     (start_tag ["<" ">"] @md-html-tag-delimiter)
     (end_tag ["</" ">"] @md-html-tag-delimiter)))
  "Tree-sitter Font-lock settings for html parser.")

(defvar md-ts-mode--yaml-font-lock-settings
  (treesit-font-lock-rules
   :language 'yaml
   :feature 'metadata_yaml
   '((["[" "]" "{" "}"]) @font-lock-bracket-face
     (["," ":" "-" ">" "?" "|"]) @font-lock-delimiter-face
     (["---"]) @md-horizontal-rule

     (block_mapping_pair key: (_) @font-lock-property-use-face)
     (flow_mapping (_ key: (_) @font-lock-property-use-face))
     (flow_sequence (_ key: (_) @font-lock-property-use-face))

     [(alias_name) (anchor_name) (tag)] @font-lock-type-face
     [(block_scalar) (double_quote_scalar) (single_quote_scalar) (string_scalar)]
     @font-lock-string-face
     [(boolean_scalar) (null_scalar) (reserved_directive)
      (tag_directive)(yaml_directive)]
     @font-lock-constant-face
     [(float_scalar) (integer_scalar)] @font-lock-number-face
     (escape_sequence) @font-lock-escape-face))
  "Tree-sitter Font-lock settings for yaml metadata.")

(defvar md-ts-mode--toml-font-lock-settings
  (treesit-font-lock-rules
   :language 'toml
   :feature 'metadata_toml
   :override t
   '((boolean) @font-lock-constant-face
     (["="]) @font-lock-delimiter-face
     [(integer) (float) (local_date) (local_date_time)
      (local_time) (offset_date_time)] @font-lock-number-face
     (string) @font-lock-string-face
     (escape_sequence) @font-lock-escape-face
     [(bare_key) (quoted_key)] @font-lock-property-use-face
     (array [ "[" "]"] @font-lock-bracket-face)
     (table ("[" @font-lock-bracket-face
             (_) @font-lock-type-face
             "]" @font-lock-bracket-face))
     (table_array_element ("[[" @font-lock-bracket-face
                           (_) @font-lock-type-face
                           "]]" @font-lock-bracket-face))
     (table (quoted_key) @font-lock-type-face)
     (table (dotted_key (quoted_key)) @font-lock-type-face)
     ((ERROR) @hr (:equal "+++" @hr)) @md-horizontal-rule))
  "Tree-sitter Font-lock settings for toml metadata.")

(defun md-ts-mode--language-at-point (point)
  "Return the language at POINT for `md-ts-mode'."
  (if-let* ((node (treesit-node-at point 'markdown)))
      (pcase (treesit-node-type node)
        ("minus_metadata" ''yaml)
        ("plus_metadata" 'toml)
        ("html_block" 'html)
        ("inline"
         (if-let* ((node-i (treesit-node-at point 'markdown-inline)))
             (pcase (treesit-node-type node-i)
               ("html_tag" 'html)
               ;; ("latex_block" 'latex)
               (_ 'markdown-inline))
           'markdown-inline))
        (_ 'markdown))
    'markdown))

;; TODO add more embedded langs, latex, mdx
;;;###autoload
(defvar md-ts-mode-embedded-recipes
  '((markdown-inline
     :font-lock md-ts-mode--markdown-inline-font-lock-settings
     :range-rule (:embed 'markdown-inline
                  :host 'markdown
                  '((inline) @cap)))
    (html
     :font-lock md-ts-mode--html-font-lock-settings
     :range-rule (:embed 'html
                  :host 'markdown
                  '((html_block) @cap)

                  ;; FIXME failed to capture html in inline sometimes
                  :embed 'html
                  :host 'markdown-inline
                  :local t
                  '((html_tag) @cap)))
    (yaml
     :font-lock md-ts-mode--yaml-font-lock-settings
     :range-rule (:embed 'yaml
                  :host 'markdown
                  '((minus_metadata) @cap)))
    (toml
     :font-lock md-ts-mode--toml-font-lock-settings
     :range-rule (:embed 'toml
                  :host 'markdown
                  '((plus_metadata) @cap))))
  "Recipes for embedded languages in `md-ts-mode'.")

(defun md-ts-mode--fetch-embedded-font-lock ()
  "Return embedded font lock settings for `md-ts-mode'."
  (thread-last
    md-ts-mode-embedded-recipes
    (seq-filter (lambda (x) (treesit-ready-p (car x) 'quiet)))
    (seq-mapcat (lambda (x) (symbol-value (plist-get (cdr x) :font-lock))))))

(defmacro md-ts-mode--fetch-embedded-range-rules ()
  "Return embedded range rules for `md-ts-mode'."
  `(treesit-range-rules
    ,@(thread-last
        md-ts-mode-embedded-recipes
        (seq-filter (lambda (x) (treesit-ready-p (car x) 'quiet)))
        (seq-mapcat (lambda (x) (plist-get (cdr x) :range-rule))))))

;; (defun md-ts-mode-fontify-footnote ()
;;   )


;; Imenu

(defun md-ts-mode--heading-name (node)
  "Return the text content of the heading NODE's inline content."
  (when-let* ((parent (treesit-node-parent node))
              (inline (treesit-node-child-by-field-name parent "heading_content"))
              ((string= (treesit-node-type inline) "inline")))
    (treesit-node-text inline)))

(defun md-ts-mode--imenu-headings ()
  "Return a list of Markdown heading rules for imenu integration.
Each rule is a list (NAME PATTERN nil EXTRACTOR) for ATX headings (H1-H6).
NAME is the heading level (e.g., \"H1\"), PATTERN matches Tree-sitter
node types like \"atx_h1_marker\", and EXTRACTOR is `md-ts-heading-name'."
  (let ((heading-levels (number-sequence 1 6))
        rules)
    (dolist (level heading-levels rules)
      (push (list (format "H%d" level)
                  (format "\\`atx_h%d_marker\\'" level)
                  nil
                  #'md-ts-mode--heading-name)
            rules))
    (nreverse rules)))


;; Major mode

;;;###autoload
(define-derived-mode md-ts-mode fundamental-mode "MD"
  "Major mode for editing markdown, powered by tree-sitter."
  :group 'md
  :syntax-table md-ts-mode--syntax-table

  (unless (treesit-ready-p 'markdown 'quiet)
    (error "Tree-sitter for markdown isn't available.
You can install the parser with M-x `md-ts-mode-install-parsers'"))

  ;; Comments
  (setq-local comment-start "<!--")
  (setq-local comment-end "-->")
  (setq-local comment-start-skip (rx (seq (syntax comment-start)
                                          (* (syntax whitespace)))))
  (setq-local comment-end-skip (rx (seq (* (syntax whitespace))
                                        (syntax comment-end))))

  ;; Indent
  (setq-local treesit-simple-indent-rules md-ts-mode--indent-rules)

  ;; ;; Navigation
  ;; (setq-local treesit-defun-type-regexp
  ;;             (rx (or "pair" "object")))
  ;; (setq-local treesit-defun-name-function #'md-ts-mode--defun-name)
  ;; (setq-local treesit-thing-settings
  ;;             `((markdown
  ;;                (sentence "pair"))))

  ;; Font-lock.
  (setq-local treesit-primary-parser (treesit-parser-create 'markdown))
  (setq-local treesit-range-settings (md-ts-mode--fetch-embedded-range-rules))
  (setq-local treesit-language-at-point-function #'md-ts-mode--language-at-point)
  (setq-local treesit-font-lock-settings
              (append md-ts-mode--markdown-font-lock-settings
                      (md-ts-mode--fetch-embedded-font-lock)))

  (setq-local treesit-font-lock-feature-list
              '((comment delimiter)
                (heading emphasis blockquote list task_list table
                         link link_reference image code_inline code_block
                         horizontal_rule html_tag)
                (escape reference footnote metadata_yaml metadata_toml)
                (wiki_link tag)))

  ;; TODO provide more features which are missing in tree-sitter grammar with
  ;; regexp in font-lock-defaults

  ;; Imenu
  (setq-local treesit-simple-imenu-settings `(,@(md-ts-mode--imenu-headings)))

  (treesit-major-mode-setup))

(derived-mode-add-parents 'md-ts-mode '(markdown-mode))

(when (treesit-ready-p 'markdown 'quiet)
  (add-to-list 'auto-mode-alist '("\\.md\\'" . md-ts-mode)))

(provide 'md-ts-mode)

;;; md-ts-mode.el ends here
