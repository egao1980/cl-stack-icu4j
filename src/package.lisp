(defpackage #:cl-stack-icu4j
  (:use #:cl)
  (:export
   #:+icu4j-version+
   #:ensure-icu4j
   #:icu4j-version-string
   #:icu4j-error
   #:icu4j-error-message
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
   #:idna-name-to-ascii
   #:idna-name-to-unicode
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
   #:format-list
   #:format-relative-time
   #:locale-downcase
   #:locale-upcase
   #:locale-titlecase))

(in-package #:cl-stack-icu4j)

(defconstant +icu4j-version+ "78.1"
  "Pinned ICU4J Maven artifact version (aligns with cl-stack-icu ICU sources).")

(define-condition icu4j-error (error)
  ((message :initarg :message :reader icu4j-error-message))
  (:report (lambda (c s)
             (format s "cl-stack-icu4j: ~A" (icu4j-error-message c)))))
