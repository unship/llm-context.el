# llm-context.el

Copy Emacs context in a format useful to LLM coding tools.

`M-x llm-context-copy` copies a reference and optional source text. For
temporary, non-file, non-web buffers it uses an `emacs-context` reference and
adds a block describing the current Emacs state.

## Installation

```elisp
(use-package llm-context
  :ensure t
  :bind (("C-c y c" . llm-context-copy)))
```

Doom Emacs:

```elisp
(package! llm-context
  :recipe (:host github :repo "unship/llm-context.el"))
```

Run `doom sync` after adding the package. Then restart the daemon.

## Basic file buffers

Run `M-x llm-context-copy` with point on one line:

~~~~text
~/src/app.el:42

```emacs-lisp
(message "hello")
```

~~~~

Select lines 10 through 14 to copy a range:

~~~~text
~/src/app.py:10-14

```python
def answer():
    return 42
```

~~~~

Selections ending at the beginning of the next line exclude that next line.
Selections longer than `llm-context-max-lines` (100 by default) omit the source
block. Use `C-u M-x llm-context-copy` to force it back in.

## Dired and Dirvish

With files marked, each path is copied on its own line:

~~~~text
~/src/app.el
~/src/lib/util.py

~~~~

With no marks, the file at point is copied. If point is not on a file, the
current directory is copied.

## EWW

Without a region, EWW copies only the URL:

~~~~text
https://example.com/article
~~~~

With text selected in the rendered page, it copies the URL and selected text:

~~~~text
https://example.com/article

```text
The selected paragraph from the page.
```

~~~~

## Magit

At a Magit hunk, it copies a unified diff and its source reference:

~~~~text
~/src/app.el (unstaged)

```diff
@@ -42,1 +42,1 @@
-old value
+new value
```

~~~~

Staged and untracked files use `(staged)` and `(untracked)`. A commit view
includes SHA and subject:

```text
~/src/app.el @ e63a038 — fix parser error
```

A range view uses:

```text
~/src/app.el @ main..feature/parser
```

A diff longer than the configured limit is copied without its diff body. Use a
prefix argument to include it.

## Result buffers with source locations

Compilation, grep, xref, occur, and plain diff buffers use the source file and
line when Emacs can resolve one:

~~~~text
~/src/parser.py:87

```python
raise ParseError(token)
```
~~~~

If no source location is available, the command falls back to the result
buffer's `emacs-context` reference and its current line or selected region.

## Help and documentation

### help-mode and helpful-mode

These are temporary, non-file buffers, so the reference uses Emacs context.
The symbol at point and its current line (or selection) are copied:

~~~~text
emacs-context:*Help*

```text
Return the file name of the current buffer, or nil.
```
~~~~

### Info-mode

Info uses an Emacs context reference while preserving the current Info file
and node in the buffer state:

~~~~text
emacs-context:*info*

```text
Buffers are objects that hold text to be edited.
```
~~~~

### Man-mode and woman-mode

The manual page is a temporary buffer, so it uses Emacs context:

~~~~text
emacs-context:*Man git-commit*

```text
git commit - Record changes to the repository
```
~~~~

## Shell and status buffers

`shell-mode`, `eshell-mode`, `term-mode`, and `comint-mode` use an
`emacs-context` reference and copy the current command/output line or selected
region:

~~~~text
emacs-context:*shell*

```sh
git status --short
```
~~~~

`messages-buffer-mode`, `debugger-mode`, and `backtrace-mode` use an
`emacs-context` reference and copy the current line or selection:

~~~~text
emacs-context:*Backtrace*

```text
  my-function(arg)
```
~~~~

`package-menu-mode`, `ibuffer-mode`, `tabulated-list-mode`, `vc-dir-mode`,
`org-agenda-mode`, and `calendar-mode` also use an `emacs-context` reference
and copy the current row/entry or selected region:

~~~~text
emacs-context:*Packages*

```text
U  magit   4.3.0   A Git porcelain inside Emacs
U  gptel   0.9.8   A large language model chat client
```
~~~~

## Emacs internal context

For a temporary, non-file, non-web buffer such as `helpful-mode`, the
reference is an Emacs context instead of a fake `buffer:line` path:

~~~~text
emacs-context:*Help*

```text
describe-variable: buffer-file-name
```

```emacs-context
daemon: doom
buffer: *scratch*
major-mode: emacs-lisp-mode
minor-modes: evil-local-mode, company-mode
point: 18
narrowed: no
help-object: buffer-file-name
```
~~~~

The daemon value comes from `daemonp`: it is the daemon name for a daemon
client, and `none` for a regular Emacs process. Disable the block if only the
reference and source text are wanted:

```elisp
(setq llm-context-include-emacs-context nil)
```

## Configuration

```elisp
(setq llm-context-max-lines 200)
```

## License

GPL-3.0-or-later.
