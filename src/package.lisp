(defpackage #:cl-stack-icu4j
  (:use #:cl)
  ;; Our CHAR-NAME takes a code point (ICU UCharacter.getName); do not redefine CL:CHAR-NAME.
  (:shadow #:char-name)
  (:export
   #:+icu4j-version+
   #:ensure-icu4j
   #:icu4j-version-string
   #:icu4j-error
   #:icu4j-error-message
   #:icu4j-checksum-mismatch
   #:icu4j-checksum-mismatch-path
   #:icu4j-checksum-mismatch-expected
   #:icu4j-checksum-mismatch-actual
   #:use-unverified-jar
   #:verify-icu4j-jar
   ;; unicode
   #:has-binary-property-p
   #:int-property
   #:char-name
   #:char-from-name
   #:numeric-value
   #:digit-value
   #:char-mirror
   #:char-age
   #:char-type
   #:property-value-name
   #:normalize
   #:normalized-p
   #:quick-check
   #:has-boundary-before-p
   #:has-boundary-after-p
   #:raw-decomposition
   #:fold-case
   #:to-lower
   #:to-upper
   #:to-title
   #:simple-fold-case
   #:simple-to-lower
   #:simple-to-upper
   #:simple-to-title
   #:script-extensions
   #:idna-name-to-ascii
   #:idna-name-to-unicode
   #:idna-label-to-ascii
   #:idna-label-to-unicode
   #:make-break-iterator
   #:break-set-text
   #:break-first
   #:break-last
   #:break-next
   #:break-previous
   #:break-current
   #:break-following
   #:break-preceding
   #:break-is-boundary-p
   #:make-unicode-set
   #:uset-contains-p
   #:uset-span
   #:uset-span-back
   #:uset-size
   #:uset-empty-p
   #:uset-complement
   #:uset-add
   #:uset-remove
   #:uset-retain
   #:uset-clear
   #:uset-freeze
   ;; i18n
   #:parse-locale-tag
   #:locale-language
   #:locale-script
   #:locale-region
   #:locale-tag
   #:available-locale-tags
   #:mf2-format-message
   #:plural-select
   #:open-catalog
   #:catalog-get
   #:catalog-has-p
   #:catalog-locale-tag
   ;; l10n
   #:make-collator
   #:collate
   #:sort-key
   #:format-number
   #:format-percent
   #:format-currency
   #:format-date
   #:format-time
   #:format-datetime
   #:parse-number
   #:parse-date
   #:format-list
   #:format-relative-time
   #:locale-downcase
   #:locale-upcase
   #:locale-titlecase))

(in-package #:cl-stack-icu4j)

(defconstant +icu4j-version+
  ;; A string constant: reuse the old value so compile-then-load is EQL (SBCL).
  (if (boundp (quote +icu4j-version+)) (symbol-value (quote +icu4j-version+)) "79.1")
  "Pinned ICU4J Maven artifact version (aligns with cl-stack-icu ICU sources).")

(define-condition icu4j-error (error)
  ((message :initarg :message :reader icu4j-error-message))
  (:report (lambda (c s)
             (format s "cl-stack-icu4j: ~A" (icu4j-error-message c)))))

(define-condition icu4j-checksum-mismatch (icu4j-error)
  ((path :initarg :path :reader icu4j-checksum-mismatch-path)
   (expected :initarg :expected :reader icu4j-checksum-mismatch-expected)
   (actual :initarg :actual :reader icu4j-checksum-mismatch-actual))
  (:documentation
   "Signalled when an ICU4J jar's SHA-256 differs from the pinned digest.
The jar is never put on the classpath unless a handler invokes the
USE-UNVERIFIED-JAR restart, which is the only way to load it anyway.")
  (:report (lambda (c s)
             (format s "cl-stack-icu4j: SHA-256 mismatch for ~A (expected ~A, got ~A)"
                     (icu4j-checksum-mismatch-path c)
                     (icu4j-checksum-mismatch-expected c)
                     (icu4j-checksum-mismatch-actual c)))))
