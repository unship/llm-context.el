;;; llm-context.el --- Copy editor context for LLMs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Li yanan
;; Author: Li yanan
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, files, tools, llm, agent, context
;; URL: https://github.com/unship/llm-context.el

;;; Commentary:

;; Copy the current line, region, file, or tool result as LLM-friendly
;; Markdown context.  Optional integrations with Dired, Magit, xref,
;; compilation, occur, diff, and EWW are detected at runtime.

;;; Code:

(defcustom llm-context-max-lines 100
  "Maximum selected lines to include inline in `llm-context-copy'.
With a prefix argument, include the selected text regardless of this limit."
  :type 'integer
  :group 'agent)

(defcustom llm-context-include-emacs-context t
  "Whether to include Emacs buffer metadata for temporary buffers.
The metadata includes the daemon name, buffer, major mode, active minor
modes, point, and narrowing state."
  :type 'boolean
  :group 'llm-context)

(defvar llm-context--copy-language-alist
  '((c-mode . "c")
    (c++-mode . "cpp")
    (c++-ts-mode . "cpp")
    (c-ts-mode . "c")
    (css-mode . "css")
    (css-ts-mode . "css")
    (compilation-mode . "text")
    (diff-mode . "diff")
    (emacs-lisp-mode . "emacs-lisp")
    (eww-mode . "text")
    (gfm-mode . "markdown")
    (go-mode . "go")
    (go-ts-mode . "go")
    (html-mode . "html")
    (html-ts-mode . "html")
    (js-mode . "javascript")
    (js-ts-mode . "javascript")
    (json-mode . "json")
    (json-ts-mode . "json")
    (lisp-interaction-mode . "emacs-lisp")
    (magit-diff-mode . "diff")
    (magit-log-mode . "text")
    (magit-status-mode . "text")
    (markdown-mode . "markdown")
    (markdown-ts-mode . "markdown")
    (nxml-mode . "xml")
    (occur-mode . "text")
    (org-mode . "org")
    (python-mode . "python")
    (python-ts-mode . "python")
    (rust-mode . "rust")
    (rust-ts-mode . "rust")
    (sh-mode . "sh")
    (shell-script-mode . "sh")
    (tsx-ts-mode . "tsx")
    (typescript-mode . "typescript")
    (typescript-ts-mode . "typescript")
    (web-mode . "html")
    (xref--xref-buffer-mode . "text")
    (yaml-mode . "yaml")
    (yaml-ts-mode . "yaml"))
  "Major-mode to Markdown fence language mapping for LLM context snippets.")

(defun llm-context--copy-abbrev-path (path)
  "Return PATH abbreviated for copying into LLM context."
  (if (and path (file-name-absolute-p path))
      (abbreviate-file-name path)
    path))

(defun llm-context--copy-language ()
  "Return a Markdown fence language for the current buffer."
  (or (alist-get major-mode llm-context--copy-language-alist)
      (let ((name (symbol-name major-mode)))
        (cond
         ((string-match "\\`\\(.+\\)-ts-mode\\'" name)
          (match-string 1 name))
         ((string-match "\\`\\(.+\\)-mode\\'" name)
          (match-string 1 name))
         (t "")))))

(defun llm-context--copy-dired-paths ()
  "Return marked dired/dirvish files, or the file at point."
  (when (derived-mode-p 'dired-mode)
    (require 'dired)
    (or (ignore-errors (dired-get-marked-files nil nil))
        (list default-directory))))

(defun llm-context--copy-marker-ref (marker)
  "Return a file:line reference for MARKER."
  (when (markerp marker)
    (let ((buffer (marker-buffer marker))
          (pos (marker-position marker)))
      (when (and buffer pos)
        (with-current-buffer buffer
          (let ((file (or (buffer-file-name)
                          (buffer-file-name (buffer-base-buffer)))))
            (when file
              (format "%s:%d"
                      (llm-context--copy-abbrev-path file)
                      (line-number-at-pos pos t)))))))))

(defun llm-context--copy-compilation-ref ()
  "Return source reference at point in compilation/grep buffers."
  (when (derived-mode-p 'compilation-mode)
    (let* ((message (get-text-property (point) 'compilation-message))
           (loc (and message
                     (fboundp 'compilation--message->loc)
                     (ignore-errors (compilation--message->loc message))))
           (marker (and loc
                        (fboundp 'compilation--loc->marker)
                        (ignore-errors (compilation--loc->marker loc)))))
      (llm-context--copy-marker-ref marker))))

(defun llm-context--copy-xref-ref ()
  "Return source reference at point in xref result buffers."
  (when (and (fboundp 'xref--item-at-point)
             (fboundp 'xref-item-location)
             (fboundp 'xref-location-marker))
    (let* ((item (ignore-errors (xref--item-at-point)))
           (location (and item (xref-item-location item)))
           (marker (and location
                        (ignore-errors (xref-location-marker location)))))
      (llm-context--copy-marker-ref marker))))

(defun llm-context--copy-occur-ref ()
  "Return source reference at point in occur buffers."
  (when (derived-mode-p 'occur-mode)
    (llm-context--copy-marker-ref
     (get-text-property (point) 'occur-target))))

(defun llm-context--copy-diff-ref ()
  "Return source reference at point in plain diff buffers."
  (when (and (derived-mode-p 'diff-mode)
             (not (derived-mode-p 'magit-mode))
             (fboundp 'diff-find-source-location))
    (let* ((location (ignore-errors (diff-find-source-location nil nil t)))
           (buffer (car-safe location))
           (range (nth 2 location)))
      (when (and (bufferp buffer) (consp range))
        (with-current-buffer buffer
          (let ((file (or (buffer-file-name)
                          (buffer-file-name (buffer-base-buffer)))))
            (when file
              (format "%s:%d"
                      (llm-context--copy-abbrev-path file)
                      (line-number-at-pos (car range) t)))))))))

(defun llm-context--copy-line-count (string)
  "Return the number of lines in STRING."
  (with-temp-buffer
    (insert string)
    (count-lines (point-min) (point-max))))

(defun llm-context--copy-magit-rev-desc (rev)
  "Return a \"SHORT — SUBJECT\" description for REV, or REV on failure."
  (let ((short (or (ignore-errors (magit-rev-abbrev rev)) rev))
        (subject (ignore-errors (magit-rev-format "%s" rev))))
    (if (and subject (> (length subject) 0))
        (format "%s — %s" short subject)
      short)))

(defun llm-context--copy-magit-staging ()
  "Return `staged', `unstaged', or `untracked' for the section at point.
Walks the section ancestry; falls back to the buffer's diff typearg in
standalone diff buffers, else nil."
  (or (let ((section (and (fboundp 'magit-current-section)
                          (magit-current-section)))
            found)
        (require 'eieio)
        (while (and section (not found))
          (when (memq (slot-value section 'type) '(staged unstaged untracked))
            (setq found (slot-value section 'type)))
          (setq section (slot-value section 'parent)))
        found)
      (when (member "--cached" (bound-and-true-p magit-buffer-typearg))
        'staged)))

(defun llm-context--copy-magit-ref ()
  "Return file/commit/range context at point in Magit buffers.
Encodes working-tree staging state, the shown commit (SHA + subject), a
diff range, or a revision at point, so the destination knows what the
diff represents."
  (when (derived-mode-p 'magit-mode)
    (let* ((root (and (fboundp 'magit-toplevel)
                      (ignore-errors (magit-toplevel))))
           (file (and (fboundp 'magit-file-at-point)
                      (ignore-errors (magit-file-at-point))))
           (path (when file
                   (llm-context--copy-abbrev-path
                    (if (file-name-absolute-p file)
                        file
                      (expand-file-name file (or root default-directory))))))
           (rev (bound-and-true-p magit-buffer-revision))
           (range (bound-and-true-p magit-buffer-range))
           (logrev (and (not file) (not rev)
                        (fboundp 'magit-thing-at-point)
                        (ignore-errors (magit-thing-at-point 'git-revision t)))))
      (cond
       (rev
        (let ((desc (llm-context--copy-magit-rev-desc rev)))
          (if path (format "%s @ %s" path desc) desc)))
       ((and (stringp range) (string-match-p "\\.\\." range))
        (if path (format "%s @ %s" path range) (format "git:%s" range)))
       (file
        (let ((state (llm-context--copy-magit-staging)))
          (if state (format "%s (%s)" path state) path)))
       (logrev
        (llm-context--copy-magit-rev-desc logrev))))))

(defun llm-context--copy-magit-hunks (section)
  "Return the list of hunk sections at or below SECTION."
  (require 'cl-lib)
  (require 'eieio)
  (if (eq (slot-value section 'type) 'hunk)
      (list section)
    (mapcan #'llm-context--copy-magit-hunks
            (slot-value section 'children))))

(defun llm-context--copy-magit-content ()
  "Return unified-diff text for the Magit hunk(s) at point or in the region.
With an active region include every hunk it overlaps; otherwise include
the hunk(s) under the section at point.  Each hunk keeps its @@ header so
line numbers survive.  Returns nil when point is not over any diff."
  (when (derived-mode-p 'magit-mode)
    (require 'seq)
    (let* ((root (bound-and-true-p magit-root-section))
           (hunks
            (cond
             ((null root) nil)
             ((use-region-p)
              (let ((beg (region-beginning))
                    (end (region-end)))
                (seq-filter
                 (lambda (h) (and (< (slot-value h 'start) end)
                                  (> (slot-value h 'end) beg)))
                 (llm-context--copy-magit-hunks root))))
             (t (let ((section (and (fboundp 'magit-current-section)
                                    (magit-current-section))))
                  (and section (llm-context--copy-magit-hunks section)))))))
      (when hunks
        (mapconcat
         (lambda (h)
           (let ((text (buffer-substring-no-properties
                        (slot-value h 'start) (slot-value h 'end))))
             (if (string-suffix-p "\n" text) text (concat text "\n"))))
         hunks "")))))

(defun llm-context--copy-special-ref ()
  "Return context references for non-file result buffers."
  (or (llm-context--copy-magit-ref)
      (llm-context--copy-diff-ref)
      (llm-context--copy-compilation-ref)
      (llm-context--copy-xref-ref)
      (llm-context--copy-occur-ref)
      (when (derived-mode-p 'Info-mode)
        (format "info:%s#%s"
                (or (bound-and-true-p Info-current-file) "*Info*")
                (or (bound-and-true-p Info-current-node) "Top")))
      (when (memq major-mode '(help-mode helpful-mode))
        (format "help:%s"
                (or (thing-at-point 'symbol t) (buffer-name))))))

(defun llm-context--copy-region-lines ()
  "Return selected line range as (BEG . END), fixing end-at-BOL selections."
  (let* ((beg-pos (region-beginning))
         (end-pos (region-end))
         (last-pos
          (if (and (> end-pos beg-pos)
                   (save-excursion (goto-char end-pos) (bolp)))
              (save-excursion
                (goto-char end-pos)
                (forward-line -1)
                (line-end-position))
            (max beg-pos (1- end-pos)))))
    (cons (line-number-at-pos beg-pos t)
          (line-number-at-pos last-pos t))))

(defun llm-context--copy-emacs-context ()
  "Return a compact description of the current Emacs buffer state."
  (when llm-context-include-emacs-context
    (let ((minor-modes
           (delq nil
                 (mapcar (lambda (mode)
                           (when (and (boundp mode) (symbol-value mode))
                             (symbol-name mode)))
                         minor-mode-list))))
      (format
       "\n\n```emacs-context\ndaemon: %s\nbuffer: %s\nmajor-mode: %s\nminor-modes: %s\npoint: %d\nnarrowed: %s\n```\n"
       (or (daemonp) "none")
       (buffer-name)
       major-mode
       (if minor-modes (string-join minor-modes ", ") "none")
       (line-number-at-pos (point) t)
       (if (buffer-narrowed-p) "yes" "no")))))

(defun llm-context--copy-emacs-context-buffer-p
    (file eww-p dired-paths special-ref magit-p)
  "Return non-file, non-web buffers that should use Emacs context."
  (and (not file)
       (not eww-p)
       (not dired-paths)
       (not magit-p)
       (or (memq major-mode
                 '(help-mode helpful-mode Info-mode shell-mode eshell-mode
                   term-mode comint-mode messages-buffer-mode debugger-mode
                   backtrace-mode Man-mode woman-mode package-menu-mode
                   ibuffer-mode tabulated-list-mode vc-dir-mode
                   org-agenda-mode calendar-mode))
           (not special-ref))))

;;;###autoload
(defun llm-context-copy (&optional force-content)
  "Copy current line or selected region as LLM-friendly context.
Format:
~/.../path:line-range   (or path://URL for eww buffer, no line numbers)

```emacs-lisp
code
```

In dired/dirvish, copy marked files or the file at point.  In Magit, copy
the diff hunk(s) at point or across the region as a unified diff, with a
reference that encodes the working-tree staging state, the shown commit
\(SHA + subject), or a diff range; an over-long diff is omitted unless
FORCE-CONTENT.  In compilation, grep, xref, occur, and plain diff buffers,
prefer source file or revision references over buffer-local line numbers.
With prefix argument FORCE-CONTENT, include selected text even when it
exceeds `llm-context-max-lines'."
  (interactive "P")
  (let* ((dired-paths (llm-context--copy-dired-paths))
         (magit-p (derived-mode-p 'magit-mode))
         (magit-content-raw (when (and magit-p (not dired-paths))
                              (llm-context--copy-magit-content)))
         (magit-content-lines (when magit-content-raw
                                (llm-context--copy-line-count
                                 magit-content-raw)))
         (magit-omitted (and magit-content-raw (not force-content)
                             (> magit-content-lines
                                llm-context-max-lines)))
         (special-ref (llm-context--copy-special-ref))
         (eww-p (derived-mode-p 'eww-mode))
         (selection-lines (when (use-region-p)
                            (llm-context--copy-line-count
                             (buffer-substring-no-properties
                              (region-beginning) (region-end)))))
         (file (or (buffer-file-name)
                   (buffer-file-name (buffer-base-buffer))))
         (emacs-context-p
          (llm-context--copy-emacs-context-buffer-p
           file eww-p dired-paths special-ref magit-p))
         (path (cond (dired-paths nil)
                     (emacs-context-p nil)
                     (special-ref nil)
                     (eww-p (or (plist-get (bound-and-true-p eww-data) :url)
                                (bound-and-true-p eww-current-url)
                                "eww"))
                     (file (llm-context--copy-abbrev-path file))
                     (t (buffer-name))))
         (line-range (when (and path (not eww-p))
                       (if (use-region-p)
                           (llm-context--copy-region-lines)
                         (let ((line (line-number-at-pos (point) t)))
                           (cons line line)))))
         (line-count (when line-range
                       (1+ (- (cdr line-range) (car line-range)))))
         (ref (cond
               (dired-paths
                (mapconcat #'llm-context--copy-abbrev-path dired-paths "\n"))
               (emacs-context-p (format "emacs-context:%s" (buffer-name)))
               (special-ref special-ref)
               ((and line-range (= (car line-range) (cdr line-range)))
                (format "%s:%d" path (car line-range)))
               (line-range
                (format "%s:%d-%d" path (car line-range) (cdr line-range)))
               (t path)))
         (content
          (cond
           ((and magit-content-raw (not magit-omitted))
            (format "\n\n```diff\n%s```\n" magit-content-raw))
           ((and (not dired-paths)
                 (not magit-p)
                 (or special-ref line-count eww-p emacs-context-p)
                 (or (not (use-region-p))
                     force-content
                     (<= (or line-count selection-lines)
                         llm-context-max-lines)))
            (let ((text (if (use-region-p)
                            (buffer-substring-no-properties
                             (region-beginning)
                             (region-end))
                          (buffer-substring-no-properties
                           (line-beginning-position)
                           (line-end-position))))
                  (lang (llm-context--copy-language)))
              (format "\n\n```%s\n%s\n```\n" lang text))))))
    (kill-new (concat ref (or content "")
                      (if emacs-context-p
                          (or (llm-context--copy-emacs-context) "")
                        "")))
    (message "Copied LLM context: %s%s" ref
             (cond (magit-omitted
                    (format " (diff omitted: %d lines > %d; C-u to include)"
                            magit-content-lines llm-context-max-lines))
                   (magit-content-raw " + diff")
                   (t "")))))

(provide 'llm-context)
;;; llm-context.el ends here
