(eval-when (:compile-toplevel :load-toplevel :execute)
  (ql:quickload '(:adopt :cl-ppcre :with-user-abort) :silent t))

(defpackage :batchcolor
  (:use :cl)
  (:export :toplevel :*ui*))

(in-package :batchcolor)

;;;; Configuration ------------------------------------------------------------
(defparameter *start* 0)
(defparameter *dark* t)

;;;; Errors -------------------------------------------------------------------
(define-condition user-error (error) ())

(define-condition missing-regex (user-error) ()
  (:report "A regular expression is required."))

(define-condition malformed-regex (user-error)
  ((underlying-error :initarg :underlying-error))
  (:report (lambda (c s)
             (format s "Invalid regex: ~A" (slot-value c 'underlying-error)))))

(define-condition overlapping-groups (user-error) ()
  (:report "Invalid regex: seems to contain overlapping capturing groups."))

(define-condition malformed-explicit (user-error)
  ((spec :initarg :spec))
  (:report
   (lambda (c s)
     (format s "Invalid explicit spec ~S, must be of the form \"R,G,B:string\" with colors being 0-5."
             (slot-value c 'spec)))))

;;;; Functionality ------------------------------------------------------------
(defun rgb-code (r g b)
  ;; The 256 color mode color values are essentially r/g/b in base 6, but
  ;; shifted 16 higher to account for the intiial 8+8 colors.
  (+ (* r 36)
     (* g 6)
     (* b 1)
     16))

(defun make-colors (excludep)
  (let ((result (make-array 256 :fill-pointer 0)))
    (dotimes (r 6)
      (dotimes (g 6)
        (dotimes (b 6)
          (unless (funcall excludep (+ r g b))
            (vector-push-extend (rgb-code r g b) result)))))
    result))

(defparameter *dark-colors*  (make-colors (lambda (v) (< v 3))))
(defparameter *light-colors* (make-colors (lambda (v) (> v 11))))

(defparameter *explicits* (make-hash-table :test #'equal))

(defun djb2 (string)
  ;; http://www.cse.yorku.ca/~oz/hash.html
  (reduce (lambda (hash c)
            (mod (+ (* 33 hash) c) (expt 2 64)))
          string
          :initial-value 5381
          :key #'char-code))

(defun find-color (string)
  (gethash string *explicits*
           (let ((colors (if *dark* *dark-colors* *light-colors*)))
             (aref colors
                   (mod (+ (djb2 string) *start*)
                        (length colors))))))

(defun ansi-color-start (color)
  (format nil "~C[38;5;~Dm" #\Escape color))

(defun ansi-color-end ()
  (format nil "~C[0m" #\Escape))

(defun print-colorized (string)
  (format *standard-output* "~A~A~A"
          (ansi-color-start (find-color string))
          string
          (ansi-color-end)))

(defun colorize-line (scanner line &aux (start 0))
  (ppcre:do-scans (ms me rs re scanner line)
    ;; If we don't have any register groups, colorize the entire match.
    ;; Otherwise, colorize each matched capturing group.
    (let* ((regs? (plusp (length rs)))
           (starts (if regs? (remove nil rs) (list ms)))
           (ends   (if regs? (remove nil re) (list me))))
      (map nil (lambda (word-start word-end)
                 (unless (<= start word-start)
                   (error 'overlapping-groups))
                 (write-string line *standard-output* :start start :end word-start)
                 (print-colorized (subseq line word-start word-end))
                 (setf start word-end))
           starts ends)))
  (write-line line *standard-output* :start start))

;;;; Run ----------------------------------------------------------------------
(defun run% (scanner stream)
  (loop :for line = (read-line stream nil)
        :while line
        :do (colorize-line scanner line)))

(defun run (pattern paths)
  (let ((scanner (handler-case (ppcre:create-scanner pattern)
                   (ppcre:ppcre-syntax-error (c)
                     (error 'malformed-regex :underlying-error c))))
        (paths (or paths '("-"))))
    (dolist (path paths)
      (if (string= "-" path)
          (run% scanner *standard-input*)
          (with-open-file (stream path :direction :input)
            (run% scanner stream))))))

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

(adopt:defparameters (*option-randomize* *option-no-randomize*)
    (adopt:make-boolean-options 'randomize
				:help "Randomize the choice of color each run."
				:help-no "Do not randomize the choice of color each run (the default)."
				:long "randomize"
				:short #\r))

(adopt:defparameters (*option-dark* *option-light*)
    (adopt:make-boolean-options 'dark
				:name-no 'light
				:long "dark"
				:long-no "light"
				:help "Optimize for dark terminals (the default)."
				:help-no "Optimize for light terminals."
				:initial-value t))

(defun parse-explicit (spec)
  (ppcre:register-groups-bind
   ((#'parse-integer r g b) string)
   ("^([0-5]),([0-5]),([0-5]):(.+)$" spec)
   (return-from parse-explicit (cons string (rgb-code r g b))))
  (error 'malformed-explicit :spec spec))

(defparameter *option-explicit*
  (adopt:make-option 'explicit
		     :parameter "R,G,B:STRING"
		     :help "Highlight STRING in an explicit color.  May be given multiple times."
		     :manual (format nil "~
      Highlight STRING in an explicit color instead of randomly choosing one.  ~
      R, G, and B must be 0-5.  STRING is treated as literal string, not a regex.  ~
      Note that this doesn't automatically add STRING to the overall regex, you ~
      must do that yourself!  This is a known bug that may be fixed in the future.")
		     :long "explicit"
		     :short #\e
		     :key #'parse-explicit
		     :reduce #'adopt:collect))

(adopt:define-string *help-text*
    "batchcolor takes a regular expression and matches it against standard ~
   input one line at a time.  Each unique match is highlighted in its own color.~@
   ~@
   If the regular expression contains any capturing groups, only those parts of ~
   the matches will be highlighted.  Otherwise the entire match will be ~
   highlighted.  Overlapping capturing groups are not supported.")

(adopt:define-string *extra-manual-text*
    "If no FILEs are given, standard input will be used.  A file of - stands for ~
   standard input as well.~@
   ~@
   Overlapping capturing groups are not supported because it's not clear what ~
   the result should be.  For example: what should ((f)oo|(b)oo) highlight when ~
   matched against 'foo'?  Should it highlight 'foo' in one color?  The 'f' in ~
   one color and 'oo' in another color?  Should that 'oo' be the same color as ~
   the 'oo' in 'boo' even though the overall match was different?  There are too ~
   many possible behaviors and no clear winner, so batchcolor disallows ~
   overlapping capturing groups entirely.")

(defparameter *examples*
  '(("Colorize IRC nicknames in a chat log:"
     . "cat channel.log | batchcolor '<(\\\\w+)>'")
    ("Colorize UUIDs in a request log:"
     . "tail -f /var/log/foo | batchcolor '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}'")
    ("Colorize some keywords explicitly and IPv4 addresses randomly (note that the keywords have to be in the main regex too, not just in the -e options):"
     . "batchcolor 'WARN|INFO|ERR|(?:[0-9]{1,3}\\\\.){3}[0-9]{1,3}' -e '5,0,0:ERR' -e '5,4,0:WARN' -e '2,2,5:INFO' foo.log")
    ("Colorize earmuffed symbols in a Lisp file:"
     . "batchcolor '(?:^|[^*])([*][-a-zA-Z0-9]+[*])(?:$|[^*])' tests/test.lisp")))

(defparameter *ui*
  (adopt:make-interface
   :name "batchcolor"
   :usage "[OPTIONS] REGEX [FILE...]"
   :summary "colorize regex matches in batches"
   :help *help-text*
   :manual (format nil "~A~2%~A" *help-text* *extra-manual-text*)
   :examples *examples*
   :contents (list
              *option-help*
              *option-debug*
              *option-no-debug*
              (adopt:make-group 'color-options
                                :title "Color Options"
                                :options (list *option-randomize*
                                               *option-no-randomize*
                                               *option-dark*
                                               *option-light*
                                               *option-explicit*)))))

(defmacro exit-on-ctrl-c (&body body)
  `(handler-case (with-user-abort:with-user-abort (progn ,@body))
     (with-user-abort:user-abort () (adopt:exit 130))))

(defun configure (options)
  (loop :for (string . rgb) :in (gethash 'explicit options)
        :do (setf (gethash string *explicits*) rgb))
  (setf *start* (if (gethash 'randomize options)
                    (random 256 (make-random-state t))
                    0)
        *dark* (gethash 'dark options)))

(defun toplevel ()
  (sb-ext:disable-debugger)
  (exit-on-ctrl-c
   (multiple-value-bind (arguments options) (adopt:parse-options-or-exit *ui*)
     (when (gethash 'debug options)
       (sb-ext:enable-debugger))
     (handler-case
         (cond
           ((gethash 'help options) (adopt:print-help-and-exit *ui*))
           ((null arguments) (error 'missing-regex))
           (t (destructuring-bind (pattern . files) arguments
                (configure options)
                (run pattern files))))
       (user-error (e) (adopt:print-error-and-exit e))))))

