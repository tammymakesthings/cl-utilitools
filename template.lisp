(eval-when (:compile-toplevel :load-toplevel :execute)
  (ql:quickload '(
                  :adopt 
                  :cl-ppcre 
                  :with-user-abort
                  ) 
                :silent t)
  )

(defpackage :template
  (:use :cl)
  (:export :toplevel :*ui*)
  )

(in-package :template)

;;;; Configuration ------------------------------------------------------------


;;;; Errors -------------------------------------------------------------------

(define-condition user-error (error) ())

;;;; Functionality ------------------------------------------------------------

(defun hello (name)
  (format t "Hello ~A!~%" name)
  )

;;;; Run ----------------------------------------------------------------------

(defun run (name)
  (hello (or name "gentle user"))
  )

(defparameter *option-help*
  (adopt:make-option 'help
    :help "Display help and exit."
    :long "help"
    :short #\h
    :reduce (constantly t)))

(adopt:defparameters (*option-debug* *option-no-debug*)
  (adopt:make-boolean-options 'debug
    :long "debug"
    :short #\d
    :help "Enable the Lisp debugger."
    :help-no "Disable the Lisp debugger (the default)."))

(adopt:define-string *help-text*
    "Help text" )

(adopt:define-string *extra-manual-text*
    "Extra manual text"
                     )

(defparameter *examples*
  '(("Example title:" . "Example text")
    ))

(defparameter *ui*
  (adopt:make-interface
    :name "template"
    :usage "[OPTIONS] NAME"
    :summary "do a thing"
    :help *help-text*
    :manual (format nil "~A~2%~A" *help-text* *extra-manual-text*)
    :examples *examples*
    :contents (list
                *option-help*
                *option-debug*
                *option-no-debug*
                )
    )
  )

(defmacro exit-on-ctrl-c (&body body)
  `(handler-case (with-user-abort:with-user-abort (progn ,@body))
     (with-user-abort:user-abort () (adopt:exit 130))))

(defun configure (options)
  (declare (ignorable options))
  )

(defun toplevel ()
  (sb-ext:disable-debugger)
  (exit-on-ctrl-c
    (multiple-value-bind (arguments options)
        (adopt:parse-options-or-exit *ui*)
      (when (gethash 'debug options)
        (sb-ext:enable-debugger))
      (handler-case
          (cond
            ((gethash 'help options) (adopt:print-help-and-exit *ui*))
            (t (destructuring-bind (&optional name) arguments
                 (configure options)
                 (run name))))
        (user-error (e)
                    (adopt:print-error-and-exit e))))))

