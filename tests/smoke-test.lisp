(in-package #:cl-stack-icu4j/tests)

#+abcl
(deftest smoke
  (ok (ensure-icu4j))
  (ok (search "78." (icu4j-version-string)))
  (ok (has-binary-property-p 32 :white-space))
  (ok (eq :lu (int-property (char-code #\A) :general-category)))
  (ok (string= "LATIN CAPITAL LETTER A" (char-name (char-code #\A))))
  (ok (= (char-code #\A) (char-from-name "LATIN CAPITAL LETTER A")))
  (ok (string= "é" (normalize (concatenate 'string "e" (string (code-char #x0301))) :nfc)))
  (ok (string= "xn--mnchen-3ya.de" (idna-name-to-ascii "münchen.de")))
  (let ((bi (make-break-iterator :word :locale "en")))
    (break-set-text bi "one two")
    (ok (= 0 (break-first bi)))
    (ok (integerp (break-next bi))))
  (let ((set (make-unicode-set :pattern "[a-z]")))
    (ok (uset-contains-p set (char-code #\a)))
    (ng (uset-contains-p set (char-code #\A))))
  (ok (string= "Hello World!"
               (mf2-format-message "Hello {$name}!" '(("name" . "World")) :locale "en")))
  (ok (eq :one (plural-select "en" 1)))
  (ok (eq :other (plural-select "en" 2)))
  (ok (minusp (collate (make-collator :locale "en") "a" "b")))
  (ok (plusp (length (format-number 1234.5d0 :locale "en-US"))))
  (ok (plusp (length (format-currency 10 "USD" :locale "en-US"))))
  (ok (plusp (length (format-list '("a" "b" "c") :locale "en"))))
  (ok (string= "İ" (locale-upcase "i" :locale "tr"))))

#-abcl
(deftest smoke-skip
  (ok t "non-ABCL: skip"))
