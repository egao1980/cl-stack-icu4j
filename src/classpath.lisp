(in-package #:cl-stack-icu4j)

;;; Resolve icu4j-<ver>.jar onto the ABCL classpath.
;;; Order: CL_STACK_ICU4J_JAR → lib/ next to .asd → XDG cache (download from Maven).

(defparameter *icu4j-maven-url*
  (format nil "https://repo1.maven.org/maven2/com/ibm/icu/icu4j/~A/icu4j-~A.jar"
          +icu4j-version+ +icu4j-version+))

(defparameter *icu4j-sha256*
  "bbb70d3be23110d7295823eee0c2e896ac3b619b3c0f26168f65eb972df51d2a")

(defvar *icu4j-loaded* nil)

(defun %system-root ()
  (let ((sys (asdf:find-system :cl-stack-icu4j nil)))
    (when sys (asdf:system-source-directory sys))))

(defun %cache-jar-path ()
  (merge-pathnames
   (format nil "cl-stack-icu4j/icu4j-~A.jar" +icu4j-version+)
   (uiop:xdg-cache-home)))

(defun %lib-jar-path ()
  (let ((root (%system-root)))
    (when root
      (merge-pathnames (format nil "lib/icu4j-~A.jar" +icu4j-version+) root))))

(defun %verify-sha256 (path)
  "Best-effort SHA-256 check via `shasum`/`sha256sum` when present."
  (let ((expected *icu4j-sha256*))
    (unless expected
      (return-from %verify-sha256 t))
    (handler-case
        (let* ((out (with-output-to-string (s)
                      (uiop:run-program
                       (cond
                         ((uiop:file-exists-p "/usr/bin/shasum")
                          (list "/usr/bin/shasum" "-a" "256" (namestring path)))
                         ((uiop:file-exists-p "/usr/bin/sha256sum")
                          (list "/usr/bin/sha256sum" (namestring path)))
                         (t (return-from %verify-sha256 t)))
                       :output s)))
               (got (string-downcase (subseq out 0 (min 64 (length out))))))
          (or (string= got expected)
              (error 'icu4j-error
                     :message (format nil "SHA-256 mismatch for ~A (got ~A)" path got))))
      (error (c)
        (warn "cl-stack-icu4j: could not verify jar checksum: ~A" c)
        t))))

(defun %download-jar (dest)
  (uiop:ensure-all-directories-exist (list (uiop:pathname-directory-pathname dest)))
  (format *error-output* "~&; cl-stack-icu4j: downloading ~A~%  → ~A~%"
          *icu4j-maven-url* dest)
  (finish-output *error-output*)
  (uiop:run-program
   (list "curl" "-fsSL" "-o" (namestring dest) *icu4j-maven-url*)
   :output t :error-output t)
  (%verify-sha256 dest)
  dest)

(defun %resolve-jar ()
  (or (let ((env (uiop:getenv "CL_STACK_ICU4J_JAR")))
        (when (and env (plusp (length env)) (probe-file env))
          (pathname env)))
      (let ((lib (%lib-jar-path)))
        (when (and lib (probe-file lib)) lib))
      (let ((cache (%cache-jar-path)))
        (if (probe-file cache)
            cache
            (%download-jar cache)))))

#-abcl
(defun ensure-icu4j ()
  (warn "cl-stack-icu4j: designed for ABCL (ICU4J via java:j*).")
  nil)

#+abcl
(defun ensure-icu4j ()
  "Ensure ICU4J is on the classpath. Idempotent. Called at ASDF load."
  (unless *icu4j-loaded*
    (let ((jar (%resolve-jar)))
      (java:add-to-classpath (namestring (truename jar)))
      ;; Touch a class so missing/corrupt jars fail at load, not first call.
      (java:jfield "com.ibm.icu.util.VersionInfo" "ICU_VERSION")
      (setf *icu4j-loaded* t)))
  t)

#+abcl
(eval-when (:load-toplevel :execute)
  (ensure-icu4j))
