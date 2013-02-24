;;; edebug-x.el --- extensions for Edebug

;; Copyright (C) 2013  Scott Barnett

;; Author: Scott Barnett
;; Keywords: extensions

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Extension to Edebug to make it a little nicer to work with.

;; Breakpoints can now be toggled from an Elisp buffer without first
;; running Edebug with `edebug-x-modify-breakpoint-wrapper', bound to
;; `C-x SPC'. If the function isn't instrumented already then it will
;; instrument it and then set the breakpoint.

;; The list of current break points can be viewed with
;; `edebug-x-show-breakpoints', bound to `C-c C-x b'. From the
;; tabulated list buffer the following commands are available:

;; `edebug-x-kill-breakpoint' bound to `K': clear breakpoint
;; `edebug-x-visit-breakpoint' bound to `RET': visit breakpoint location

;; To view a list of instrumented functions execute `C-c C-x i',
;; `edebug-x-show-instrumented'. The instrumented functions buffer has
;; these commands:

;; `edebug-x-evaluate-function' bound to `E': evaluate function,
;; clearing breakpoints within it.
;; `edebug-x-find-function' bound to `RET': jump to function.

;; There is also a convenience command, `edebug-x-show-data' (bound to
;; `C-c C-x s') which will split the window into two showing both the
;; breakpoints and instrumented function buffers. Executing `Q' will
;; remove both these buffers.

;;; Code:

(require 'which-func)
(require 'dash)
(require 'cl)

(defface hi-edebug-x-stop
  '((((background dark)) (:background "plum1" :foreground "black"))
    (t (:background "wheat")))
  "Face for Edebug breakpoints.")

(defvar instrumented-forms '()
  "Stores all instrumented forms. Format is (symbol name . buffer position).")

(defun edebug-x-highlight-line ()
  "Create an overlay at line."
  (interactive)
  (setq overlay (make-overlay (line-beginning-position) (line-end-position)))
  (overlay-put overlay 'face 'hi-edebug-x-stop)
  (overlay-put overlay 'edebug-x-hi-lock-overlay t))

(defun edebug-x-remove-highlight ()
  "Remove overlay at point if present."
  (interactive)
  (if (find-if (lambda (elt) (equal (car (overlay-properties elt)) 'edebug-x-hi-lock-overlay))
               (overlays-at (point)))
      (progn
        (remove-overlays (overlay-start overlay)
                         (overlay-end overlay) 'edebug-x-hi-lock-overlay t))))

(defadvice edebug-make-form-wrapper (after edebug-x-make-form-wrapper
                                           (cursor form-begin form-end
                                                   &optional speclist)
                                           activate)
  "Highlight the form being wrapped and save it to a list."
  (save-excursion
    (let* ((func (which-function)))
      (beginning-of-defun)
      (if (not (-contains? instrumented-forms func))
          (add-to-list 'instrumented-forms `(,func . ,(point))))
      (edebug-x-highlight-line))))

