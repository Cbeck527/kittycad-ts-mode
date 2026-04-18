;;; kittycad-ts-mode.el --- Tree-sitter major mode for KCL -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Chris Becker
;; SPDX-License-Identifier: MIT

;; Author: Chris Becker <chris@becker.am>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages kcl tree-sitter

;;; Commentary:

;; `kittycad-ts-mode' provides a tree-sitter based major mode for KCL
;; (KittyCAD Language) files.
;;
;; The mode provides syntax highlighting, indentation, comment handling,
;; imenu support, and defun navigation.
;;
;; Load this file, then either open a .kcl file or run:
;;
;;   M-x treesit-install-language-grammar RET kcl RET
;;
;; This package registers the KCL grammar source automatically.
;;
;; If you prefer to install the grammar manually, build the shared library
;; from https://github.com/KittyCAD/tree-sitter-kcl and place it in the
;; `tree-sitter/' directory under `user-emacs-directory', or in a directory
;; listed in `treesit-extra-load-path'.

;;; Code:

(require 'treesit)

(declare-function treesit-language-available-p "treesit.c")
(declare-function treesit-node-parent "treesit.c")
(declare-function treesit-node-type "treesit.c")
(declare-function treesit-parser-create "treesit.c")

(unless (treesit-available-p)
  (error "kittycad-ts-mode requires Emacs with tree-sitter support"))

;;; Emacs 29 compatibility

(unless (facep 'font-lock-number-face)
  (defface font-lock-number-face
    '((t :inherit font-lock-constant-face))
    "Face used for numbers."
    :group 'font-lock-faces))

(unless (facep 'font-lock-operator-face)
  (defface font-lock-operator-face
    '((t :inherit default))
    "Face used for operators."
    :group 'font-lock-faces))

(unless (facep 'font-lock-bracket-face)
  (defface font-lock-bracket-face
    '((t :inherit default))
    "Face used for brackets."
    :group 'font-lock-faces))

(unless (facep 'font-lock-delimiter-face)
  (defface font-lock-delimiter-face
    '((t :inherit default))
    "Face used for delimiters."
    :group 'font-lock-faces))

;;; Grammar source

(unless (assoc 'kcl treesit-language-source-alist)
  (add-to-list 'treesit-language-source-alist
               '(kcl "https://github.com/KittyCAD/tree-sitter-kcl")))

(defgroup kittycad nil
  "Support for KCL (KittyCAD Language)."
  :group 'languages)

(defcustom kittycad-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `kittycad-ts-mode'."
  :type 'integer
  :safe #'integerp
  :group 'kittycad)

(defvar kittycad-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_ "_" table)
    (modify-syntax-entry ?\\ "\\" table)
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?% "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?& "." table)
    (modify-syntax-entry ?| "." table)
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?\^m "> b" table)
    table)
  "Syntax table for `kittycad-ts-mode'.")

(defvar kittycad-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'kcl
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'kcl
   :feature 'string
   '((string) @font-lock-string-face)

   :language 'kcl
   :feature 'string
   :override t
   '((escape_sequence) @font-lock-escape-face)

   :language 'kcl
   :feature 'keyword
   '(["fn" "return" "import" "export" "if" "else" "else if" "as"]
     @font-lock-keyword-face)

   :language 'kcl
   :feature 'definition
   :override t
   '((fn_definition
      (identifier) @font-lock-function-name-face)
     (non_fn_definition
      (identifier) @font-lock-variable-name-face)
     (param
      (identifier) @font-lock-variable-name-face)
     (import_stmt
      (identifier) @font-lock-variable-name-face))

   :language 'kcl
   :feature 'function
   :override t
   '((fn_call
      callee: (identifier) @font-lock-function-call-face))

   :language 'kcl
   :feature 'assignment
   :override t
   '((labeledArg
      label: (identifier) @font-lock-variable-name-face)
     (type_name
      (identifier) @font-lock-type-face)
     (type_name
      units: (identifier) @font-lock-type-face)
     (boolean) @font-lock-constant-face
     (number) @font-lock-number-face
     (shebang) @font-lock-preprocessor-face
     (annotation) @font-lock-preprocessor-face)

   :language 'kcl
   :feature 'operator
   '((binary_operator) @font-lock-operator-face
     (prefix_operator) @font-lock-operator-face
     (pipe_sub) @font-lock-operator-face)

   :language 'kcl
   :feature 'bracket
   '(["(" ")" "[" "]" "{" "}"] @font-lock-bracket-face)

   :language 'kcl
   :feature 'delimiter
   '(([","]) @font-lock-delimiter-face))
  "Tree-sitter font-lock settings for `kittycad-ts-mode'.")

