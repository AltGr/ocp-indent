;; Eval this file to automatically use ocp-indent on caml/tuareg buffers
;;

(provide 'ocp-indent)
(require 'cl)

(defgroup ocp-indent nil
  "ocp-indent OCaml indenter binding configuration"
  :group 'languages)

(defcustom ocp-indent-path "ocp-indent"
  "*Path to access the ocp-indent command"
  :group 'ocp-indent :type '(file))

(defcustom ocp-indent-config nil
  "*Ocp-indent config string, as for its --config option.
WARNING: DEPRECATED, this will override any user or project
ocp-indent configuration files"
  :group 'ocp-indent
  :type '(choice (const nil) (string)))

(defcustom ocp-indent-syntax nil
  "*Enabled syntax extensions for ocp-indent (see option --syntax)"
  :group 'ocp-indent
  :type '(repeat (string)))

(defcustom ocp-indent-allow-tabs nil
  "*Allow indent-tabs-mode in ocaml buffers. Not recommended, won't work well."
  :group 'ocp-indent
  :type '(bool))

(defun ocp-in-indentation-p ()
  "Tests whether all characters between beginning of line and point
are blanks."
  (save-excursion
    (skip-chars-backward " \t")
    (bolp)))

(defun ocp-indent-args (start-line end-line)
  (append
   (list "--numeric"
         "--lines" (format "%d-%d" start-line end-line))
   (if ocp-indent-config (list "--config" ocp-indent-config) nil)
   (reduce (lambda (acc syn) (list* "--syntax" syn acc))
           ocp-indent-syntax :initial-value nil)))

(defun ocp-indent-file-to-string (file)
  (replace-regexp-in-string
   "\n$" ""
   (with-temp-buffer (insert-file-contents errfile)
                     (buffer-string))))

(defun ocp-indent-region (start end)
  (interactive "r")
  (let*
      ((start-line (line-number-at-pos start))
       (end-line (line-number-at-pos end))
       (errfile (make-temp-name "ocp-indent-error"))
       (indents-str
        (with-output-to-string
          (if (/= 0
                  (apply 'call-process-region
                         (point-min) (point-max) ocp-indent-path nil
                         (list standard-output errfile) nil
                         (ocp-indent-args start-line end-line)))
              (error "Can't indent: %s returned failure" cmd))))
       (indents (mapcar 'string-to-number (split-string indents-str))))
    (when (file-exists-p errfile)
      (message (ocp-indent-file-to-string errfile))
      (delete-file errfile))
    (save-excursion
      (goto-char start)
      (mapcar
       #'(lambda (indent) (indent-line-to indent) (forward-line))
       indents))
    (when (ocp-in-indentation-p) (back-to-indentation))))

(defun ocp-indent-line ()
  (interactive nil)
  (ocp-indent-region (point) (point)))

(defun ocp-setup-indent ()
  (interactive nil)
  (unless ocp-indent-allow-tabs (set 'indent-tabs-mode nil))
  (set (make-local-variable 'indent-line-function) #'ocp-indent-line)
  (set (make-local-variable 'indent-region-function) #'ocp-indent-region))

(add-hook 'tuareg-mode-hook 'ocp-setup-indent t)
(add-hook
 'caml-mode-hook
 '(lambda ()
    (ocp-setup-indent)
    (local-unset-key "\t")) ;; caml-mode rebinds TAB !
 t)
