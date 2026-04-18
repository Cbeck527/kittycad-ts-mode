# kittycad-ts-mode

`kittycad-ts-mode` is an Emacs major mode for editing KCL (KittyCAD Language)
files with Emacs's built-in tree-sitter support.

It provides syntax highlighting, indentation, comment handling, imenu support,
and defun navigation in a single `kittycad-ts-mode.el` file.

## Requirements

- Emacs 29.1 or newer
- Emacs built with tree-sitter support
- The KCL tree-sitter grammar

## Installation

### 1. Install the package

Choose one of these installation methods.

#### Install with `elpaca`

```elisp
(use-package kittycad-ts-mode
  :ensure (:host github :repo "Cbeck527/kittycad-ts-mode"))
```

#### Install with `straight.el`

```elisp
(use-package kittycad-ts-mode
  :straight (kittycad-ts-mode :type git :host github :repo "Cbeck527/kittycad-ts-mode"))
```

#### Manual install

Clone the repository into `~/.emacs.d/site-lisp/kittycad-ts-mode/`:

```sh
git clone https://github.com/Cbeck527/kittycad-ts-mode.git ~/.emacs.d/site-lisp/kittycad-ts-mode
```

Then load it with `use-package`:

```elisp
(use-package kittycad-ts-mode
  :load-path (locate-user-emacs-file "site-lisp/kittycad-ts-mode"))
```

### 2. Install the grammar

After the package is loaded, you can let Emacs build and install the grammar:

1. Run `M-x treesit-install-language-grammar RET kcl RET`
2. Or open a `.kcl` file and let `kittycad-ts-mode` prompt you to install it

This package adds the following recipe to `treesit-language-source-alist`:

- `kcl` → `https://github.com/KittyCAD/tree-sitter-kcl`

### Manual grammar installation

If you prefer to build the shared library yourself:

1. Build the KCL grammar from <https://github.com/KittyCAD/tree-sitter-kcl>
2. Place the resulting shared library in the `tree-sitter/` directory under
   `user-emacs-directory`, or add its directory to `treesit-extra-load-path`

Emacs looks in `treesit-extra-load-path` first, then in the `tree-sitter/`
subdirectory of `user-emacs-directory`.

## Features

- Tree-sitter syntax highlighting for KCL keywords, strings, comments,
  definitions, types, numbers, operators, brackets, and delimiters
- Tree-sitter indentation for function bodies, if/else blocks, parameter lists,
  function calls, arrays, and binary-expression continuations
- `comment-dwim` support with `// ` comments
- Imenu entries for top-level functions and variables
- `beginning-of-defun` / `end-of-defun` navigation for function definitions
- Automatic `*.kcl` file association

## Configuration

The default indentation width is 2 spaces.

```elisp
(setq kittycad-ts-mode-indent-offset 4)
```

## Development notes

The mode is intentionally small and follows the shape of Emacs built-in
`json-ts-mode.el`: one file, top-level tree-sitter settings, and a single
`define-derived-mode` form.
