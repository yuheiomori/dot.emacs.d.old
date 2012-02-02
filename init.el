(add-to-list 'load-path "~/.emacs.d/config/")
(add-to-list 'load-path "~/.emacs.d/vendor")
(load "general")


(dolist (dir (list
              "/sbin"
              "/usr/sbin"
              "/bin"
              "/usr/bin"
              "/opt/local/bin"
              "/sw/bin"
              "/usr/local/bin"
	      "/usr/local/mysql/bin"
	      "/usr/local/share/npm/bin"
	      "/Applications/GoogleAppEngineLauncher.app/Contents/Resources/GoogleAppEngine-default.bundle/Contents/Resources/google_appengine"
              (expand-file-name "~/bin")
              (expand-file-name "~/.emacs.d/bin")
              ))
 ;; PATH と exec-path に同じ物を追加します
 (when (and (file-exists-p dir) (not (member dir exec-path)))
   (setenv "PATH" (concat dir ":" (getenv "PATH")))
   (setq exec-path (append (list dir) exec-path))))




;; auto-install
(require 'auto-install)
(setq auto-install-directory "~/.emacs.d/vendor/auto-install/")
(add-to-list 'load-path "~/.emacs.d/vendor/auto-install/")

;; package
(require 'package)
;;リポジトリにMarmaladeを追加
(add-to-list 'package-archives '("marmalade" . "http://marmalade-repo.org/packages/"))
(add-to-list 'package-archives '("ELPA" . "http://tromey.com/elpa/"))
;;インストールするディレクトリを指定
(setq package-user-dir (concat user-emacs-directory "vendor/elpa"))
;;インストールしたパッケージにロードパスを通してロードする
(package-initialize)


;; monky
(global-set-key (kbd "M-G") 'monky-status)
(define-key dired-mode-map [(meta G)] 'monky-status)

(custom-set-variables
  ;; custom-set-variables was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 '(kill-whole-line nil)
 '(monky-hg-process-environment (quote ("TERM=dumb" "HGPLAIN=" "LANGUAGE=C" "HGENCODING=utf-8")))
 '(safe-local-variable-values (quote ((b . 2) (a . 1))))
 '(uniquify-buffer-name-style (quote post-forward-angle-brackets) nil (uniquify))
 '(yas/global-mode t nil (yasnippet))
 '(yas/prompt-functions (quote (yas/dropdown-prompt yas/completing-prompt yas/ido-prompt yas/no-prompt))))
(custom-set-faces
  ;; custom-set-faces was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 )


;; python
(autoload 'python-mode "python-mode" "Python editing mode." t)
(setq auto-mode-alist (cons '("\\.py$" . python-mode) auto-mode-alist))
(setq interpreter-mode-alist (cons '("python" . python-mode)
                                   interpreter-mode-alist))

;;; flymake for python
(add-hook 'python-mode-hook 'flymake-find-file-hook)
(when (load "flymake" t)
  (defun flymake-pyflakes-init ()
    (let* ((temp-file (flymake-init-create-temp-buffer-copy
                       'flymake-create-temp-inplace))
           (local-file (file-relative-name
                        temp-file
                        (file-name-directory buffer-file-name))))
      (list "pycheckers"  (list local-file))))
  (add-to-list 'flymake-allowed-file-name-masks
               '("\\.py\\'" flymake-pyflakes-init)))
(load-library "flymake-cursor")
(global-set-key (kbd "M-e") 'flymake-goto-next-error)
(global-set-key (kbd "M-E") 'flymake-goto-prev-error)

(add-hook 'python-mode-hook 'hs-minor-mode)

;;; ruby
(add-hook 'ruby-mode-hook 'hs-minor-mode)



(require 'auto-complete)

(require 'summarye)
(define-key help-map "M" 'se/make-summary-buffer)

(require 'moccur-edit)

(require 'color-theme-zenburn)
(color-theme-zenburn)


;; yasnippet
(setq yas/root-directory "~/.emacs.d/snippets")
(add-hook 'python-mode-hook 'yas/minor-mode-on)
(add-hook 'js2-mode-hook  'yas/minor-mode-on)

;; js2
(autoload 'js2-mode "js2-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.js$" . js2-mode))


;; coffee-mode
(defun coffee-custom ()
  "coffee-mode-hook"
 (set (make-local-variable 'tab-width) 2)
 ;; Emacs key binding
 (define-key coffee-mode-map [(meta R)] 'coffee-compile-buffer)
 (define-key coffee-mode-map [(meta r)] 'coffee-compile-region)
 )

(add-hook 'coffee-mode-hook
  '(lambda() (coffee-custom)))

(shell)

(require 'uniquify)
;(require 'textmate)
;(textmate-mode)


(require 'haml-mode)
(require 'flymake-haml)
(add-hook 'haml-mode-hook 'flymake-haml-load)


(require 'auto-highlight-symbol)
(global-auto-highlight-symbol-mode t)
(ahs-set-idle-interval 0.8)

(require 'fold-dwim)
(global-set-key (kbd "<f7>")      'fold-dwim-toggle)
(global-set-key (kbd "<M-f7>")    'fold-dwim-hide-all)
(global-set-key (kbd "<S-M-f7>")  'fold-dwim-show-all)


(require 'navi2ch)



(require 'highlight-indentation)

 	
(global-set-key (kbd "C-l") '(lambda () (interactive) (recenter 0)))

;(setq visible-bell t)
(setq ring-bell-function 'ignore)


(add-to-list 'load-path "~/.emacs.d/vendor/manual_install/expand-region.el")
(require 'expand-region)
(global-set-key (kbd "C-@") 'er/expand-region)
(global-set-key (kbd "C-M-@") 'er/contract-region)


(add-to-list 'load-path "~/.emacs.d/vendor/manual_install/rvm.el")
(require 'rvm)





(defun py-backward-kill-word (arg)
 "Kill characters backward until encountering the beginning of a word.
With argument ARG, do this that many times."
 (interactive "p")
 (kill-region (point) (progn (py-forward-into-nomenclature (- arg)) (point))))

(add-hook 'python-mode-hook
	  (lambda()
	    (define-key py-mode-map [(meta f)] 'py-forward-into-nomenclature) 
	    (define-key py-mode-map [(meta b)] 'py-backward-into-nomenclature) 
	    (define-key py-mode-map [(control w)] 'py-backward-kill-word) 
	    ))



;; open-junk-file
(require 'open-junk-file)
(global-set-key (kbd "C-x C-z") 'open-junk-file)
(require 'lispxmp)
(define-key emacs-lisp-mode-map (kbd "C-c C-d") 'lispxmp)

(require 'paredit)
(add-hook 'emacs-lisp-mode-hook 'enable-paredit-mode)
(add-hook 'lisp-interaction-mode-hook 'enable-paredit-mode)
(add-hook 'lisp-mode-hook 'enable-paredit-mode)
(add-hook 'ielm-mode-hook 'enable-paredit-mode)
(require 'auto-async-byte-compile)
(setq auto-async-byte-compile-exclude-files-regexp "/junk/")
(add-hook 'emacs-lisp-mode-hook 'enable-auto-async-byte-compile-mode)
(add-hook 'emacs-lisp-mode-hook 'turn-on-eldoc-mode)
(add-hook 'lisp-interaction-mode-hook 'turn-on-eldoc-mode)
(add-hook 'ielm-mode-hook 'turn-on-eldoc-mode)
(setq eldoc-idle-delay 0.2)
(setq eldoc-minor-mode-string "")
(show-paren-mode 1)
(global-set-key "\C-m" 'newline-and-indent)
(find-function-setup-keys)




;; Dictionary.app を Emacs から引く
;; (+ "http://sakito.jp/mac/dictionary.html"
;;    "http://d.hatena.ne.jp/tomoya/20091218/1261138091"
;;    "http://d.hatena.ne.jp/tomoya/20100103/1262482873")
(defvar dict-bin "~/.emacs.d/bin/dict.py"
  "dict 実行ファイルのパス")
(defun my-dictionary ()
  (interactive)
  (let ((pt (save-excursion (mouse-set-point last-nonmenu-event)))
        (old-buf (current-buffer))
        (dict-buf (get-buffer-create "*dictionary.app*"))
        beg end)
    (if (and mark-active
             (<= (region-beginning) pt) (<= pt (region-end)))
        (setq beg (region-beginning)
              end (region-end))
      (save-excursion
        (goto-char pt)
        (setq end (progn (forward-word) (point)))
        (setq beg (progn (backward-word) (point)))
        ))
    (setq word (buffer-substring-no-properties beg end))
    (set-buffer dict-buf)
    (erase-buffer)
    (call-process dict-bin
                  nil "*dictionary.app*" t word
                  "Japanese-English" "Japanese" "Japanese Synonyms")
    (setq dict (buffer-string))
    (set-buffer old-buf)
    (when (not (eq (length dict) 0))
      (popup-tip dict :margin t :scroll-bar t) t)
    ))
;(defvar dict-timer nil)
;(defvar dict-delay 1.0)
;(defun dict-timer ()
;  (when (and (not (minibufferp))
;             (and mark-active transient-mark-mode))
;    (ns-popup-dictionary)))
;(setq dict-timer (run-with-idle-timer dict-delay dict-delay 'dict-timer))
(define-key global-map (kbd "C-M-d") 'my-dictionary)



(let ((ruby-mode-hs-info
       '(ruby-mode
          "class\\|module\\|def\\|if\\|unless\\|case\\|while\\|until\\|for\\|begin\\|do"
          "end"
          "#"
          ruby-move-to-block
          nil)))
  (if (not (member ruby-mode-hs-info hs-special-modes-alist))
      (setq hs-special-modes-alist
            (cons ruby-mode-hs-info hs-special-modes-alist))))


(require 'info)
(add-to-list 'Info-directory-list "~/.emacs.d/info")

(defun open-sicp (&optional other-window)
  (interactive "P")
  (info "sicp.info" (and other-window "*SICP*")))

(load "anything-settings")