(defadvice edebug-read-sexp (before edebug-x-read-sexp activate)
  "Stores forms instrumented and removes overlay if present."
  (let* ((func (which-function)))
    (setq instrumented-forms
          (-remove (lambda (elemt) (equal (car elemt) func)) instrumented-forms))
    (save-excursion
      (remove-overlays (point)
                       (progn (forward-sexp 1) (point)) 'edebug-x-hi-lock-overlay t))))

(defun instrumentedp (fun-symbol)
  (unless (functionp fun-symbol)
    (error "FUN-SYMBOL is not a function"))
  (let ((data (get fun-symbol 'edebug)))
    (unless (markerp data)
      data)))

(defun edebug-x-modify-breakpoint-wrapper ()
  "Set a breakpoint from an Elisp file.
The current function that pointer is in will be instrumented if
not already."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (let* ((func-symbol (intern (which-function)))
           (edebug-data (get func-symbol 'edebug))
           (breakpoints (and (not (markerp edebug-data)) (car (cdr edebug-data))))
           (removed (-remove (lambda (elt) (= (cdr (edebug-find-stop-point)) (car elt)))
                             breakpoints)))
      (if (not (instrumentedp func-symbol))
          (edebug-eval-top-level-form))
      (if (= (length breakpoints) (length removed))
          (progn
            (edebug-x-highlight-line)
            (edebug-modify-breakpoint t))
        (edebug-x-remove-highlight)
        (edebug-modify-breakpoint nil)))))

(defadvice edebug-set-breakpoint (before edebug-x-set-breakpoint-highlight
                                         (arg)
                                         activate)
  "Highlights the current line."
  (edebug-x-highlight-line))

(defadvice edebug-unset-breakpoint (before edebug-x-unset-breakpoint-highlight
                                           activate)
  "Remove highlights from the current line."
  (edebug-x-remove-highlight))

(defun edebug-x-visit-breakpoint ()
  "Navigate to breakpoint at line."
  (interactive)
  (destructuring-bind (func-name pos &optional condition temporary)
      (split-string (buffer-substring-no-properties
                     (line-beginning-position)
                     (line-end-position)))
    (find-function (intern func-name))
    (goto-char (string-to-number pos))))

(defun edebug-x-clear-data ()
  "Delete the window setup after `edebug-show-data'."
  (interactive)
  (delete-other-windows)
  (switch-to-prev-buffer))

(defun edebug-x-kill-breakpoint ()
  "Remove breakpoint at line."
  (interactive)
  (destructuring-bind (func-name pos &optional condition temporary)
      (split-string (buffer-substring-no-properties
                     (line-beginning-position)
                     (line-end-position)))
    (when (y-or-n-p (format "Edebug breakpoints: delete breakpoint %s?" func-name))
      (save-excursion
        (edebug-x-visit-breakpoint)
        (edebug-x-modify-breakpoint-wrapper)))
    (switch-to-prev-buffer)
    (revert-buffer)))

(defun edebug-x-list-breakpoints ()
  "Checks all the instrumented functions for any breakpoints.
Returns a tablulated list friendly result to be displayed in
edebug-breakpoint-list-mode."
  (let ((results))
    (-each instrumented-forms
           (lambda (form)
             (let* ((edebug-data (get (intern (car form)) 'edebug))
                    (pos (cdr form))
                    (func-name (car form))
                    (breakpoints (car (cdr edebug-data)))
                    (stop-points (nth 2 edebug-data)))
               (loop for i in breakpoints do
                     (add-to-list
                      'results
                      (list form
                            (vconcat `(,func-name)
                                     (list (number-to-string (+ pos (aref stop-points (car i)))))
                                     ;; FIXME: need to check values for last two elements stored as a breakpoint
                                     (mapcar (lambda (ele) (if ele else "")) (cdr i)))))))))
    results))

(define-derived-mode
  edebug-x-breakpoint-list-mode tabulated-list-mode "Edebug Breakpoints"
  "Major mode for listing Edebug breakpoints"
  (setq tabulated-list-entries 'edebug-x-list-breakpoints)
  (setq tabulated-list-format
        [("Function name" 50 nil)
         ("Position" 20 nil)
         ("Condition" 20 nil)
         ("Temporary" 20 nil)])
  (define-key edebug-x-breakpoint-list-mode-map (kbd "RET") 'edebug-x-visit-breakpoint)
  (define-key edebug-x-breakpoint-list-mode-map (kbd "K") 'edebug-x-kill-breakpoint)
  (define-key edebug-x-breakpoint-list-mode-map (kbd "Q") 'edebug-x-clear-data)
  (tabulated-list-init-header))

(defun edebug-x-evaluate-function ()
  "Evaluate function on line.
This removes all breakpoints in this function."
  (interactive)
  (let ((function-name (car (split-string (buffer-substring-no-properties
                                           (line-beginning-position)
                                           (line-end-position))))))
    (when (y-or-n-p (format "Edebug instrumented functions: evaluate function %s?" function-name))
      (find-function (intern function-name))
      (eval-defun nil)
      (switch-to-prev-buffer)
      (revert-buffer))))

(defun edebug-x-find-function ()
  "Navigate to function from the instrumented function buffer."
  (interactive)
  (let ((function-name (car (split-string (buffer-substring-no-properties
                                           (line-beginning-position)
                                           (line-end-position))))))
    (find-function (intern function-name))))

(defun edebug-x-list-instrumented-functions ()
  "Return the list of instrumented functions.
Tabulated buffer ready."
  (-map (lambda (item) (list (car item) (vector (car item)))) instrumented-forms))

(define-derived-mode
  edebug-x-instrumented-function-list-mode tabulated-list-mode "Edebug Instrumented functions"
  "Major mode for listing instrumented functions"
  (setq tabulated-list-entries 'edebug-x-list-instrumented-functions)
  (setq tabulated-list-format
        [("Instrumented Functions" 50 nil)])
  (define-key edebug-x-instrumented-function-list-mode-map (kbd "E") 'edebug-x-evaluate-function)
  (define-key edebug-x-instrumented-function-list-mode-map (kbd "Q") 'edebug-x-clear-data)
  (define-key edebug-x-instrumented-function-list-mode-map (kbd "RET") 'edebug-x-find-function)
  (tabulated-list-init-header))

(defun edebug-x-show-data ()
  "Display instrumented functions and edebug breakpoints.
Frame is split into two vertically showing the tabluated buffers
for each."
  (interactive)
  (delete-other-windows)
  (let ((buff-breakpoints (get-buffer-create "*Edebug Breakpoints*"))
        (buff-instrumented (get-buffer-create "*Instrumented Functions*")))
    (with-current-buffer buff-breakpoints
      (edebug-x-breakpoint-list-mode)
      (tabulated-list-print))
    (with-current-buffer buff-instrumented
      (edebug-x-instrumented-function-list-mode)
      (tabulated-list-print))
    (switch-to-buffer buff-breakpoints)
    (set-window-buffer (split-window-vertically)
                       buff-instrumented)))

(defun edebug-x-show-breakpoints ()
  "Display breakpoints in a tabulated list buffer."
  (interactive)
  (switch-to-buffer (get-buffer-create "*Edebug Breakpoints*"))
  (edebug-x-breakpoint-list-mode)
  (tabulated-list-print))

(defun edebug-x-show-instrumented ()
  "Display instrumented functions in a tabluated list buffer."
  (interactive)
  (switch-to-buffer (get-buffer-create "*Instrumented Functions*"))
  (edebug-x-instrumented-function-list-mode)
  (tabulated-list-print))

(define-key emacs-lisp-mode-map (kbd "C-x SPC") 'edebug-x-modify-breakpoint-wrapper)
(define-key emacs-lisp-mode-map (kbd "C-c C-x s") 'edebug-x-show-data)
(define-key emacs-lisp-mode-map (kbd "C-c C-x b") 'edebug-x-show-breakpoints)
(define-key emacs-lisp-mode-map (kbd "C-c C-x i") 'edebug-x-show-instrumented)

(provide 'edebug-x)

;;; edebug-x.el ends here
