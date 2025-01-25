;;; md.el --- Package for editing MARKDOWN files using tree-sitter -*- lexical-binding: t; -*-

;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Homepage: https://github.com/eki3z/md.el

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

;; A package for editing markdown files

;;; Code:

(require 'md-ts-mode)
(require 'md-util)
(require 'md-view)

;;; Custom variables

(defgroup md nil
  "Package for markdown related markup language."
  :prefix "md-"
  :group 'text
  :link '(url-link "https://github.com/eki3z/md.el"))

(provide 'md)

;;; md.el ends here
