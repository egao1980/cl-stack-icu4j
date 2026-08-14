(in-package #:cl-stack-icu4j/tests)

(defun %s (&rest cps)
  (map 'string #'code-char cps))

#-abcl
(deftest smoke-skip
  (ok t "non-ABCL: skip"))

#+abcl
(progn
  (deftest bootstrap
    (ok (ensure-icu4j))
    (ok (search "78." (icu4j-version-string))))

  ;;; --- unicode --------------------------------------------------------------

  (deftest uchar-properties
    (ok (has-binary-property-p 32 :white-space))
    (ok (has-binary-property-p (char-code #\A) :alphabetic))
    (ok (not (has-binary-property-p (char-code #\1) :alphabetic)))
    (ok (eq :lu (int-property (char-code #\A) :general-category)))
    (ok (eq :ll (int-property (char-code #\a) :general-category)))
    (ok (eq :nd (int-property (char-code #\1) :general-category)))
    (ok (eq :latin (int-property (char-code #\A) :script)))
    (ok (string= "LATIN CAPITAL LETTER A" (char-name (char-code #\A))))
    (ok (= (char-code #\A) (char-from-name "LATIN CAPITAL LETTER A")))
    (ok (null (char-from-name "NOT A REAL UNICODE NAME XYZ")))
    (ok (= (numeric-value (char-code #\5)) 5d0))
    (ok (= (numeric-value #x00BD) 0.5d0))
    (ok (= (digit-value (char-code #\A) :radix 16) 10))
    (ok (null (digit-value (char-code #\A) :radix 10)))
    (ok (= (char-mirror (char-code #\()) (char-code #\))))
    (ok (equal (char-age (char-code #\A)) '(1 1 0 0)))
    (ok (has-binary-property-p #x1F600 :emoji))
    (ok (has-binary-property-p #x1F600 :extended-pictographic)))

  (deftest normalize-forms
    (ok (string= (normalize (%s #x65 #x301) :nfc) (string (code-char #x00E9))))
    (ok (string= (normalize (string (code-char #x00E9)) :nfd) (%s #x65 #x301)))
    (ok (string= (normalize (string (code-char #xFB01)) :nfkc) "fi"))
    (ok (string= (normalize "ß" :nfkc-casefold) "ss"))
    (ok (normalized-p (string (code-char #x00E9)) :nfc))
    (ok (eq (quick-check "a" :nfc) :yes))
    (let ((d (raw-decomposition #x00E9 :nfd)))
      (ok (stringp d))
      (ok (= (length d) 2))
      (ok (find #\e d))))

  (deftest case-mapping
    (ok (= (simple-to-lower (char-code #\A)) (char-code #\a)))
    (ok (= (simple-to-upper (char-code #\a)) (char-code #\A)))
    (ok (string= (fold-case "Straße") "strasse"))
    (ok (string= (to-lower "AbC") "abc"))
    (ok (string= (to-upper "AbC") "ABC"))
    (ok (string= (to-title "hello world") "Hello World"))
    (ok (string= (locale-upcase "i" :locale "tr") "İ"))
    (ok (string= (locale-downcase "I" :locale "tr") "ı")))

  (deftest idna-uts46
    (ok (string= (idna-name-to-ascii "bücher.de") "xn--bcher-kva.de"))
    (ok (string= (idna-name-to-unicode "xn--bcher-kva.de") "bücher.de"))
    (ok (string= (idna-name-to-ascii "example.com") "example.com"))
    (ok (search "xn--" (idna-name-to-ascii "日本語.jp"))))

  (deftest break-iterator
    (let ((bi (make-break-iterator :grapheme)))
      (break-set-text bi "ab")
      (ok (= 0 (break-first bi)))
      (ok (= 1 (break-next bi)))
      (ok (break-is-boundary-p bi 0))
      (ok (= 2 (break-following bi 1)))
      (ok (= 1 (break-preceding bi 2)))
      (ok (= 2 (break-last bi))))
    (let ((bi (make-break-iterator :word :locale "en"))
          (text "Hello, world"))
      (break-set-text bi text)
      (ok (= 0 (break-first bi)))
      (ok (= (length text) (break-last bi)))))

  (deftest unicode-set
    (let ((s (make-unicode-set :pattern "[:Letter:]")))
      (ok (uset-contains-p s (char-code #\A)))
      (ok (not (uset-contains-p s (char-code #\0))))
      (ok (plusp (uset-size s))))
    (let ((s (make-unicode-set)))
      (ok (uset-empty-p s))
      (uset-add s (char-code #\A))
      (ok (uset-contains-p s (char-code #\A)))
      (uset-add s "fi")
      (ok (uset-contains-p s "fi"))
      (uset-remove s (char-code #\A))
      (ok (not (uset-contains-p s (char-code #\A))))
      (uset-clear s)
      (ok (uset-empty-p s)))
    (let ((s (make-unicode-set :pattern "[:Digit:]")))
      (ok (= (uset-span s "123abc") 3))
      (ok (zerop (uset-span s "abc123")))))

  ;;; --- i18n -----------------------------------------------------------------

  (deftest locale-and-plural
    (multiple-value-bind (lang script region tag)
        (parse-locale-tag "zh-Hans-CN")
      (declare (ignore script tag))
      (ok (string-equal lang "zh"))
      (ok (string-equal region "CN")))
    (ok (plusp (length (available-locale-tags))))
    (ok (eq :one (plural-select "en" 1)))
    (ok (eq :other (plural-select "en" 2)))
    (ok (eq :few (plural-select "ru" 2)))
    (ok (eq :many (plural-select "ru" 5))))

  (deftest mf2-and-catalog
    (ok (string= "Hello World!"
                 (mf2-format-message "Hello {$name}!" '(("name" . "World")) :locale "en")))
    (ok (search "42" (mf2-format-message "n={$n}" '(("n" . 42)) :locale "en")))
    (let ((cat (open-catalog :locale "en")))
      (ok (catalog-has-p cat "Version"))
      (ok (stringp (catalog-get cat "Version")))
      (ok (stringp (catalog-locale-tag cat)))
      (ok (null (catalog-get cat "DefinitelyMissingKeyXYZ" :default nil)))))

  ;;; --- l10n -----------------------------------------------------------------

  (deftest collate-and-sort-key
    (ok (minusp (collate (make-collator :locale "en") "a" "b")))
    (ok (zerop (collate (make-collator :locale "en" :strength :primary) "a" "A")))
    (let ((c (make-collator :locale "en")))
      (ok (vectorp (sort-key c "apple")))
      (ok (not (equalp (sort-key c "apple") (sort-key c "banana"))))))

  (deftest number-date-list
    (ok (plusp (length (format-number 1234.5d0 :locale "en-US"))))
    (ok (or (search "%" (format-percent 0.25d0 :locale "en-US"))
            (search "25" (format-percent 0.25d0 :locale "en-US"))))
    (ok (or (search "$" (format-currency 12.5d0 "USD" :locale "en-US"))
            (search "12" (format-currency 12.5d0 "USD" :locale "en-US"))))
    (ok (= (parse-number "1,234.5" :locale "en-US") 1234.5d0))
    (ok (plusp (length (format-date 0 :locale "en-US" :style :short))))
    (let ((s (format-relative-time -1 :day :locale "en" :numeric t)))
      (ok (plusp (length s))))
    (let ((and-s (format-list '("a" "b" "c") :locale "en" :type :and))
          (or-s (format-list '("a" "b") :locale "en" :type :or)))
      (ok (search "a" and-s))
      (ok (search "c" and-s))
      (ok (search "a" or-s))))
) ; progn #+abcl
