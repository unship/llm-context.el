# llm-context.el

Copy Emacs context in a format useful to LLM coding tools.

`M-x llm-context-copy` copies a reference, optional source text, and (by default)
an `emacs-context` block describing the current Emacs state.

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

```emacs-context
daemon: doom
buffer: app.el
major-mode: emacs-lisp-mode
minor-modes: ...
point: 42
narrowed: no
```
~~~~

Select lines 10 through 14 to copy a range:

~~~~text
~/src/app.py:10-14

```python
def answer():
    return 42
```

```emacs-context
daemon: doom
buffer: app.py
major-mode: python-mode
...
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

```emacs-context
daemon: doom
buffer: *Dired*
major-mode: dired-mode
...
```
~~~~

With no marks, the file at point is copied. If point is not on a file, the
current directory is copied.

## EWW

Without a region, EWW copies only the URL plus Emacs metadata:

~~~~text
https://example.com/article

```emacs-context
daemon: doom
buffer: *eww*
major-mode: eww-mode
...
```
~~~~

With text selected in the rendered page, it copies the URL and selected text:

~~~~text
https://example.com/article

```text
The selected paragraph from the page.
```

```emacs-context
daemon: doom
buffer: *eww*
major-mode: eww-mode
...
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

```emacs-context
daemon: doom
buffer: *magit: project*
major-mode: magit-status-mode
...
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
buffer name plus its current line or selected region.

## Help and documentation

### help-mode and helpful-mode

The symbol at point becomes the reference, and the current line (or selection)
is copied:

~~~~text
help:buffer-file-name

```text
Return the file name of the current buffer, or nil.
```
~~~~

### Info-mode

The current Info file and node become the reference:

~~~~text
info:elisp#Buffers

```text
Buffers are objects that hold text to be edited.
```
~~~~

### Man-mode and woman-mode

The manual buffer name is used as the reference:

~~~~text
*Man git-commit*:12

```text
git commit - Record changes to the repository
```
~~~~

## Shell and status buffers

`shell-mode`, `eshell-mode`, `term-mode`, and `comint-mode` copy the current
command/output line or selected region:

~~~~text
*shell*:18

```sh
git status --short
```
~~~~

`messages-buffer-mode`, `debugger-mode`, and `backtrace-mode` use the same
current-line/region behavior:

~~~~text
*Backtrace*:7

```text
  my-function(arg)
```
~~~~

`package-menu-mode`, `ibuffer-mode`, `tabulated-list-mode`, `vc-dir-mode`,
`org-agenda-mode`, and `calendar-mode` copy the current row/entry or selected
region using the buffer name and line range:

~~~~text
*Packages*:23-24

```text
U  magit   4.3.0   A Git porcelain inside Emacs
U  gptel   0.9.8   A large language model chat client
```
~~~~

## Emacs internal context

Every copy can include this compact state block, even when the buffer has no
file:

~~~~text
```emacs-context
daemon: doom
buffer: *scratch*
major-mode: emacs-lisp-mode
minor-modes: evil-local-mode, company-mode
point: 18
narrowed: no
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

