(in-package #:cl-stack-icu4j)

;;; Resolve icu4j-<ver>.jar onto the ABCL classpath.
;;; Order: CL_STACK_ICU4J_JAR → lib/ next to .asd → XDG cache (download from Maven).

(defparameter *icu4j-maven-url*
  (format nil "https://repo1.maven.org/maven2/com/ibm/icu/icu4j/~A/icu4j-~A.jar"
          +icu4j-version+ +icu4j-version+))

(defparameter *icu4j-sha256*
  "28b292e60d0d00c496bae88a15b2615f89f781be13670aeac9dc90f189570e07")

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

(defun %file-sha256-hex (path)
  "SHA-256 of the file at PATH as lowercase hex, through crypto-protocol."
  (let ((hasher (crypto-protocol:make-hasher
                 (or crypto-protocol:*crypto-backend*
                     (error 'icu4j-error
                            :message "crypto-protocol:*crypto-backend* is nil; cannot verify the ICU4J jar"))
                 :sha256))
        (buf (make-array 65536 :element-type '(unsigned-byte 8))))
    (with-open-file (in path :element-type '(unsigned-byte 8))
      (loop for n = (read-sequence buf in)
            while (plusp n)
            do (crypto-protocol:update! hasher buf :start 0 :end n)))
    (string-downcase
     (encoding-protocol:encode (crypto-protocol:finalize hasher) :encoding :base16))))

(defun verify-icu4j-jar (path &key (expected *icu4j-sha256*))
  "Check that the jar at PATH has SHA-256 EXPECTED (default: the pinned
*ICU4J-SHA256*). Returns PATH on a match. On a mismatch signals
ICU4J-CHECKSUM-MISMATCH; the jar is refused unless a handler invokes the
USE-UNVERIFIED-JAR restart, the explicit override for a jar you trust
anyway (e.g. a locally patched build). There is no other way past the check:
a missing hash tool or backend is an error, not a skip."
  (check-type expected string)
  (let ((actual (%file-sha256-hex path)))
    (if (string-equal actual expected)
        path
        (restart-case
            (error 'icu4j-checksum-mismatch
                   :path path :expected (string-downcase expected) :actual actual
                   :message (format nil "SHA-256 mismatch for ~A" path))
          (use-unverified-jar ()
            :report "Load this jar even though its SHA-256 does not match."
            path)))))

(defun %download-jar (dest)
  "Download the pinned jar to a temporary file next to DEST, verify it, then
rename it into place, so a bad download never lands in the cache."
  (uiop:ensure-all-directories-exist (list (uiop:pathname-directory-pathname dest)))
  (format *error-output* "~&; cl-stack-icu4j: downloading ~A~%  → ~A~%"
          *icu4j-maven-url* dest)
  (finish-output *error-output*)
  (let ((tmp (make-pathname :type "jar-partial" :defaults dest))
        (done nil))
    (unwind-protect
         (progn
           (uiop:run-program
            (list "curl" "-fsSL" "-o" (namestring tmp) *icu4j-maven-url*)
            :output t :error-output t)
           (verify-icu4j-jar tmp)
           (rename-file tmp dest)
           (setf done t)
           dest)
      (unless done
        (uiop:delete-file-if-exists tmp)))))

(defun %resolve-jar ()
  "Locate the jar (CL_STACK_ICU4J_JAR → lib/ → XDG cache, downloading when
absent) and verify its SHA-256 before returning it."
  (or (let ((env (uiop:getenv "CL_STACK_ICU4J_JAR")))
        (when (and env (plusp (length env)) (probe-file env))
          (verify-icu4j-jar (pathname env))))
      (let ((lib (%lib-jar-path)))
        (when (and lib (probe-file lib))
          (verify-icu4j-jar lib)))
      (let ((cache (%cache-jar-path)))
        (if (probe-file cache)
            (verify-icu4j-jar cache)
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
