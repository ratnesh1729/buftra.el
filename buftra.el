;;; buftra.el --- for docstring support to py.

;; Copyright (C) 2015-2016, Friedrich Paetzke <f.paetzke@gmail.com>
;; Author: Friedrich Paetzke <f.paetzke@gmail.com>
;; URL: https://github.com/paetzke/buftra.el
;; Package-Version: 20220627.2244
;; Package-X-Original-Version: 20220627.2236
;; Version: 0.6


;;; Commentary:

;; makes it convenient to create new python projects within Emacs.


;;; Code:

(defun buftra--apply-rcs-patch (patch-buffer)
  "Apply an RCS-formatted diff from PATCH-BUFFER to the current buffer."
  (let ((target-buffer (current-buffer))
        (line-offset 0))
    (save-excursion
      (with-current-buffer patch-buffer
        (goto-char (point-min))
        (while (not (eobp))
          (unless (looking-at "^\\([ad]\\)\\([0-9]+\\) \\([0-9]+\\)")
            (error "Invalid rcs patch or internal error in buftra--apply-rcs-patch"))
          (forward-line)
          (let ((action (match-string 1))
                (from (string-to-number (match-string 2)))
                (len  (string-to-number (match-string 3))))
            (cond
             ((equal action "a")
              (let ((start (point)))
                (forward-line len)
                (let ((text (buffer-substring start (point))))
                  (with-current-buffer target-buffer
                    (setq line-offset (- line-offset len))
                    (goto-char (point-min))
                    (forward-line (- from len line-offset))
                    (insert text)))))
             ((equal action "d")
              (with-current-buffer target-buffer
                (goto-char (point-min))
                (forward-line (- from line-offset 1))
                (setq line-offset (+ line-offset len))
                (kill-whole-line len)
                (pop kill-ring)))
             (t
              (error "Invalid rcs patch or internal error in buftra--apply-rcs-patch")))))))))


(defun buftra--replace-region (filename)
  "Argument FILENAME simple filename."
  (delete-region (region-beginning) (region-end))
  (insert-file-contents filename))


(defun buftra--get-tmp-file-name ()
  "Return the temporal filename used to save the formatted file.

It uses variable `projectile-project-root' as relative directory to build the filename."
  (make-temp-file
   (concat
    (replace-regexp-in-string "/" "-" (file-relative-name (buffer-file-name) (projectile-project-root))) "-" executable-name)
   nil (concat "." file-extension)))

(defun buftra--apply-executable-to-buffer (executable-name
                                           executable-call
                                           only-on-region
                                           file-extension
                                           ignore-return-code)
  "Formats the current buffer according to the executable.
Argument EXECUTABLE-NAME simple exec.
Argument EXECUTABLE-CALL exec call.
Argument ONLY-ON-REGION only on region.
Argument FILE-EXTENSION f extension.
Argument IGNORE-RETURN-CODE ignore ret code."
  (when (not (executable-find executable-name))
    (error (format "%s command not found." executable-name)))
  (let ((tmpfile (buftra--get-tmp-file-name))
        (patchbuf (get-buffer-create (format "*%s patch*" executable-name)))
        (errbuf (get-buffer-create (format "*%s Errors*" executable-name)))
        (coding-system-for-read buffer-file-coding-system)
        (coding-system-for-write buffer-file-coding-system))
    (with-current-buffer errbuf
      (setq buffer-read-only nil)
      (erase-buffer))
    (with-current-buffer patchbuf
      (erase-buffer))

    (if (and only-on-region (use-region-p))
        (write-region (region-beginning) (region-end) tmpfile)
      (write-region nil nil tmpfile))

    (if (or (funcall executable-call errbuf tmpfile)
            ignore-return-code)
        (if (zerop (call-process-region (point-min) (point-max) "diff" nil
                                        patchbuf nil "-n" "-" tmpfile))
            (progn
              (kill-buffer errbuf)
              (message (format "Buffer is already %sed" executable-name)))

          (if only-on-region
              (buftra--replace-region tmpfile)
            (buftra--apply-rcs-patch patchbuf))

          (kill-buffer errbuf)
          (message (format "Applied %s" executable-name)))
      (error (format "Could not apply %s. Check *%s Errors* for details"
                     executable-name executable-name)))
    (kill-buffer patchbuf)
    (delete-file tmpfile)))

(provide 'buftra)

;; buftra.el ends here
