;;; ob-soql.el --- org-babel functions for SOQL evaluation -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2022 James Estevez
;;
;; Author: James Estevez <j@jstvz.dev>
;; Maintainer: James Estevez <j@jstvz.dev>
;; Created: May 08, 2022
;; Modified: May 08, 2022
;; Version: 0.0.1
;; Keywords: languages outlines tools soql
;; Homepage: https://github.com/jstvz/ob-soql
;; Package-Requires: ((emacs "24.3"))
;;
;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Executes Salesforce Object Query Language queries

;;; Requirements:

;; Use this section to list the requirements of this language.  Most
;; languages will require that at least the language be installed on
;; the user's system, and the Emacs major mode relevant to the
;; language be installed as well.

;;; Code:
(require 'ob)
(require 'ob-ref)
(require 'ob-comint)
(require 'ob-eval)
;; possibly require modes required for your language

(defcustom ob-soql-sfdx-cli-path nil
  "Path to SFDX executable."
  :group 'org-babel
  :type 'string)

;; optionally define a file extension for this language
(add-to-list 'org-babel-tangle-lang-exts '("soql" . "soql"))

;; (:results . "output") optionally declare default header arguments for this language
(defvar org-babel-default-header-args:soql '((:resultformat . "csv")))

;; This function expands the body of a source code block by doing things like
;; prepending argument definitions to the body, it should be called by the
;; `org-babel-execute:soql' function below. Variables get concatenated in
;; the `mapconcat' form, therefore to change the formatting you can edit the
;; `format' form.
(defun org-babel-expand-body:soql (body params &optional processed-params)
  "Expand BODY according to PARAMS, return the expanded body."
  (require 'inf-soql nil t)
  (let ((vars (org-babel--get-vars (or processed-params (org-babel-process-params params)))))
    (concat "\"" body "\"")))

;; This is the main function which is called to evaluate a code
;; block.
;;
;; This function will evaluate the body of the source code and
;; return the results as emacs-lisp depending on the value of the
;; :results header argument
;; - output means that the output to STDOUT will be captured and
;;   returned
;; - value means that the value of the last statement in the
;;   source code block will be returned
;;
;; The most common first step in this function is the expansion of the
;; PARAMS argument using `org-babel-process-params'.
;;
;; Please feel free to not implement options which aren't appropriate
;; for your language (e.g. not all languages support interactive
;; "session" evaluation).  Also you are free to define any new header
;; arguments which you feel may be useful -- all header arguments
;; specified by the user will be available in the PARAMS variable.
(defun org-babel-execute:soql (body params)
  "Execute a BODY containing a SOQL query with org-babel using PARAMS.

This function is called by `org-babel-execute-src-block'"
  (message "executing Soql source code block")
  (let* ((processed-params (org-babel-process-params params))
         ;; variables assigned for use in the block
         (vars (org-babel--get-vars processed-params))
         (result-params (assq :result-params processed-params))
         ;; either OUTPUT or VALUE which should behave as described above
         (result-type (assq :result-type processed-params))
         ;; expand the body with `org-babel-expand-body:soql'
         (full-body (org-babel-expand-body:soql
                     body params processed-params))
         (username (cdr (assq :username params)))
         (resultformat (or (cdr (assq :resultformat params))
                       "csv"))
         (sfdx-cli (or (executable-find "sfdx")
                       ob-soql-sfdx-cli-path
                       (error
                        "`ob-soql-sfdx-cli-path' is not set and sfdx is not in `exec-path'")))
         (cmd (concat (shell-quote-argument (expand-file-name sfdx-cli))
                      " force:data:soql:query "
                      (when username
                        (concat " -u " username))
                      (when resultformat
                        (concat " -r " resultformat))
                      " -q " full-body)))
    ;; actually execute the source-code block either in a session or
    ;; possibly by dropping it to a temporary file and evaluating the
    ;; file.
    (unless (file-executable-p sfdx-cli)
      ;; cannot happen with `executable-find', so we complain about
      ;; `ob-soql-sfdx-cli-path'
      (error "Cannot find or execute %s, please check `ob-soql-sfdx-cli-path'" sfdx-cli))
    (message "%s" cmd)
    (org-babel-eval cmd "")))

(defun org-babel-soql-var-to-soql (var)
  "Convert an elisp var into a string of soql source code
specifying a var of the same value."
  (format "%S" var))

(provide 'ob-soql)
;;; ob-soql.el ends here
