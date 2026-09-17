;;; llm-context-test.el --- Tests for llm-context -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'llm-context)

(ert-deftest llm-context-test-language-fallback ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (should (equal (llm-context--copy-language) "emacs-lisp"))))

(ert-deftest llm-context-test-emacs-context-includes-daemon ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (cl-letf (((symbol-function 'daemonp) (lambda () "test-daemon")))
      (let ((context (llm-context--copy-emacs-context)))
        (should (string-match-p "daemon: test-daemon" context))
        (should (string-match-p "major-mode: emacs-lisp-mode" context))))))

(ert-deftest llm-context-test-region-lines-end-at-bol ()
  (with-temp-buffer
    (insert "one\ntwo\nthree\n")
    (set-mark (point-min))
    (goto-char 9)
    (activate-mark)
    (should (equal (llm-context--copy-region-lines) '(1 . 2)))))

(ert-deftest llm-context-test-copy-file-line ()
  (let ((file (make-temp-file "llm-context-test" nil ".el" "(message \"hi\")\n"))
        copied)
    (unwind-protect
        (with-current-buffer (find-file-noselect file)
          (goto-char (point-min))
          (cl-letf (((symbol-function 'kill-new)
                     (lambda (value &rest _) (setq copied value))))
            (llm-context-copy))
          (should (string-match-p ":1\n\n```emacs-lisp" copied))
          (should (string-match-p "```emacs-context" copied)))
      (delete-file file))))

(ert-deftest llm-context-test-eww-region-includes-text ()
  (with-temp-buffer
    (eww-mode)
    (setq eww-current-url "https://example.test/page")
    (let ((inhibit-read-only t))
      (insert "selected article text"))
    (set-mark (point-min))
    (goto-char (point-max))
    (activate-mark)
    (let (copied)
      (cl-letf (((symbol-function 'kill-new)
                 (lambda (value &rest _) (setq copied value))))
      (llm-context-copy))
      (should (string-prefix-p
               "https://example.test/page\n\n```text\nselected article text\n```\n"
               copied))
      (should (string-match-p "daemon: none" copied)))))

;;; llm-context-test.el ends here
