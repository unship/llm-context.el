# llm-context.el

Copy the current Emacs context in a format useful to LLM coding tools.

`M-x llm-context-copy` copies a file reference and, when appropriate, the
current line or region in a fenced Markdown block. It also understands Dired,
Magit hunks, compilation/grep, xref, occur, plain diff, and EWW buffers.

## Installation

With `use-package` and your package manager:

```elisp
(use-package llm-context
  :ensure t
  :bind (("C-c y c" . llm-context-copy)))
```

For Doom Emacs:

```elisp
(package! llm-context
  :recipe (:host github :repo "unship/llm-context.el"))
```

The maximum number of selected lines copied inline defaults to 100:

```elisp
(setq llm-context-max-lines 200)
```

Use a prefix argument to include an over-limit selection.

## License

GPL-3.0-or-later.
