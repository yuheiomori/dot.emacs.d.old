;;; monky.el --- Control Hg from Emacs.

;; Copyright (C) 2011 Anantha Kumaran.

;; Author: Anantha kumaran <ananthakumaran@gmail.com>
;; URL: http://github.com/ananthakumaran/monky
;; Version: 0.1
;; Keywords: tools

;; Monky is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; Monky is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'cl)

(defgroup monky nil
  "Controlling Hg from Emacs."
  :prefix "monky-"
  :group 'tools)

(defcustom monky-hg-executable "hg"
  "The name of the Hg executable."
  :group 'monky
  :type 'string)

(defcustom monky-hg-standard-options '("--config" "diff.git=Off")
  "Standard options when running Hg."
  :group 'monky
  :type '(repeat string))

(defcustom monky-hg-process-environment '("TERM=dumb" "HGPLAIN=" "LANGUAGE=C")
  "Default environment variables for hg."
  :group 'monky
  :type '(repeat string))

;; TODO
(defcustom monky-save-some-buffers t
  "Non-nil means that \\[monky-status] will save modified buffers before running.
Setting this to t will ask which buffers to save, setting it to 'dontask will
save all modified buffers without asking."
  :group 'monky
  :type '(choice (const :tag "Never" nil)
		 (const :tag "Ask" t)
		 (const :tag "Save without asking" dontask)))

(defcustom monky-revert-item-confirm t
  "Require acknowledgment before reverting an item."
  :group 'monky
  :type 'boolean)

(defcustom monky-log-edit-confirm-cancellation nil
  "Require acknowledgment before canceling the log edit buffer."
  :group 'monky
  :type 'boolean)

(defcustom monky-process-popup-time -1
  "Popup the process buffer if a command takes longer than this many seconds."
  :group 'monky
  :type '(choice (const :tag "Never" -1)
		 (const :tag "Immediately" 0)
		 (integer :tag "After this many seconds")))

(defcustom monky-log-cutoff-length 100
  "The maximum number of commits to show in the log buffer."
  :group 'monky
  :type 'integer)

(defcustom monky-log-infinite-length 99999
  "Number of log used to show as maximum for `monky-log-cutoff-length'."
  :group 'monky
  :type 'integer)

(defcustom monky-log-auto-more t
  "Insert more log entries automatically when moving past the last entry.

Only considered when moving past the last entry with `monky-goto-next-section'."
  :group 'monky
  :type 'boolean)

(defcustom monky-incoming-repository "default"
  "The repository from which changes are pulled from by default."
  :group 'monky
  :type 'string)

(defcustom monky-outgoing-repository ""
  "The repository to which changes are pushed to by default."
  :group 'monky
  :type 'string)

(defgroup monky-faces nil
  "Customize the appearance of Monky"
  :prefix "monky-"
  :group 'faces
  :group 'monky)

(defface monky-header
  '((t))
  "Face for generic header lines.

Many Monky faces inherit from this one by default."
  :group 'monky-faces)

(defface monky-section-title
  '((t :weight bold :inherit monky-header))
  "Face for section titles."
  :group 'monky-faces)

(defface monky-branch
  '((t :weight bold :inherit monky-header))
  "Face for the current branch."
  :group 'monky)

(defface monky-diff-hunk-header
  '((t :slant italic :inherit monky-header))
  "Face for diff hunk header lines."
  :group 'monky-faces)

(defface monky-diff-add
  '((((class color) (background light))
     :foreground "blue1")
    (((class color) (background dark))
     :foreground "white"))
  "Face for lines in a diff that have been added."
  :group 'monky-faces)

(defface monky-diff-none
  '((t))
  "Face for lines in a diff that are unchanged."
  :group 'monky-faces)

(defface monky-diff-del
  '((((class color) (background light))
     :foreground "red")
    (((class color) (background dark))
     :foreground "OrangeRed"))
  "Face for lines in a diff that have been deleted."
  :group 'monky-faces)

(defface monky-log-sha1
  '((((class color) (background light))
     :foreground "firebrick")
    (((class color) (background dark))
     :foreground "tomato"))
  "Face for the sha1 element of the log output."
  :group 'monky-faces)

(defface monky-log-message
  '((t))
  "Face for the message element of the log output."
  :group 'monky-faces)

(defface monky-queue-positive-guard
  '((((class color) (background light))
     :box t
     :background "light green"
     :foreground "dark olive green")
    (((class color) (background dark))
     :box t
     :background "light green"
     :foreground "dark olive green"))
  "Face for queue postive guards"
  :group 'monky)

(defface monky-queue-negative-guard
  '((((class color) (background light))
     :box t
     :background "IndianRed1"
     :foreground "IndianRed4")
    (((class color) (background dark))
     :box t
     :background "IndianRed1"
     :foreground "IndianRed4"))
  "Face for queue negative guards"
  :group 'monky)

(defvar monky-mode-hook nil
  "Hook run by `monky-mode'.")

(put 'monky-mode 'mode-class 'special)

;;; Compatibilities

(eval-when-compile
  (when (< emacs-major-version 23)
    (defvar line-move-visual nil)))

;;; Utilities

(defmacro monky-with-process-environment (&rest body)
  (declare (indent 0))
  `(let ((process-environment (append monky-hg-process-environment
				      process-environment)))
     ,@body))

(defmacro monky-with-refresh (&rest body)
  (declare (indent 0))
  `(monky-refresh-wrapper (lambda () ,@body)))

(defmacro monky-def-permanent-buffer-local (name &optional init-value)
  `(progn
     (defvar ,name ,init-value)
     (make-variable-buffer-local ',name)
     (put ',name 'permanent-local t)))

(defun monky-completing-read (&rest args)
  (apply (if (null ido-mode)
	     'completing-read
	   'ido-completing-read)
	 args))

(defun monky-start-process (&rest args)
  (monky-with-process-environment
    (apply (if (functionp 'start-file-process)
	       'start-file-process
	     'start-process) args)))

(defun monky-process-file (&rest args)
  (monky-with-process-environment
    (apply 'process-file args)))

(defvar monky-bug-report-url "http://github.com/ananthakumaran/monky/issues")
(defun monky-bug-report (str)
  (message "Unknown error: %s\nPlease file a bug at %s"
	   str monky-bug-report-url))

(defun monky-string-starts-with-p (string prefix)
  (eq (compare-strings string nil (length prefix) prefix nil nil) t))

(defun monky-trim-line (str)
  (if (string= str "")
      nil
    (if (equal (elt str (- (length str) 1)) ?\n)
	(substring str 0 (- (length str) 1))
      str)))

(defun monky-delete-line (&optional end)
  "Delete the text in current line.
If END is non-nil, deletes the text including the newline character"
  (let ((end-point (if end
		       (1+ (point-at-eol))
		     (point-at-eol))))
    (delete-region (point-at-bol) end-point)))

(defun monky-split-lines (str)
  (if (string= str "")
      nil
    (let ((lines (nreverse (split-string str "\n"))))
      (if (string= (car lines) "")
	  (setq lines (cdr lines)))
      (nreverse lines))))

(defun monky-put-line-property (prop val)
  (put-text-property (line-beginning-position) (line-beginning-position 2)
		     prop val))

(defun monky-parse-args (command)
  (require 'pcomplete)
  (car (with-temp-buffer
	 (insert command)
	 (pcomplete-parse-buffer-arguments))))

(defun monky-prefix-p (prefix list)
  "Return non-nil if PREFIX is a prefix of LIST.
PREFIX and LIST should both be lists.

If the car of PREFIX is the symbol '*, then return non-nil if the cdr of PREFIX
is a sublist of LIST (as if '* matched zero or more arbitrary elements of LIST)"
  (or (null prefix)
      (if (eq (car prefix) '*)
	  (or (monky-prefix-p (cdr prefix) list)
	      (and (not (null list))
		   (monky-prefix-p prefix (cdr list))))
	(and (not (null list))
	     (equal (car prefix) (car list))
	     (monky-prefix-p (cdr prefix) (cdr list))))))

(defun monky-wash-sequence (func)
  "Run FUNC until end of buffer is reached.

FUNC should leave point at the end of the modified region"
  (while (and (not (eobp))
	      (funcall func))))

(defun monky-goto-line (line)
  "Like `goto-line' but doesn't set the mark."
  (save-restriction
    (widen)
    (goto-char 1)
    (forward-line (1- line))))

;;; Key bindings

(defvar monky-mode-map
  (let ((map (make-keymap)))
    (suppress-keymap map t)
    (define-key map (kbd "n") 'monky-goto-next-section)
    (define-key map (kbd "p") 'monky-goto-previous-section)
    (define-key map (kbd "RET") 'monky-visit-item)
    (define-key map (kbd "TAB") 'monky-toggle-section)
    (define-key map (kbd "g") 'monky-refresh)
    (define-key map (kbd "$") 'monky-display-process)
    (define-key map (kbd ":") 'monky-hg-command)
    (define-key map (kbd "l") 'monky-log)
    (define-key map (kbd "b") 'monky-branches)
    (define-key map (kbd "q") 'monky-queue)
    map))

(defvar monky-status-mode-map
  (let ((map (make-keymap)))
    (define-key map (kbd "s") 'monky-stage-item)
    (define-key map (kbd "S") 'monky-stage-all)
    (define-key map (kbd "u") 'monky-unstage-item)
    (define-key map (kbd "U") 'monky-unstage-all)
    (define-key map (kbd "c") 'monky-log-edit)
    (define-key map (kbd "C") 'monky-checkout)
    (define-key map (kbd "B") 'monky-backout)
    (define-key map (kbd "P") 'monky-push)
    (define-key map (kbd "f") 'monky-pull)
    (define-key map (kbd "F") 'monky-fetch)
    (define-key map (kbd "k") 'monky-discard-item)
    (define-key map (kbd "m") 'monky-resolve-item)
    (define-key map (kbd "x") 'monky-unresolve-item)
    (define-key map (kbd "X") 'monky-reset-tip)
    map))

(defvar monky-log-mode-map
  (let ((map (make-keymap)))
    (define-key map (kbd "e") 'monky-log-show-more-entries)
    (define-key map (kbd "C") 'monky-checkout-item)
    (define-key map (kbd "B") 'monky-backout-item)
    map))

(defvar monky-branches-mode-map
  (let ((map (make-keymap)))
    (define-key map (kbd "C") 'monky-checkout-item)
    map))

(defvar monky-commit-mode-map
  (let ((map (make-keymap)))
    map))

(defvar monky-queue-mode-map
  (let ((map (make-keymap)))
    (define-key map (kbd "u") 'monky-qpop-item)
    (define-key map (kbd "U") 'monky-qpop-all)
    (define-key map (kbd "s") 'monky-qpush-item)
    (define-key map (kbd "S") 'monky-qpush-all)
    (define-key map (kbd "r") 'monky-qrefresh)
    (define-key map (kbd "R") 'monky-qrename-item)
    (define-key map (kbd "k") 'monky-qremove-item)
    (define-key map (kbd "N") 'monky-qnew)
    (define-key map (kbd "f") 'monky-qfold-item)
    (define-key map (kbd "F") 'monky-qfinish-item)
    (define-key map (kbd "G") 'monky-qguard-item)
    map))

(defvar monky-log-edit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") 'monky-log-edit-commit)
    (define-key map (kbd "C-c C-k") 'monky-log-edit-cancel-log-message)
    (define-key map (kbd "C-x C-s")
      (lambda ()
	(interactive)
	(message "Not saved. Use C-c C-c to finalize this commit message.")))
    map))

;;; Sections

(monky-def-permanent-buffer-local monky-top-section)

(defvar monky-old-top-section nil)
(defvar monky-section-hidden-default nil)

;; A buffer in monky-mode is organized into hierarchical sections.
;; These sections are used for navigation and for hiding parts of the
;; buffer.
;;
;; Most sections also represent the objects that Monky works with,
;; such as files, diffs, hunks, commits, etc.  The 'type' of a section
;; identifies what kind of object it represents (if any), and the
;; parent and grand-parent, etc provide the context.

(defstruct monky-section
  parent children beginning end type title hidden info
  needs-refresh-on-show)

(defun monky-set-section-info (info &optional section)
  (setf (monky-section-info (or section monky-top-section)) info))


(defun monky-new-section (title type)
  "Create a new section with title TITLE and type TYPE in current buffer.

If not `monky-top-section' exist, the new section will be the new top-section
otherwise, the new-section will be a child of the current top-section.

If TYPE is nil, the section won't be highlighted."
  (let* ((s (make-monky-section :parent monky-top-section
				:title title
				:type type
				:hidden monky-section-hidden-default))
	 (old (and monky-old-top-section
		   (monky-find-section (monky-section-path s)
				       monky-old-top-section))))
    (if monky-top-section
	(push s (monky-section-children monky-top-section))
      (setq monky-top-section s))
    (if old
	(setf (monky-section-hidden s) (monky-section-hidden old)))
    s))

(defmacro monky-with-section (title type &rest body)
  "Create a new section of title TITLE and type TYPE and evaluate BODY there.

Sections create into BODY will be child of the new section.
BODY must leave point at the end of the created section.

If TYPE is nil, the section won't be highlighted."
  (declare (indent 2))
  (let ((s (make-symbol "*section*")))
    `(let* ((,s (monky-new-section ,title ,type))
	    (monky-top-section ,s))
       (setf (monky-section-beginning ,s) (point))
       ,@body
       (setf (monky-section-end ,s) (point))
       (setf (monky-section-children ,s)
	     (nreverse (monky-section-children ,s)))
       ,s)))

(defmacro monky-create-buffer-sections (&rest body)
  "Empty current buffer of text and monky's section, and then evaluate BODY."
  (declare (indent 0))
  `(let ((inhibit-read-only t))
     (erase-buffer)
     (let ((monky-old-top-section monky-top-section))
       (setq monky-top-section nil)
       ,@body
       (when (null monky-top-section)
	 (monky-with-section 'top nil
	   (insert "(empty)\n")))
       (monky-propertize-section monky-top-section)
       (monky-section-set-hidden monky-top-section
				 (monky-section-hidden monky-top-section)))))

(defun monky-propertize-section (section)
  "Add text-property needed for SECTION."
  (put-text-property (monky-section-beginning section)
		     (monky-section-end section)
		     'monky-section section)
  (dolist (s (monky-section-children section))
    (monky-propertize-section s)))

(defun monky-find-section (path top)
  "Find the section at the path PATH in subsection of section TOP."
  (if (null path)
      top
    (let ((secs (monky-section-children top)))
      (while (and secs (not (equal (car path)
				   (monky-section-title (car secs)))))
	(setq secs (cdr secs)))
      (and (car secs)
	   (monky-find-section (cdr path) (car secs))))))

(defun monky-section-path (section)
  "Return the path of SECTION."
  (if (not (monky-section-parent section))
      '()
    (append (monky-section-path (monky-section-parent section))
	    (list (monky-section-title section)))))

(defun monky-insert-section (section-title-and-type buffer-title washer cmd &rest args)
  "Run CMD and put its result in a new section.

SECTION-TITLE-AND-TYPE is either a string that is the title of the section
or (TITLE . TYPE) where TITLE is the title of the section and TYPE is its type.

If there is no type, or if type is nil, the section won't be highlighted.

BUFFER-TITLE is the inserted title of the section

WASHER is a function that will be run after CMD.
The buffer will be narrowed to the inserted text.
It should add sectioning as needed for monky interaction

CMD is an external command that will be run with ARGS as arguments"
  (let* ((body-beg nil)
	 (section-title (if (consp section-title-and-type)
			    (car section-title-and-type)
			  section-title-and-type))
	 (section-type (if (consp section-title-and-type)
			   (cdr section-title-and-type)
			 nil))
	 (section (monky-with-section section-title section-type
		    (if buffer-title
			(insert (propertize buffer-title 'face 'monky-section-title) "\n"))
		    (setq body-beg (point))
		    (apply 'monky-process-file cmd nil t nil args)
		    (if (not (eq (char-before) ?\n))
			(insert "\n"))
		    (if washer
			(save-restriction
			  (narrow-to-region body-beg (point))
			  (goto-char (point-min))
			  (funcall washer)
			  (goto-char (point-max)))))))
    (if (= body-beg (point))
	(monky-cancel-section section)
      (insert "\n"))
    section))

(defun monky-cancel-section (section)
  (delete-region (monky-section-beginning section)
		 (monky-section-end section))
  (let ((parent (monky-section-parent section)))
    (if parent
	(setf (monky-section-children parent)
	      (delq section (monky-section-children parent)))
      (setq monky-top-section nil))))

(defun monky-current-section ()
  "Return the monky section at point."
  (or (get-text-property (point) 'monky-section)
      monky-top-section))

(defun monky-find-section-after (pos secs)
  "Find the first section that begins after POS in the list SECS."
  (while (and secs
	      (not (> (monky-section-beginning (car secs)) pos)))
    (setq secs (cdr secs)))
  (car secs))

(defun monky-find-section-before (pos secs)
  "Find the last section that begins before POS in the list SECS."
  (let ((prev nil))
    (while (and secs
		(not (> (monky-section-beginning (car secs)) pos)))
      (setq prev (car secs))
      (setq secs (cdr secs)))
    prev))

(defun monky-next-section (section)
  "Return the section that is after SECTION."
  (let ((parent (monky-section-parent section)))
    (if parent
	(let ((next (cadr (memq section
				(monky-section-children parent)))))
	  (or next
	      (monky-next-section parent))))))

(defun monky-goto-next-section ()
  "Go to the next monky section."
  (interactive)
  (let* ((section (monky-current-section))
	 (next (or (and (not (monky-section-hidden section))
			(monky-section-children section)
			(monky-find-section-after (point)
						  (monky-section-children
						   section)))
		   (monky-next-section section))))
    (cond
     ((and next (eq (monky-section-type next) 'longer))
      (when monky-log-auto-more
	(monky-log-show-more-entries)
	(monky-goto-next-section)))
     (next
      (goto-char (monky-section-beginning next))
      (if (eq monky-submode 'log)
	  (monky-show-commit next))
      (if (not (monky-section-hidden next))
	  (let ((offset (- (line-number-at-pos
			    (monky-section-beginning next))
			   (line-number-at-pos
			    (monky-section-end next)))))
	    (if (< offset 0)
		(recenter offset)))))
     (t (message "No next section")))))

(defun monky-prev-section (section)
  "Return the section that is before SECTION."
  (let ((parent (monky-section-parent section)))
    (if parent
	(let ((prev (cadr (memq section
				(reverse (monky-section-children parent))))))
	  (cond (prev
		 (while (and (not (monky-section-hidden prev))
			     (monky-section-children prev))
		   (setq prev (car (reverse (monky-section-children prev)))))
		 prev)
		(t
		 parent))))))


(defun monky-goto-previous-section ()
  "Goto the previous monky section."
  (interactive)
  (let ((section (monky-current-section)))
    (cond ((= (point) (monky-section-beginning section))
	   (let ((prev (monky-prev-section (monky-current-section))))
	     (if prev
		 (progn
		   (if (eq monky-submode 'log)
		       (monky-show-commit prev))
		   (goto-char (monky-section-beginning prev)))
	       (message "No previous section"))))
	  (t
	   (let ((prev (monky-find-section-before (point)
						  (monky-section-children
						   section))))
	     (if (eq monky-submode 'log)
		 (monky-show-commit (or prev section)))
	     (goto-char (monky-section-beginning (or prev section))))))))


(defun monky-section-context-type (section)
  (if (null section)
      '()
    (let ((c (or (monky-section-type section)
		 (if (symbolp (monky-section-title section))
		     (monky-section-title section)))))
      (if c
	  (cons c (monky-section-context-type
		   (monky-section-parent section)))
	'()))))

(defun monky-hg-section (section-title-and-type buffer-title washer &rest args)
  (apply #'monky-insert-section
	 section-title-and-type
	 buffer-title
	 washer
	 monky-hg-executable
	 (append monky-hg-standard-options args)))

(defun monky-set-section-needs-refresh-on-show (flag &optional section)
  (setf (monky-section-needs-refresh-on-show
	 (or section monky-top-section))
	flag))

(defun monky-section-set-hidden (section hidden)
  "Hide SECTION if HIDDEN is not nil, show it otherwise."
  (setf (monky-section-hidden section) hidden)
  (if (and (not hidden)
	   (monky-section-needs-refresh-on-show section))
      (monky-refresh)
    (let ((inhibit-read-only t)
	  (beg (save-excursion
		 (goto-char (monky-section-beginning section))
		 (forward-line)
		 (point)))
	  (end (monky-section-end section)))
      (if (< beg end)
	  (put-text-property beg end 'invisible hidden)))
    (if (not hidden)
	(dolist (c (monky-section-children section))
	  (monky-section-set-hidden c (monky-section-hidden c))))))

(defun monky-section-hideshow (flag-or-func)
  "Show or hide current section depending on FLAG-OR-FUNC.

If FLAG-OR-FUNC is a function, it will be ran on current section
IF FLAG-OR-FUNC is a Boolean value, the section will be hidden if its true, shown otherwise"
  (let ((section (monky-current-section)))
    (when (monky-section-parent section)
      (goto-char (monky-section-beginning section))
      (if (functionp flag-or-func)
	  (funcall flag-or-func section)
	(monky-section-set-hidden section flag-or-func)))))

(defun monky-toggle-section ()
  "Toggle hidden status of current section."
  (interactive)
  (monky-section-hideshow
   (lambda (s)
     (monky-section-set-hidden s (not (monky-section-hidden s))))))

;;; Running commands

(defun monky-set-mode-line-process (str)
  (let ((pr (if str (concat " " str) "")))
    (save-excursion
      (monky-for-all-buffers (lambda ()
			       (setq mode-line-process pr))))))

(defun monky-process-indicator-from-command (comps)
  (if (monky-prefix-p (cons monky-hg-executable monky-hg-standard-options)
		      comps)
      (setq comps (nthcdr (+ (length monky-hg-standard-options) 1) comps)))
  (car comps))

(defvar monky-process nil)
(defvar monky-process-client-buffer nil)
(defvar monky-process-buffer-name "*monky-process*")

(defun monky-run* (cmd-and-args
		   &optional logline noerase noerror nowait input)
  (if (and monky-process
	   (get-buffer monky-process-buffer-name))
      (error "Hg is already running"))
  (let ((cmd (car cmd-and-args))
	(args (cdr cmd-and-args))
	(dir default-directory)
	(buf (get-buffer-create monky-process-buffer-name))
	(successp nil))
    (monky-set-mode-line-process
     (monky-process-indicator-from-command cmd-and-args))
    (setq monky-process-client-buffer (current-buffer))
    (with-current-buffer buf
      (view-mode 1)
      (set (make-local-variable 'view-no-disable-on-exit) t)
      (setq view-exit-action
	    (lambda (buffer)
	      (with-current-buffer buffer
		(bury-buffer))))
      (setq buffer-read-only t)
      (let ((inhibit-read-only t))
	(setq default-directory dir)
	(if noerase
	    (goto-char (point-max))
	  (erase-buffer))
	(insert "$ " (or logline
			 (mapconcat #'identity cmd-and-args " "))
		"\n")
	(cond (nowait
	       (setq monky-process
		     (let ((process-connection-type nil))
		       (apply 'monky-start-process cmd buf cmd args)))
	       (set-process-sentinel monky-process 'monky-process-sentinel)
	       (set-process-filter monky-process 'monky-process-filter)
	       (when input
		 (with-current-buffer input
		   (process-send-region monky-process
					(point-min) (point-max))
		   (process-send-eof monky-process)
		   (sit-for 0.1 t)))
	       (cond ((= monky-process-popup-time 0)
		      (pop-to-buffer (process-buffer monky-process)))
		     ((> monky-process-popup-time 0)
		      (run-with-timer
		       monky-process-popup-time nil
		       (function
			(lambda (buf)
			  (with-current-buffer buf
			    (when monky-process
			      (display-buffer (process-buffer monky-process))
			      (goto-char (point-max))))))
		       (current-buffer))))
	       (setq successp t))
	      (input
	       (with-current-buffer input
		 (setq default-directory dir)
		 (setq monky-process
		       ;; Don't use a pty, because it would set icrnl
		       ;; which would modify the input (issue #20).
		       (let ((process-connection-type nil))
			 (apply 'monky-start-process cmd buf cmd args)))
		 (set-process-filter monky-process 'monky-process-filter)
		 (process-send-region monky-process
				      (point-min) (point-max))
		 (process-send-eof monky-process)
		 (while (equal (process-status monky-process) 'run)
		   (sit-for 0.1 t))
		 (setq successp
		       (equal (process-exit-status monky-process) 0))
		 (setq monky-process nil))
	       (monky-set-mode-line-process nil)
	       (monky-need-refresh monky-process-client-buffer))
	      (t
	       (setq successp
		     (equal (apply 'monky-process-file cmd nil buf nil args) 0))
	       (monky-set-mode-line-process nil)
	       (monky-need-refresh monky-process-client-buffer))))
      (or successp
	  noerror
	  (error
	   (or (monky-abort-message (get-buffer monky-process-buffer-name))
	       "Hg failed")))
      successp)))

(defun monky-process-sentinel (process event)
  (let ((msg (format "Hg %s." (substring event 0 -1)))
	(successp (string-match "^finished" event)))
    (with-current-buffer (process-buffer process)
      (let ((inhibit-read-only t))
	(goto-char (point-max))
	(insert msg "\n")
	(message msg)))
    (when (not successp)
      (let ((msg (monky-abort-message (process-buffer process))))
	(and msg (message msg))))
    (setq monky-process nil)
    (monky-set-mode-line-process nil)
    (if (buffer-live-p monky-process-client-buffer)
	(with-current-buffer monky-process-client-buffer
	  (monky-with-refresh
	    (monky-need-refresh monky-process-client-buffer))))))

(defun monky-abort-message (buffer)
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward
	     (concat "^abort: \\(.*\\)" paragraph-separate) nil t)
	(match-string 1)))))

;; TODO password?

(defun monky-process-filter (proc string)
  (save-current-buffer
    (set-buffer (process-buffer proc))
    (let ((inhibit-read-only t))
      (goto-char (process-mark proc))
      (insert string)
      (set-marker (process-mark proc) (point)))))


(defun monky-run-hg (&rest args)
  (monky-with-refresh
    (monky-run* (append (cons monky-hg-executable
			      monky-hg-standard-options)
			args))))

(defun monky-run-hg-async (&rest args)
  (message "Running %s %s"
	   monky-hg-executable
	   (mapconcat #'identity args " "))
  (monky-run* (append (cons monky-hg-executable
			    monky-hg-standard-options)
		      args)
	      nil nil nil t))

(defun monky-run-async-with-input (input cmd &rest args)
  (monky-run* (cons cmd args) nil nil nil t input))

(defun monky-display-process ()
  "Display output from most recent hg command."
  (interactive)
  (unless (get-buffer monky-process-buffer-name)
    (error "No Hg commands have run"))
  (display-buffer monky-process-buffer-name))

(defun monky-hg-command (command)
  "Perform arbitrary Hg COMMAND."
  (interactive "sRun hg like this: ")
  (let ((args (monky-parse-args command))
	(monky-process-popup-time 0))
    (monky-with-refresh
      (monky-run* (append (cons monky-hg-executable
				monky-hg-standard-options)
			  args)
		  nil nil nil t))))

;;; Actions

(defmacro monky-section-case (head &rest clauses)
  "Make different action depending of current section.

HEAD is (SECTION INFO &optional OPNAME),
  SECTION will be bind to the current section,
  INFO will be bind to the info's of the current section,
  OPNAME is a string that will be used to describe current action,

CLAUSES is a list of CLAUSE, each clause is (SECTION-TYPE &BODY)
where SECTION-TYPE describe section where BODY will be run.

This returns non-nil if some section matches.  If the
corresponding body return a non-nil value, it is returned,
otherwise it return t.

If no section matches, this returns nil if no OPNAME was given
and throws an error otherwise."

  (declare (indent 1))
  (let ((section (car head))
	(info (cadr head))
	(type (make-symbol "*type*"))
	(context (make-symbol "*context*"))
	(opname (caddr head)))
    `(let* ((,section (monky-current-section))
	    (,info (monky-section-info ,section))
	    (,type (monky-section-type ,section))
	    (,context (monky-section-context-type ,section)))
       (cond ,@(mapcar (lambda (clause)
			 (let ((prefix (car clause))
			       (body (cdr clause)))
			   `(,(if (eq prefix t)
				  `t
				`(monky-prefix-p ',(reverse prefix) ,context))
			     (or (progn ,@body)
				 t))))
		       clauses)
	     ,@(when opname
		 `(((not ,type)
		    (error "Nothing to %s here" ,opname))
		   (t
		    (error "Can't %s as %s"
			   ,opname
			   ,type))))))))

(defmacro monky-section-action (head &rest clauses)
  (declare (indent 1))
  `(monky-with-refresh
     (monky-section-case ,head ,@clauses)))

(defun monky-visit-item (&optional other-window)
  "Visit current item.
With a prefix argument, visit in other window."
  (interactive (list current-prefix-arg))
  (monky-section-action (item info "visit")
    ((file)
     (funcall (if other-window 'find-file-other-window 'find-file)
	      info))
    ((diff)
     (find-file (monky-diff-item-file item)))
    ((hunk)
     (let ((file (monky-diff-item-file (monky-hunk-item-diff item)))
	   (line (monky-hunk-item-target-line item)))
       (find-file file)
       (goto-char (point-min))
       (forward-line (1- line))))
    ((commit)
     (message (monky-show-commit info)))
    ((longer)
     (monky-log-show-more-entries))))

(defun monky-stage-all ()
  "Add all items in Changes to the staging area."
  (interactive)
  (monky-with-refresh
    (setq monky-staged-all-files t)
    (monky-refresh-buffer)))

(defun monky-stage-item ()
  "Add the item at point to the staging area."
  (interactive)
  (monky-section-action (item info "stage")
    ((untracked file)
     (monky-run-hg "add" info))
    ((untracked)
     (monky-run-hg "add"))
    ((missing file)
     (monky-run-hg "remove" "--after" info))
    ((changes diff)
     (monky-stage-file (monky-section-title item))
     (monky-refresh-buffer))
    ((changes)
     (monky-stage-all))
    ((staged diff)
     (error "Already staged"))
    ((unmodified diff)
     (error "Cannot partially commit a merge"))
    ((merged diff)
     (error "Cannot partially commit a merge"))))

(defun monky-unstage-all ()
  "Remove all items from the staging area"
  (interactive)
  (monky-with-refresh
    (setq monky-staged-files '())
    (monky-refresh-buffer)))

(defun monky-unstage-item ()
  "Remove the item at point from the staging area."
  (interactive)
  (monky-section-action (item info "unstage")
    ((staged diff)
     (monky-unstage-file (monky-section-title item))
     (monky-refresh-buffer))
    ((staged)
     (monky-unstage-all))
    ((changes diff)
     (error "Already unstaged"))))

;;; Updating

(defun monky-fetch ()
  "Run hg fetch."
  (interactive)
  (let ((remote (if current-prefix-arg
		    (monky-read-remote "Fetch from : ")
		  monky-incoming-repository)))
    (monky-run-hg-async "fetch" remote
			"--config" "extensions.fetch=")))

(defun monky-pull ()
  "Run hg pull."
  (interactive)
  (let ((remote (if current-prefix-arg
		    (monky-read-remote "Pull from : ")
		  monky-incoming-repository)))
    (monky-run-hg-async "pull" remote)))

(defun monky-remotes ()
  (mapcar #'car (monky-hg-config-section "paths")))

(defun monky-read-remote (prompt)
  (monky-completing-read prompt
			 (monky-remotes)))

(defun monky-read-revision (prompt)
  (let ((revision (read-string prompt)))
    (unless (monky-hg-revision-p revision)
      (error "%s is not a revision" revision))
    revision))

(defun monky-push ()
  "Pushes current branch to the default path."
  (interactive)
  (let* ((branch (monky-current-branch))
	 (remote (if current-prefix-arg
		     (monky-read-remote
		      (format "Push branch %s to : " branch))
		   monky-outgoing-repository)))
    (monky-run-hg-async "push" "--branch" branch remote)))

(defun monky-checkout (node)
  (interactive (list (monky-read-revision "Update to : ")))
  (monky-run-hg "update" node))

(defun monky-reset-tip ()
  (interactive)
  (when (yes-or-no-p "Discard all uncommitted changes? ")
      (monky-run-hg "update" "--clean")))

;;; Merging

(defun monky-unresolve-item ()
  "Mark the item at point as unresolved."
  (interactive)
  (monky-section-action (item info "unresolve")
    ((merged diff)
     (if (eq (monky-diff-item-kind item) 'resolved)
	 (monky-run-hg "resolve" "--unmark" (monky-diff-item-file item))
       (error "Already unresolved")))))

(defun monky-resolve-item ()
  "Mark the item at point as resolved."
  (interactive)
  (monky-section-action (item info "resolve")
    ((merged diff)
     (if (eq (monky-diff-item-kind item) 'unresolved)
	 (monky-run-hg "resolve" "--mark" (monky-diff-item-file item))
       (error "Already resolved")))))

;; History

(defun monky-backout (revision)
  "Runs hg backout."
  (interactive (list (monky-read-revision "Backout : ")))
  (monky-pop-to-log-edit 'backout revision))

(defun monky-backout-item ()
  "Backout the revision represented by current item."
  (interactive)
  (monky-section-action (item info "backout")
    ((log commits commit)
     (monky-backout info))))

;;; Miscellaneous

(defun monky-revert-file (file)
  (when (or (not monky-revert-item-confirm) (yes-or-no-p (format "Revert %s? " file)))
    (monky-run-hg "revert" "--no-backup" file)))

(defun monky-discard-item ()
  "Delete the file if not tracked, otherwise revert it."
  (interactive)
  (monky-section-action (item info "discard")
    ((untracked file)
     (when (yes-or-no-p (format "Delete %s? " info))
       (delete-file info)
       (monky-refresh-buffer)))
    ((changes diff)
     (monky-revert-file (monky-diff-item-file item)))
    ((staged diff)
     (monky-revert-file (monky-diff-item-file item)))
    ((missing file)
     (monky-revert-file info))))

;;; Refresh

(defun monky-revert-buffers (dir &optional ignore-modtime)
  (dolist (buffer (buffer-list))
    (when (and buffer
	       (buffer-file-name buffer)
	       (file-readable-p (buffer-file-name buffer))
	       (monky-string-starts-with-p (buffer-file-name buffer) dir)
	       (or ignore-modtime (not (verify-visited-file-modtime buffer)))
	       (not (buffer-modified-p buffer)))
      (with-current-buffer buffer
	(condition-case var
	    (revert-buffer t t nil)
	  (error (let ((signal-data (cadr var)))
		   (cond (t (monky-bug-report signal-data))))))))))

(defvar monky-refresh-needing-buffers nil)
(defvar monky-refresh-pending nil)

(defun monky-refresh-wrapper (func)
  (if monky-refresh-pending
      (funcall func)
    (let* ((dir default-directory)
	   (status-buffer (monky-find-status-buffer dir))
	   (monky-refresh-needing-buffers nil)
	   (monky-refresh-pending t))
      (unwind-protect
	  (funcall func)
	(when monky-refresh-needing-buffers
	  (monky-revert-buffers dir)
	  (dolist (b (adjoin status-buffer
			     monky-refresh-needing-buffers))
	    (monky-refresh-buffer b)))))))

(defun monky-need-refresh (&optional buffer)
  (let ((buffer (or buffer (current-buffer))))
    (setq monky-refresh-needing-buffers
	  (adjoin buffer monky-refresh-needing-buffers))))

(defun monky-refresh ()
  "Refresh current buffer to match repository state.
Also revert every unmodified buffer visiting files
in the corresponding directory."
  (interactive)
  (monky-with-refresh
    (monky-need-refresh)))

(defun monky-refresh-buffer (&optional buffer)
  (with-current-buffer (or buffer (current-buffer))
    (let* ((old-line (line-number-at-pos))
	   (old-section (monky-current-section))
	   (old-path (and old-section
			  (monky-section-path old-section)))
	   (section-line (and old-section
			      (count-lines
			       (monky-section-beginning old-section)
			       (point)))))
      (if monky-refresh-function
	  (apply monky-refresh-function
		 monky-refresh-args))
      (let ((s (and old-path (monky-find-section old-path monky-top-section))))
	(cond (s
	       (goto-char (monky-section-beginning s))
	       (forward-line section-line))
	      (t
	       (monky-goto-line old-line)))
	(dolist (w (get-buffer-window-list (current-buffer)))
	  (set-window-point w (point)))))))

(defvar last-point)

(defun monky-remember-point ()
  (setq last-point (point)))

(defun monky-invisible-region-end (pos)
  (while (and (not (= pos (point-max))) (invisible-p pos))
    (setq pos (next-char-property-change pos)))
  pos)

(defun monky-invisible-region-start (pos)
  (while (and (not (= pos (point-min))) (invisible-p pos))
    (setq pos (1- (previous-char-property-change pos))))
  pos)

(defun monky-correct-point-after-command ()
  "Move point outside of invisible regions.

Emacs often leaves point in invisible regions, it seems.  To fix
this, we move point ourselves and never let Emacs do its own
adjustments.

When point has to be moved out of an invisible region, it can be
moved to its end or its beginning.  We usually move it to its
end, except when that would move point back to where it was
before the last command."
  (if (invisible-p (point))
      (let ((end (monky-invisible-region-end (point))))
	(goto-char (if (= end last-point)
		       (monky-invisible-region-start (point))
		     end))))
  (setq disable-point-adjustment t))

(defun monky-post-command-hook ()
  (monky-correct-point-after-command))

;;; Monky mode

(monky-def-permanent-buffer-local monky-submode)
(monky-def-permanent-buffer-local monky-refresh-function)
(monky-def-permanent-buffer-local monky-refresh-args)

(defun monky-mode ()
  "View the status of a Hg Repository.

\\{monky-mode-map}"
  (kill-all-local-variables)
  (buffer-disable-undo)
  (setq buffer-read-only t)
  (make-local-variable 'line-move-visual)
  (setq major-mode 'monky-mode
	mode-name "Monky"
	mode-line-process ""
	truncate-lines t
	line-move-visual nil)
  (add-hook 'pre-command-hook #'monky-remember-point nil t)
  (add-hook 'post-command-hook #'monky-post-command-hook t t)
  (use-local-map monky-mode-map)
  (run-hooks 'monky-mode-hook))

(defun monky-mode-init (dir submode refresh-func &rest refresh-args)
  (setq default-directory dir
	monky-submode submode
	monky-refresh-function refresh-func
	monky-refresh-args refresh-args)
  (monky-mode)
  (monky-refresh-buffer))


;;; Hg utils

(defmacro monky-with-temp-file (file &rest body)
  "Create a temporary file name, evaluate BODY and delete the file."
  (declare (indent 1))
  `(let ((,file (expand-file-name
		 (make-temp-name "monky-temp-file")
		 temporary-file-directory)))
     (unwind-protect
	 (progn ,@body)
       (delete-file ,file))))

(defun monky-hg-insert (args)
  (insert (monky-hg-output args)))

(defun monky-hg-output (args)
  (with-output-to-string
    (with-current-buffer standard-output
      (monky-with-temp-file stderr
	(unless (eq 0 (apply #'monky-process-file
			     monky-hg-executable
			     nil (list t stderr) nil
			     (append monky-hg-standard-options args)))
	  (error (with-temp-buffer
		   (insert-file-contents stderr)
		   (buffer-string))))))))

(defun monky-hg-string (&rest args)
  (monky-trim-line (monky-hg-output args)))

(defun monky-hg-lines (&rest args)
  (monky-split-lines (monky-hg-output args)))

(defun monky-hg-exit-code (&rest args)
  (apply #'monky-process-file monky-hg-executable nil nil nil
	 (append monky-hg-standard-options args)))

(defun monky-hg-revision-p (revision)
  (eq 0 (monky-hg-exit-code "identify" "--rev" revision)))

;; TODO needs cleanup
(defun monky-get-root-dir ()
  (let ((root (monky-hg-string "root")))
    (if root
	(concat root "/")
      (error "Not inside a hg repo"))))

(defun monky-find-buffer (submode &optional dir)
  (let ((rootdir (or dir (monky-get-root-dir))))
    (find-if (lambda (buf)
	       (with-current-buffer buf
		 (and default-directory
		      (equal (expand-file-name default-directory) rootdir)
		      (eq major-mode 'monky-mode)
		      (eq monky-submode submode))))
	     (buffer-list))))

(defun monky-find-status-buffer (&optional dir)
  (monky-find-buffer 'status dir))

(defun monky-for-all-buffers (func &optional dir)
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (if (and (eq major-mode 'monky-mode)
	       (or (null dir)
		   (equal default-directory dir)))
	  (funcall func)))))

(defun monky-hg-config ()
  "Return an alist of ((section . key) . value)"
  (mapcar (lambda (line)
	    (string-match "^\\([^.]*\\)\.\\([^=]*\\)=\\(.*\\)$" line)
	    (cons (cons (match-string 1 line)
			(match-string 2 line))
		  (match-string 3 line)))
	  (monky-hg-lines "debugconfig")))

(defun monky-hg-config-section (section)
  "Return an alist of (name . value) for section"
  (mapcar (lambda (item)
	    (cons (cdar item) (cdr item)))
   (remove-if-not (lambda (item)
		    (equal section (caar item)))
		  (monky-hg-config))))

;;; Washers

(defmacro monky-with-wash-status (status file &rest body)
  (declare (indent 2))
  `(lambda ()
     (if (looking-at "\\([A-Z!? ]\\) \\([^\t\n]+\\)$")
	 (let ((,status (case (string-to-char (match-string-no-properties 1))
			  (?M 'modified)
			  (?A 'new)
			  (?R 'removed)
			  (?C 'clean)
			  (?! 'missing)
			  (?? 'untracked)
			  (?I 'ignored)
			  (?U 'unresolved)
			  (t nil)))
	       (,file (match-string-no-properties 2)))
	   (monky-delete-line t)
	   ,@body
	   t)
       nil)))

;; File

(defun monky-wash-files ()
  (monky-wash-sequence
   (monky-with-wash-status status file
     (monky-with-section file 'file
       (monky-set-section-info file)
       (insert "\t" file "\n")))))

;; Hunk

(defun monky-hunk-item-diff (hunk)
  (let ((diff (monky-section-parent hunk)))
    (or (eq (monky-section-type diff) 'diff)
	(error "Huh?  Parent of hunk not a diff"))
    diff))

(defun monky-hunk-item-target-line (hunk)
  (save-excursion
    (beginning-of-line)
    (let ((line (line-number-at-pos)))
      (if (looking-at "-")
	  (error "Can't visit removed lines"))
      (goto-char (monky-section-beginning hunk))
      (if (not (looking-at "@@+ .* \\+\\([0-9]+\\),[0-9]+ @@+"))
	  (error "Hunk header not found"))
      (let ((target (string-to-number (match-string 1))))
	(forward-line)
	(while (< (line-number-at-pos) line)
	  ;; XXX - deal with combined diffs
	  (if (not (looking-at "-"))
	      (setq target (+ target 1)))
	  (forward-line))
	target))))

(defun monky-wash-hunk ()
  (if (looking-at "\\(^@+\\)[^@]*@+")
      (let ((n-columns (1- (length (match-string 1))))
	    (head (match-string 0)))
	(monky-with-section head 'hunk
	  (add-text-properties (match-beginning 0) (match-end 0)
			       '(face monky-diff-hunk-header))
	  (forward-line)
	  (while (not (or (eobp)
			  (looking-at "^diff\\|^@@")))
	    (let ((prefix (buffer-substring-no-properties
			   (point) (min (+ (point) n-columns) (point-max)))))
	      (cond ((string-match "\\+" prefix)
		     (monky-put-line-property 'face 'monky-diff-add))
		    ((string-match "-" prefix)
		     (monky-put-line-property 'face 'monky-diff-del))
		    (t
		     (monky-put-line-property 'face 'monky-diff-none))))
	    (forward-line))))
    nil))

;; Diff

(defvar monky-hide-diffs nil)

(defun monky-diff-item-kind (diff)
  (car (monky-section-info diff)))

(defun monky-diff-item-file (diff)
  (cadr (monky-section-info diff)))

(defun monky-diff-line-file ()
  (cond ((looking-at "^diff -r \\(.*\\) \\(.*\\)$")
	 (match-string-no-properties 2))
	(t
	 nil)))

(defun monky-wash-diff-section (&optional status)
  (if (looking-at "^diff")
      (let* ((file (monky-diff-line-file))
	     (end (save-excursion
		    (forward-line)
		    (if (search-forward-regexp "^diff\\|^@@" nil t)
			(goto-char (match-beginning 0))
		      (goto-char (point-max)))
		    (point-marker)))
	     (status (or status
			 (cond
			  ((save-excursion
			     (search-forward-regexp "^--- /dev/null" end t))
			   'new)
			  ((save-excursion
			     (search-forward-regexp "^+++ /dev/null" end t))
			   'removed)
			  (t 'modified)))))
	(monky-set-section-info (list status file))
	(monky-insert-diff-title status file)
	(goto-char end)
	(let ((monky-section-hidden-default nil))
	  (monky-wash-sequence #'monky-wash-hunk)))
    nil))

(defun monky-wash-diff ()
  (let ((monky-section-hidden-default monky-hide-diffs))
    (monky-with-section nil 'diff
      (monky-wash-diff-section))))

(defun monky-wash-diffs ()
  (monky-wash-sequence #'monky-wash-diff))

(defun monky-insert-diff (file &optional status)
  (let ((p (point)))
    (monky-hg-insert (list "diff" file))
    (if (not (eq (char-before) ?\n))
	(insert "\n"))
    (save-restriction
      (narrow-to-region p (point))
      (goto-char p)
      (monky-wash-diff-section status)
      (goto-char (point-max)))))

(defun monky-insert-diff-title (status file)
  (insert (format "\t%-10s %s\n" (capitalize (symbol-name status)) file)))

;;; Untracked files

(defun monky-insert-untracked-files ()
  (monky-hg-section 'untracked "Untracked files:" #'monky-wash-files
		    "status" "--unknown"))

;;; Missing files

(defun monky-insert-missing-files ()
  (monky-hg-section 'missing "Missing files:" #'monky-wash-files
		    "status" "--deleted"))

;;; Changes

(defun monky-wash-changes ()
  (monky-wash-sequence
   (monky-with-wash-status status file
     (let ((monky-section-hidden-default monky-hide-diffs))
       (if (or monky-staged-all-files
	       (member file monky-old-staged-files))
	   (monky-stage-file file)
	 (monky-with-section file 'diff
	   (monky-insert-diff file status)))))))


(defun monky-insert-changes ()
  (let ((monky-hide-diffs t))
    (setq monky-old-staged-files (copy-list monky-staged-files))
    (setq monky-staged-files '())
    (monky-hg-section 'changes "Changes:" #'monky-wash-changes
		      "status" "--modified" "--added" "--removed")))

;; Staged Changes

(defvar monky-staged-all-files nil)
(defvar monky-old-staged-files '())
(monky-def-permanent-buffer-local monky-staged-files)

(defun monky-stage-file (file)
  (if (not (member file monky-staged-files))
      (setq monky-staged-files (cons file monky-staged-files))))

(defun monky-unstage-file (file)
  (setq monky-staged-files (delete file monky-staged-files)))

(defun monky-insert-staged-changes ()
  (when monky-staged-files
    (monky-with-section 'staged nil
      (insert (propertize "Staged changes:" 'face 'monky-section-title) "\n")
      (let ((monky-section-hidden-default t))
	(dolist (file monky-staged-files)
	  (monky-with-section file 'diff
	    (monky-insert-diff file))))))
  (setq monky-staged-all-files nil))


;;; Parents

(defvar monky-parents '())
(make-variable-buffer-local 'monky-parents)

(defun monky-merge-p ()
  (> (length monky-parents) 1))

(defun monky-wash-parent ()
  (if (looking-at "changeset:\s*\\([0-9]+\\):\\([0-9a-z]+\\)")
      (let ((changeset (match-string 2)))
	(add-to-list 'monky-parents changeset)
	(forward-line)
	(while (not (or (eobp)
			(looking-at "changeset:\s*\\([0-9]+\\):\\([0-9a-z]+\\)")))
	  (forward-line))
	t)
    nil))

(defun monky-wash-parents ()
  (monky-wash-sequence #'monky-wash-parent))

(defun monky-insert-parents ()
  (monky-hg-section 'parents "Parents:"
		    #'monky-wash-parents "parents"))

;;; Merged Files

(defvar monky-merged-files '())
(make-variable-buffer-local 'monky-merged-files)

(defun monky-wash-merged-files ()
  (monky-wash-sequence
   (monky-with-wash-status status file
     (let ((monky-section-hidden-default monky-hide-diffs))
       (add-to-list 'monky-merged-files file)
       ;; XXX hg uses R for resolved and removed status
       (let ((status (if (eq status 'unresolved)
			 'unresolved
		       'resolved)))
	 (monky-with-section file 'diff
	   (monky-insert-diff file status)))))))

(defun monky-insert-merged-files ()
  (let ((monky-hide-diffs t))
    (setq monky-merged-files '())
    (monky-hg-section 'merged "Merged Files:" #'monky-wash-merged-files
		      "resolve" "--list")))

;;; UnModified Files

(defun monky-wash-unmodified-files ()
  (monky-wash-sequence
   (monky-with-wash-status status file
     (let ((monky-section-hidden-default monky-hide-diffs))
       (when (not (member file monky-merged-files))
	 (monky-with-section file 'diff
	   (monky-insert-diff file)))))))

(defun monky-insert-resolved-files ()
  (let ((monky-hide-diffs t))
    (monky-hg-section 'unmodified "UnModified Files during Merge:" #'monky-wash-unmodified-files
		      "status" "--modified" "--added" "--removed")))
;;; Status mode

(defun monkey-refresh-status ()
  (setq monky-parents '()
	monky-merged-files '())
  (monky-create-buffer-sections
    (monky-with-section 'status nil
      (monky-insert-parents)
      (if (monky-merge-p)
	  (progn
	    (monky-insert-merged-files)
	    (monky-insert-resolved-files))
	(monky-insert-untracked-files)
	(monky-insert-missing-files)
	(monky-insert-changes)
	(monky-insert-staged-changes)))))

(define-minor-mode monky-status-mode
  "Minor mode for hg status.

\\{monky-status-mode-map}"
  :group monky
  :init-value ()
  :lighter ()
  :keymap monky-status-mode-map)

;;;###autoload
(defun monky-status ()
  "Show the status of Hg repository."
  (interactive)
  (let* ((rootdir (monky-get-root-dir))
	 (buf (or (monky-find-status-buffer rootdir)
		  (generate-new-buffer
		   (concat "*monky: "
			   (file-name-nondirectory
			    (directory-file-name rootdir)) "*")))))
    (pop-to-buffer buf)
    (monky-mode-init rootdir 'status #'monkey-refresh-status)
    (monky-status-mode t)))

;;; Log mode

(define-minor-mode monky-log-mode
  "Minor mode for hg log.

\\{monky-log-mode-map}"
  :group monky
  :init-value ()
  :lighter ()
  :keymap monky-log-mode-map)

(defvar monky-log-buffer-name "*monky-log*")

(defun monky-present-log-line (graph id message)
  (concat (propertize (substring id 0 8) 'face 'monky-log-sha1)
	  "  "
	  graph
	  (propertize message 'face 'monky-log-message)))

(defun monky-log ()
  (interactive)
  (let ((topdir (monky-get-root-dir)))
    (pop-to-buffer monky-log-buffer-name)
    (monky-mode-init topdir 'log #'monky-refresh-log-buffer)
    (monky-log-mode t)))

(defvar monky-log-graph-re "^\\([-\\/@o+|\s]+\s*\\) \\([a-z0-9]\\{40\\}\\)\\(.*\\)$")

(defun monky-wash-log-line ()
  (if (looking-at monky-log-graph-re)
      (let ((graph (match-string 1))
	    (id (match-string 2))
	    (msg (match-string 3)))
	(monky-delete-line)
	(monky-with-section id 'commit
	  (insert (monky-present-log-line graph id msg))
	  (monky-set-section-info id)
	  (when monky-log-count (incf monky-log-count))
	  (forward-line)
	  (when (looking-at "^\\([\\/@o+-|\s]+\s*\\)$")
	    (let ((graph (match-string 1)))
	      (insert "          ")
	      (forward-line))))
	t)
    nil))

(defun monky-wash-logs ()
  (let ((monky-old-top-section nil))
    (monky-wash-sequence #'monky-wash-log-line)))

(defvar monky-log-count ()
  "Internal var used to count the number of logs actually added in a buffer.")

(defmacro monky-create-log-buffer-sections (&rest body)
  "Empty current buffer of text and monky's section, and then evaluate BODY.

if the number of logs inserted in the buffer is `monky-log-cutoff-length'
insert a line to tell how to insert more of them"
  (declare (indent 0))
  `(let ((monky-log-count 0))
     (monky-create-buffer-sections
       (monky-with-section 'log nil
	 ,@body
	 (if (= monky-log-count monky-log-cutoff-length)
	   (monky-with-section "longer"  'longer
	     (insert "type \"e\" to show more logs\n")))))))

(defun monky-log-show-more-entries (&optional arg)
  "Grow the number of log entries shown.

With no prefix optional ARG, show twice as much log entries.
With a numerical prefix ARG, add this number to the number of shown log entries.
With a non numeric prefix ARG, show all entries"
  (interactive "P")
  (make-local-variable 'monky-log-cutoff-length)
  (cond
   ((numberp arg)
    (setq monky-log-cutoff-length (+ monky-log-cutoff-length arg)))
   (arg
    (setq monky-log-cutoff-length monky-log-infinite-length))
   (t (setq monky-log-cutoff-length (* monky-log-cutoff-length 2))))
  (monky-refresh))

(defun monky-refresh-log-buffer ()
  (monky-create-log-buffer-sections
    (monky-hg-section 'commits "Commits:"
		      #'monky-wash-logs
		      "log"
		      "--config" "extensions.graphlog="
		      "-G"
		      "--limit" (number-to-string monky-log-cutoff-length)
		      "--template" "{node} {desc|firstline}\n")))


;;; Commit mode

(define-minor-mode monky-commit-mode
  "Minor mode to view a hg commit.

\\{monky-commit-mode-map}"

  :group monky
  :init-value ()
  :lighter ()
  :keymap monky-commit-mode-map)

(defvar monky-commit-buffer-name "*monky-commit*")

(defun monky-show-commit (commit &optional select)
  (when (monky-section-p commit)
    (setq commit (monky-section-info commit)))
  (unless (and commit
	       (monky-hg-revision-p commit))
    (error "%s is not a commit" commit))
  (let ((topdir (monky-get-root-dir))
	(buffer (get-buffer-create monky-commit-buffer-name)))
    (display-buffer buffer)
    (with-current-buffer buffer
      (monky-mode-init topdir 'commit
		       #'monky-refresh-commit-buffer commit)
      (monky-commit-mode t))
    (if select
	(pop-to-buffer buffer))))

(defun monky-refresh-commit-buffer (commit)
  (monky-create-buffer-sections
    (monky-hg-section nil nil
		      'monky-wash-commit
		      "log"
		      "--patch"
		      "--rev" commit)))

(defun monky-wash-commit ()
  (while (and (not (eobp)) (not (looking-at "^diff")) )
    (forward-line))
  (when (looking-at "^diff")
    (monky-wash-diffs)))

;;; Branch mode
(define-minor-mode monky-branches-mode
  "Minor mode for hg branch.

\\{monky-branches-mode-map}"
  :group monky
  :init-value ()
  :lighter ()
  :keymap monky-branches-mode-map)

(defvar monky-branches-buffer-name "*monky-branches*")

(defvar monky-branch-re "^\\(.*[^\s]\\)\s* \\([0-9]+\\):\\([0-9a-z]\\{12\\}\\)\\(.*\\)$")

(defvar monky-current-branch-name nil)
(make-variable-buffer-local 'monky-current-branch-name)

(defun monky-present-branch-line (name rev node status)
  (concat rev " : "
	  (propertize node 'face 'monky-log-sha1) " "
	  (if (equal name monky-current-branch-name)
	      (propertize name 'face 'monky-branch)
	    name)
	  " "
	  status))

(defun monky-wash-branch-line ()
  (if (looking-at monky-branch-re)
      (let ((name (match-string 1))
	    (rev (match-string 2))
	    (node (match-string 3))
	    (status (match-string 4)))
	(monky-delete-line)
	(monky-with-section name 'branch
	  (insert (monky-present-branch-line name rev node status))
	  (monky-set-section-info node)
	  (forward-line))
	t)
    nil))

(defun monky-wash-branches ()
  (monky-wash-sequence #'monky-wash-branch-line))

(defun monky-refresh-branches-buffer ()
  (setq monky-current-branch-name (monky-current-branch))
  (monky-create-buffer-sections
    (monky-with-section 'buffer nil
      (monky-hg-section nil "Branches:"
			#'monky-wash-branches
			"branches"))))

(defun monky-current-branch ()
  (monky-hg-string "branch"))

(defun monky-branches ()
  (interactive)
  (let ((topdir (monky-get-root-dir)))
    (pop-to-buffer monky-branches-buffer-name)
    (monky-mode-init topdir 'branches #'monky-refresh-branches-buffer)
    (monky-branches-mode t)))

(defun monky-checkout-item ()
  "Checkout the revision represented by current item."
  (interactive)
  (monky-section-action (item info "checkout")
    ((branch)
     (monky-checkout info))
    ((log commits commit)
     (monky-checkout info))))

;;; Queue mode
(define-minor-mode monky-queue-mode
  "Minor mode for hg Queue.

\\{monky-queue-mode-map}"
  :group monky
  :init-value ()
  :lighter ()
  :keymap monky-queue-mode-map)

(defvar monky-queue-buffer-name "*monky-queue*")

(defvar monky-patches-dir ".hg/patches/")

(defun monky-insert-patch (patch)
  (let ((p (point))
	(monky-hide-diffs nil))
    (save-restriction
      (narrow-to-region p p)
      (insert-file-contents (concat monky-patches-dir patch))
      (goto-char (point-max))
      (if (not (eq (char-before) ?\n))
	  (insert "\n"))
      (goto-char p)
      (while (and (not (eobp)) (not (looking-at "^diff")))
	(monky-delete-line t))
      (when (looking-at "^diff")
	(monky-wash-diffs))
      (goto-char (point-max)))))

(defun monky-insert-guards (patch)
  (let ((guards (remove-if
		 (lambda (guard) (string= "unguarded" guard))
		 (split-string
		  (cadr (split-string
			 (monky-hg-string "qguard" patch
					  "--config" "extensions.mq=")
			 ":"))))))
    (dolist (guard guards)
      (insert " " (propertize guard
			      'face
			      (if (monky-string-starts-with-p guard "+")
				  'monky-queue-positive-guard
				'monky-queue-negative-guard))))
    (insert "\n")))

(defun monky-wash-queue-patch ()
  (if (looking-at "^\\([^\n]+\\)$")
      (let ((patch (match-string 1)))
	(monky-delete-line)
	(let ((monky-section-hidden-default t))
	  (monky-with-section patch 'patch
	    (monky-set-section-info patch)
	    (insert "\t" patch)
	    (monky-insert-guards patch)
	    (monky-insert-patch patch)
	    (forward-line)))
	t)
    nil))

(defun monky-wash-queue-patches ()
  (monky-wash-sequence #'monky-wash-queue-patch))

;;; Applied Patches
(defun monky-insert-queue-applied ()
  (monky-hg-section 'applied "Applied Patches:" #'monky-wash-queue-patches
		    "qapplied" "--config" "extensions.mq="))

;;; UnApplied Patches
(defun monky-insert-queue-unapplied ()
  (monky-hg-section 'unapplied "UnApplied Patches:" #'monky-wash-queue-patches
		    "qunapplied" "--config" "extensions.mq="))

;;; Series
(defun monky-insert-queue-series ()
  (monky-hg-section 'qseries "Series:" #'monky-wash-queue-patches
		    "qseries" "--config" "extensions.mq="))

(defun monky-wash-active-guards ()
  (if (looking-at "^no active guards")
      (monky-delete-line t)
    (monky-wash-sequence
     (lambda ()
       (let ((guard (buffer-substring (point) (point-at-eol))))
	 (monky-delete-line)
	 (insert " " (propertize guard 'face 'monky-queue-positive-guard))
	 (forward-line))))))


;;; Active guards
(defun monky-insert-active-guards ()
  (monky-hg-section 'active-guards "Active Guards:" #'monky-wash-active-guards
		    "qselect" "--config" "extensions.mq="))

(defun monky-refresh-queue-buffer ()
  (monky-create-buffer-sections
    (monky-with-section 'queue nil
      (monky-insert-active-guards)
      (monky-insert-queue-applied)
      (monky-insert-queue-unapplied)
      (monky-insert-queue-series))))

(defun monky-queue ()
  (interactive)
  (let ((topdir (monky-get-root-dir)))
    (pop-to-buffer monky-queue-buffer-name)
    (monky-mode-init topdir 'queue #'monky-refresh-queue-buffer)
    (monky-queue-mode t)))

(defun monky-qpop (&optional patch)
  (interactive)
  (apply #'monky-run-hg
	 "qpop"
	 "--config" "extensions.mq="
	 (if patch (list patch) '())))

(defun monky-qpush (&optional patch)
  (interactive)
  (apply #'monky-run-hg
	 "qpush"
	 "--config" "extensions.mq="
	 (if patch (list patch) '())))

(defun monky-qpush-all ()
  (interactive)
  (monky-run-hg "qpush" "--all"
		"--config" "extensions.mq="))

(defun monky-qpop-all ()
  (interactive)
  (monky-run-hg "qpop" "--all"
		"--config" "extensions.mq="))

(defun monky-qrefresh ()
  (interactive)
  (monky-run-hg "qrefresh"
		"--config" "extensions.mq="))

(defun monky-qremove (patch)
  (monky-run-hg "qremove" patch
		"--config" "extensions.mq="))

(defun monky-qnew (patch)
  (interactive (list (read-string "Patch Name : ")))
  (if (not current-prefix-arg)
      (monky-run-hg "qnew" patch
		    "--config" "extensions.mq=")
    (monky-pop-to-log-edit 'qnew patch)))

(defun monky-qinit ()
  (interactive)
  (monky-run-hg "qinit"
		"--config" "extensions.mq="))

(defun monky-qrename (old-patch &optional new-patch)
  (let ((new-patch (or new-patch
		       (read-string "New Patch Name : "))))
    (monky-run-hg "qrename" old-patch new-patch
		  "--config" "extensions.mq=")))

(defun monky-qfold (patch)
  (monky-run-hg "qfold" patch
		"--config" "extensions.mq="))

(defun monky-qguard (patch)
  (let ((guards (monky-parse-args (read-string "Guards : "))))
    (apply #'monky-run-hg "qguard" patch
	   "--config" "extensions.mq="
	   "--" guards)))

(defun monky-qselect ()
  (interactive)
  (let ((guards (monky-parse-args (read-string "Guards : "))))
    (apply #'monky-run-hg "qselect"
	   "--config" "extensions.mq="
	   guards)))

(defun monky-qfinish (patch)
  (monky-run-hg "qfinish" patch
		"--config" "extensions.mq="))

(defun monky-qpop-item ()
  (interactive)
  (monky-section-action (item info "qpop")
    ((applied patch)
     (monky-qpop info)
     (monky-qpop))
    ((applied)
     (monky-qpop-all))))

(defun monky-qpush-item ()
  (interactive)
  (monky-section-action (item info "qpush")
    ((unapplied patch)
     (monky-qpush info))
    ((unapplied)
     (monky-qpush-all))))

(defun monky-qremove-item ()
  (interactive)
  (monky-section-action (item info "qremove")
    ((unapplied patch)
     (monky-qremove info))))

(defun monky-qrename-item ()
  (interactive)
  (monky-section-action (item info "qrename")
    ((patch)
     (monky-qrename info))))

(defun monky-qfold-item ()
  (interactive)
  (monky-section-action (item info "qfold")
    ((unapplied patch)
     (monky-qfold info))))

(defun monky-qguard-item ()
  (interactive)
  (monky-section-action (item info "qguard")
    ((patch)
     (monky-qguard info))))

(defun monky-qfinish-item ()
  (interactive)
  (monky-section-action (item info "qfinish")
    ((applied patch)
     (monky-qfinish info))))

;;; Log edit mode

(defvar monky-log-edit-mode-hook nil
  "Hook run by `monky-log-edit-mode'.")

(defvar monky-log-edit-buffer-name "*monky-edit-log*"
  "Buffer name for composing commit messages.")

(define-derived-mode monky-log-edit-mode text-mode "Monky Log Edit")

(defvar monky-pre-log-edit-window-configuration nil)
(defvar monky-log-edit-client-buffer nil)
(defvar monky-log-edit-operation nil)
(defvar monky-log-edit-info nil)

(defun monky-restore-pre-log-edit-window-configuration ()
  (when monky-pre-log-edit-window-configuration
    (set-window-configuration monky-pre-log-edit-window-configuration)
    (setq monky-pre-log-edit-window-configuration nil)))

(defun monky-log-edit-commit ()
  "Finish edit and commit."
  (interactive)
  (when (= (buffer-size) 0)
    (error "No %s message" monky-log-edit-operation))
  (let ((commit-buf (current-buffer)))
    (case monky-log-edit-operation
      ('commit
       (with-current-buffer (monky-find-status-buffer default-directory)
	 (apply #'monky-run-async-with-input commit-buf
		monky-hg-executable
		(append monky-hg-standard-options
			(list "commit" "--logfile" "-")
			monky-staged-files))))
      ('backout
       (with-current-buffer monky-log-edit-client-buffer
	 (monky-run-async-with-input commit-buf
				   monky-hg-executable
				   "backout"
				   "--merge"
				   "--logfile" "-"
				   monky-log-edit-info)))
      ('qnew
       (with-current-buffer monky-log-edit-client-buffer
	 (monky-run-async-with-input commit-buf
				     monky-hg-executable
				     "qnew" monky-log-edit-info
				     "--config" "extensions.mq="
				     "--logfile" "-")))))
  (erase-buffer)
  (bury-buffer)
  (monky-restore-pre-log-edit-window-configuration))

(defun monky-log-edit-cancel-log-message ()
  "Abort edits and erase commit message being composed."
  (interactive)
  (when (or (not monky-log-edit-confirm-cancellation)
	    (yes-or-no-p
	     "Really cancel editing the log (any changes will be lost)?"))
    (erase-buffer)
    (bury-buffer)
    (monky-restore-pre-log-edit-window-configuration)))

(defun monky-pop-to-log-edit (operation &optional info)
  (let ((dir default-directory)
	(buf (get-buffer-create monky-log-edit-buffer-name)))
    (setq monky-pre-log-edit-window-configuration
	  (current-window-configuration)
	  monky-log-edit-operation operation
	  monky-log-edit-client-buffer (current-buffer)
	  monky-log-edit-info info)
    (pop-to-buffer buf)
    (setq default-directory dir)
    (monky-log-edit-mode)
    (message "Type C-c C-c to %s (C-c C-k to cancel)." monky-log-edit-operation)))

(defun monky-log-edit ()
  "Bring up a buffer to allow editing of commit messages."
  (interactive)
  (if (not (or monky-staged-files (monky-merge-p)))
      (error "Nothing staged")
    (monky-pop-to-log-edit 'commit)))

(provide 'monky)

;;; monky.el ends here