(defvar kittycad-ts-mode--font-lock-feature-list
  '((comment string keyword)
    (definition)
    (function assignment)
    (operator bracket delimiter))
  "Tree-sitter font-lock feature list for `kittycad-ts-mode'.")

(defvar kittycad-ts-mode--indent-rules
  `((kcl
     ((node-is "}") parent-bol 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((parent-is "fn_definition") parent-bol kittycad-ts-mode-indent-offset)
     ((parent-is "if_expr") parent-bol kittycad-ts-mode-indent-offset)
     ((parent-is "param_list") parent-bol kittycad-ts-mode-indent-offset)
     ((parent-is "fn_call") parent-bol kittycad-ts-mode-indent-offset)
     ((parent-is "array_expr") parent-bol kittycad-ts-mode-indent-offset)
     ((parent-is "binary_expr") parent-bol kittycad-ts-mode-indent-offset)
     ((parent-is "kcl_program") column-0 0)
     (no-node parent-bol 0)))
  "Tree-sitter indentation rules for `kittycad-ts-mode'.")

(defvar kittycad-ts-mode--imenu-settings
  '(("Function" "\\`fn_definition\\'" kittycad-ts-mode--top-level-node-p kittycad-ts-mode--defun-name)
    ("Variable" "\\`non_fn_definition\\'" kittycad-ts-mode--top-level-node-p kittycad-ts-mode--defun-name))
  "Imenu settings for `kittycad-ts-mode'.")

(defun kittycad-ts-mode--first-child-of-type (node type)
  "Return NODE's first named child whose type is TYPE.
Return nil when NODE has no matching child."
  (catch 'match
    (dolist (child (treesit-node-children node t))
      (when (equal (treesit-node-type child) type)
        (throw 'match child)))))

(defun kittycad-ts-mode--defun-name (node)
  "Return the name for definition NODE.
Return nil when NODE is not a supported definition node."
  (when (member (treesit-node-type node)
                '("fn_definition" "non_fn_definition"))
    (let ((name-node (kittycad-ts-mode--first-child-of-type node "identifier")))
      (when name-node
        (treesit-node-text name-node t)))))

(defun kittycad-ts-mode--top-level-node-p (node)
  "Return non-nil when NODE is a top-level definition."
  (let ((declaration (treesit-node-parent node)))
    (and declaration
         (equal (treesit-node-type declaration) "variable_declaration")
         (let ((body-item (treesit-node-parent declaration)))
           (and body-item
                (equal (treesit-node-type body-item) "body_item")
                (let ((root (treesit-node-parent body-item)))
                  (and root
                       (equal (treesit-node-type root) "kcl_program"))))))))

(defun kittycad-ts-mode--ensure-grammar ()
  "Ensure the KCL tree-sitter grammar is available.
Prompt to install it when needed."
  (unless (treesit-language-available-p 'kcl)
    (when (y-or-n-p "KCL tree-sitter grammar is not installed. Install it now? ")
      (treesit-install-language-grammar 'kcl)))
  (treesit-ready-p 'kcl))

;;;###autoload
(define-derived-mode kittycad-ts-mode prog-mode "KCL"
  "Major mode for editing KCL files with tree-sitter."
  :group 'kittycad
  :syntax-table kittycad-ts-mode--syntax-table

  (unless (kittycad-ts-mode--ensure-grammar)
    (error "Cannot activate kittycad-ts-mode without the KCL tree-sitter grammar"))

  (treesit-parser-create 'kcl)

  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "//+ *")

  (setq-local treesit-font-lock-settings kittycad-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              kittycad-ts-mode--font-lock-feature-list)

  (setq-local treesit-simple-indent-rules kittycad-ts-mode--indent-rules)

  (setq-local treesit-defun-type-regexp "\\`fn_definition\\'")
  (setq-local treesit-defun-name-function #'kittycad-ts-mode--defun-name)

  (setq-local treesit-simple-imenu-settings kittycad-ts-mode--imenu-settings)

  (treesit-major-mode-setup))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.kcl\\'" . kittycad-ts-mode))

(provide 'kittycad-ts-mode)

;;; kittycad-ts-mode.el ends here
