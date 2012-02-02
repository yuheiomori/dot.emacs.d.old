;; anything

(require 'anything-startup)

(global-set-key (kbd "C-:") 'anything-for-files)
;(define-key anything-map (kbd "C-:") 'abort-recursive-edit)
(define-key anything-map (kbd "C-:") 'anything-next-line)

(global-set-key (kbd "C-.") 'anything-resume)
(define-key anything-map (kbd "C-.") 'anything-next-line)

(global-set-key (kbd "M-y") 'anything-show-kill-ring)
(define-key anything-map (kbd "M-y") 'abort-recursive-edit)

(global-set-key (kbd "M-x") 'anything-M-x)
(define-key anything-map (kbd "M-x") 'abort-recursive-edit)

(global-set-key (kbd "C-x C-m") 'anything-M-x)
(define-key anything-map (kbd "C-x C-m") 'abort-recursive-edit)

(require 'anything-etags+)
(setq anything-etags+-use-short-file-name nil)
(setq anything-etags+-highlight-tag-after-jump t)
;;you can use  C-uM-. input symbol (default thing-at-point 'symbol)
(global-set-key "\M-." 'anything-etags+-select-one-key)
;;list all visited tags
(global-set-key "\M-*" 'anything-etags+-history)
(global-set-key (kbd "M-<left>") 'anything-etags+-history)
(setq tags-table-list '("~/.emacs.d/tags/TAGS"))


(require 'anything-project)
;(global-set-key (kbd "C-c C-f") 'anything-project)
(global-set-key (kbd "M-t") 'anything-project)
(define-key anything-map (kbd "M-t") 'abort-recursive-edit)

(ap:add-project
 :name 'python
 :look-for '(".hg")
 :include-regexp '("\\.py$" "\\.html$")
  )



;; anything-c-moccur
;;; color-moccur.elの設定
(require 'color-moccur)
;; 複数の検索語や、特定のフェイスのみマッチ等の機能を有効にする
;; 詳細は http://www.bookshelf.jp/soft/meadow_50.html#SEC751
(setq moccur-split-word t)
;; migemoがrequireできる環境ならmigemoを使う
(when (require 'migemo nil t) ;第三引数がnon-nilだとloadできなかった場合にエラーではなくnilを返す
  (setq moccur-use-migemo t))

(require 'anything-c-moccur)
(setq anything-c-moccur-anything-idle-delay 0.2 
      anything-c-moccur-higligt-info-line-flag t 
      anything-c-moccur-enable-auto-look-flag t 
      anything-c-moccur-enable-initial-pattern t)
(global-set-key (kbd "M-o") 'anything-c-moccur-occur-by-moccur)
(global-set-key (kbd "C-M-o") 'anything-c-moccur-dmoccur) 
(add-hook 'dired-mode-hook 
          '(lambda ()
             (local-set-key (kbd "O") 'anything-c-moccur-dired-do-moccur-by-moccur)))

(define-key isearch-mode-map (kbd "C-o") 'anything-c-moccur-from-isearch)
(define-key isearch-mode-map (kbd "C-M-o") 'isearch-occur)


; http://d.hatena.ne.jp/ground256/20111008/1318063872
;; (auto-install-from-url "https://raw.github.com/gist/457761/539882a79ec11bc9b6e1ac417cdafe0e198e245f/migemo.el")
(require 'migemo)
;; (auto-install-from-emacswiki "anything-migemo.el")
(require 'anything-migemo)
(setq migemo-command "/usr/local/bin/cmigemo")
(setq migemo-options '("-q" "--emacs"))
(setq migemo-dictionary "/usr/local/share/migemo/utf-8/migemo-dict")
(setq migemo-user-dictionary nil)
(setq migemo-coding-system 'utf-8-unix)
(setq migemo-regex-dictionary nil)
(load-library "migemo")
(migemo-init)


;http://sheephead.homelinux.org/2010/08/04/4018/
;(auto-compression-mode t)
(defvar anything-c-source-info-elisp-ja
  '((info-index . "elisp-ja")))
(defvar anything-c-source-info-cl-ja
  '((info-index . "cl-j")))
(defvar anything-c-source-info-emacs-ja
  '((info-index . "emacs-ja")))
(defvar anything-c-source-info-emacs-lisp-intro-ja
   '((info-index . "emacs-lisp-intro-ja.info")))
(defvar anything-c-source-info-hustler-ja
  '((info-index . "hustler")))

(defun anything-info-ja-at-point ()
  "Preconfigured `anything' for searching info at point."
  (interactive)
  (anything '(anything-c-source-info-elisp-ja
              anything-c-source-info-cl-ja
              anything-c-source-info-emacs-ja
              anything-c-source-info-emacs-lisp-intro-ja
              anything-c-source-info-hustler-ja
              )
            (thing-at-point 'symbol) nil nil nil "*anything info*"))



(defvar anything-c-source-info-python-lib-ja
  '((info-index . "python-lib-jp.info")))
(defvar anything-c-source-info-python-ref-ja
  '((info-index . "python-ref-jp.info")))
(defvar anything-c-source-info-python-api-ja
  '((info-index . "python-api-jp.info")))
(defvar anything-c-source-info-python-ext-ja
  '((info-index . "python-ext-jp.info")))
(defvar anything-c-source-info-python-tut-ja
  '((info-index . "python-tut-jp.info")))
(defvar anything-c-source-info-python-dist-ja
  '((info-index . "python-dist-jp.info")))

(defun anything-info-python-at-point ()
  "Preconfigured `anything' for searching info at point."
  (interactive)
  (anything '(anything-c-source-info-python-lib-ja
              anything-c-source-info-python-ref-ja
              anything-c-source-info-python-api-ja
              anything-c-source-info-python-ext-ja
              anything-c-source-info-python-tut-ja
              anything-c-source-info-python-dist-ja)
            (thing-at-point 'symbol) nil nil nil "*anything info*"))
