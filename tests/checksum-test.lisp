(in-package #:cl-stack-icu4j/tests)

;;; Jar SHA-256 verification (cl-stack-icu4j#10): fail closed, the only way
;;; past a mismatch is the USE-UNVERIFIED-JAR restart. Runs on every Lisp.

(defparameter +abc-sha256+
  "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  "FIPS 180-2 test vector: SHA-256(\"abc\").")

(defun %temp-file (octets)
  (let ((path (uiop:with-temporary-file (:pathname p :keep t :type "jar") p)))
    (with-open-file (out path :direction :output :if-exists :supersede
                              :element-type '(unsigned-byte 8))
      (write-sequence (coerce octets '(vector (unsigned-byte 8))) out))
    path))

(defmacro with-temp-jar ((var octets) &body body)
  `(let ((,var (%temp-file ,octets)))
     (unwind-protect (progn ,@body)
       (uiop:delete-file-if-exists ,var))))

(defparameter +abc+ (map 'vector #'char-code "abc"))
(defparameter +abd+ (map 'vector #'char-code "abd"))

(deftest good-jar-verifies
  (with-temp-jar (p +abc+)
    (ok (equal p (verify-icu4j-jar p :expected +abc-sha256+)))
    (ok (equal p (verify-icu4j-jar p :expected (string-upcase +abc-sha256+)))
        "hex comparison ignores case")))

(deftest large-file-hash-streams
  ;; More than one 64 KiB read buffer.
  (let ((data (make-array 200000 :element-type '(unsigned-byte 8))))
    (dotimes (i (length data)) (setf (aref data i) (mod i 251)))
    (with-temp-jar (p data)
      (ok (string-equal
           (cl-stack-icu4j::%file-sha256-hex p)
           (string-downcase
            (encoding-protocol:encode (crypto-protocol:digest data :algorithm :sha256)
                                      :encoding :base16)))))))

(deftest tampered-jar-refused
  (with-temp-jar (p +abd+)
    (ok (signals (verify-icu4j-jar p :expected +abc-sha256+)
                 'icu4j-checksum-mismatch))
    (ok (signals (verify-icu4j-jar p :expected +abc-sha256+) 'icu4j-error)
        "mismatch is an icu4j-error")
    (let ((c (handler-case (verify-icu4j-jar p :expected +abc-sha256+)
               (icu4j-checksum-mismatch (c) c))))
      (ok (string= +abc-sha256+ (icu4j-checksum-mismatch-expected c)))
      (ok (string/= +abc-sha256+ (icu4j-checksum-mismatch-actual c)))
      (ok (equal p (icu4j-checksum-mismatch-path c))))))

(deftest pinned-digest-refuses-other-file
  ;; Default EXPECTED is the pinned ICU4J digest: any other file is refused.
  (with-temp-jar (p +abc+)
    (ok (signals (verify-icu4j-jar p) 'icu4j-checksum-mismatch))))

(deftest override-restart-is-explicit
  (with-temp-jar (p +abd+)
    (let ((restarts '()))
      (ok (equal p
                 (handler-bind ((icu4j-checksum-mismatch
                                  (lambda (c)
                                    (setf restarts (mapcar #'restart-name
                                                           (compute-restarts c)))
                                    (invoke-restart 'use-unverified-jar))))
                   (verify-icu4j-jar p :expected +abc-sha256+)))
          "USE-UNVERIFIED-JAR loads the jar anyway")
      (ok (member 'use-unverified-jar restarts)))
    ;; Without a handler nothing continues: no warning-and-proceed path.
    (ok (null (handler-case
                  (progn (verify-icu4j-jar p :expected +abc-sha256+) t)
                (icu4j-checksum-mismatch () nil))))))

(deftest real-jar-tamper
  ;; When the pinned jar is present (ABCL CI fetches it to lib/), it verifies,
  ;; and a copy with one extra byte is refused.
  (let ((lib (cl-stack-icu4j::%lib-jar-path)))
    (if (and lib (probe-file lib))
        (let ((octets (with-open-file (in lib :element-type '(unsigned-byte 8))
                        (let ((v (make-array (file-length in)
                                             :element-type '(unsigned-byte 8))))
                          (read-sequence v in)
                          v))))
          (ok (equal lib (verify-icu4j-jar lib)) "pinned jar verifies")
          (with-temp-jar (p (concatenate '(vector (unsigned-byte 8)) octets #(0)))
            (ok (signals (verify-icu4j-jar p) 'icu4j-checksum-mismatch)
                "tampered copy refused")))
        (skip "lib/icu4j jar not present"))))
