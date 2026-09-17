;;; llm-context-test.el --- Tests for llm-context -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'llm-context)

(ert-deftest llm-context-test-language-fallback ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (should (equal (llm-context--copy-language) "emacs-lisp"))))

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
          (should (string-suffix-p
                   ":1\n\n```emacs-lisp\n(message \"hi\")\n```\n"
                   copied)))
      (delete-file file))))

;;; llm-context-test.el ends here
