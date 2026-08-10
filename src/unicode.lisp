(in-package #:cl-stack-icu4j)

#-abcl
(macrolet ((stub (&rest names)
             `(progn ,@(mapcar (lambda (n)
                                 `(defun ,n (&rest args)
                                    (declare (ignore args))
                                    (error 'icu4j-error :message "ABCL required")))
                               names))))
  (stub has-binary-property-p int-property char-name char-from-name
        numeric-value digit-value char-mirror char-age char-type
        property-value-name normalize normalized-p quick-check
        has-boundary-before-p has-boundary-after-p raw-decomposition
        fold-case to-lower to-upper to-title
        simple-fold-case simple-to-lower simple-to-upper
        idna-name-to-ascii idna-name-to-unicode
        make-break-iterator break-set-text break-first break-last
        break-next break-previous break-current break-following
        break-preceding break-is-boundary-p
        make-unicode-set uset-contains-p uset-span uset-span-back
        uset-size uset-empty-p uset-complement uset-add uset-remove
        uset-retain uset-clear uset-freeze))

#+abcl
(progn
  (defparameter *gc-short*
    #(:cn :lu :ll :lt :lm :lo :mn :me :mc :nd :nl :no
      :zs :zl :zp :cc :cf :co :cs :pd :ps :pe :pc :po
      :sm :sc :sk :so :pi :pf))

  (defun has-binary-property-p (code-point property)
    (%jstatic "hasBinaryProperty" "com.ibm.icu.lang.UCharacter"
              code-point (%uproperty property)))

  (defun char-type (code-point)
    (%jstatic "getType" "com.ibm.icu.lang.UCharacter" code-point))

  (defun int-property (code-point property)
    (let ((v (%jstatic "getIntPropertyValue" "com.ibm.icu.lang.UCharacter"
                       code-point (%uproperty property))))
      (case property
        (:general-category
         (if (and (<= 0 v) (< v (length *gc-short*)))
             (aref *gc-short* v)
             v))
        ((:script :block :bidi-class :east-asian-width)
         (or (let ((s (property-value-name property v)))
               (when (and s (plusp (length s)))
                 (intern (string-upcase (substitute #\- #\_ s :test #'char=)) :keyword)))
             v))
        (otherwise v))))

  (defun property-value-name (property value &key short)
    (let* ((name-choice (%jfield "com.ibm.icu.lang.UProperty$NameChoice"
                                 (if short "SHORT" "LONG")))
           (s (%jstatic "getPropertyValueName" "com.ibm.icu.lang.UCharacter"
                        (%uproperty property) value name-choice)))
      (when s (%jstr s))))

  (defun char-name (code-point &key (choice :unicode))
    (let ((s (ecase choice
               (:unicode (%jstatic "getName" "com.ibm.icu.lang.UCharacter" code-point))
               (:extended (%jstatic "getName" "com.ibm.icu.lang.UCharacter" code-point))
               (:alias (%jstatic "getNameAlias" "com.ibm.icu.lang.UCharacter" code-point)))))
      (when s (%jstr s))))

  (defun char-from-name (name)
    (let ((cp (%jstatic "getCharFromName" "com.ibm.icu.lang.UCharacter" (string name))))
      (unless (minusp cp) cp)))

  (defun numeric-value (code-point)
    (let ((v (%jstatic "getNumericValue" "com.ibm.icu.lang.UCharacter" code-point)))
      ;; ICU: -1 / -2 mean none; Java getNumericValue uses -1 for none for some cps
      (unless (minusp v) (float v 1d0))))

  (defun digit-value (code-point &key (radix 10))
    (let ((v (%jstatic "digit" "com.ibm.icu.lang.UCharacter" code-point radix)))
      (unless (minusp v) v)))

  (defun char-mirror (code-point)
    (%jstatic "getMirror" "com.ibm.icu.lang.UCharacter" code-point))

  (defun char-age (code-point)
    (let ((vi (%jstatic "getAge" "com.ibm.icu.lang.UCharacter" code-point)))
      (list (%jcall "getMajor" vi)
            (%jcall "getMinor" vi)
            (%jcall "getMilli" vi)
            (%jcall "getMicro" vi))))

  (defun %normalizer (form)
    (ecase form
      (:nfc (%jstatic "getNFCInstance" "com.ibm.icu.text.Normalizer2"))
      (:nfd (%jstatic "getNFDInstance" "com.ibm.icu.text.Normalizer2"))
      (:nfkc (%jstatic "getNFKCInstance" "com.ibm.icu.text.Normalizer2"))
      (:nfkd (%jstatic "getNFKDInstance" "com.ibm.icu.text.Normalizer2"))
      (:nfkc-casefold (%jstatic "getNFKCCasefoldInstance" "com.ibm.icu.text.Normalizer2"))))

  (defun normalize (string form)
    (%jstr (%jcall "normalize" (%normalizer form) (string string))))

  (defun normalized-p (string form)
    (%jcall "isNormalized" (%normalizer form) (string string)))

  (defun quick-check (string form)
    (let* ((r (%jcall "quickCheck" (%normalizer form) (string string)))
           (yes (%jfield "com.ibm.icu.text.Normalizer" "YES"))
           (no (%jfield "com.ibm.icu.text.Normalizer" "NO"))
           (maybe (%jfield "com.ibm.icu.text.Normalizer" "MAYBE")))
      (cond ((java:jcall "equals" r yes) :yes)
            ((java:jcall "equals" r no) :no)
            ((java:jcall "equals" r maybe) :maybe)
            (t :maybe))))

  (defun has-boundary-before-p (code-point form)
    (%jcall "hasBoundaryBefore" (%normalizer form) code-point))

  (defun has-boundary-after-p (code-point form)
    (%jcall "hasBoundaryAfter" (%normalizer form) code-point))

  (defun raw-decomposition (code-point form)
    (let ((s (%jcall "getDecomposition" (%normalizer form) code-point)))
      (when s (%jstr s))))

  (defun simple-fold-case (code-point)
    (%jstatic "foldCase" "com.ibm.icu.lang.UCharacter" code-point t))

  (defun simple-to-lower (code-point)
    (%jstatic "toLowerCase" "com.ibm.icu.lang.UCharacter" code-point))

  (defun simple-to-upper (code-point)
    (%jstatic "toUpperCase" "com.ibm.icu.lang.UCharacter" code-point))

  (defun fold-case (string)
    (%jstr (%jstatic "foldCase" "com.ibm.icu.lang.UCharacter" (string string) t)))

  (defun to-lower (string &key locale)
    (%jstr (if locale
               (%jstatic "toLowerCase" "com.ibm.icu.lang.UCharacter"
                         (%locale locale) (string string))
               (%jstatic "toLowerCase" "com.ibm.icu.lang.UCharacter" (string string)))))

  (defun to-upper (string &key locale)
    (%jstr (if locale
               (%jstatic "toUpperCase" "com.ibm.icu.lang.UCharacter"
                         (%locale locale) (string string))
               (%jstatic "toUpperCase" "com.ibm.icu.lang.UCharacter" (string string)))))

  (defun to-title (string &key locale)
    (let* ((cm (%jstatic "toTitle" "com.ibm.icu.text.CaseMap"))
           (loc (if locale (%locale locale) (%locale "en"))))
      ;; BreakIterator NIL → default title-casing iterator for locale.
      (%jstr (%jcall "apply" cm loc java:+null+ (string string)))))

  (defun %idna-options (options)
    (let ((opts (logior (%jfield "com.ibm.icu.text.IDNA" "DEFAULT")
                        (%jfield "com.ibm.icu.text.IDNA" "NONTRANSITIONAL_TO_ASCII")
                        (%jfield "com.ibm.icu.text.IDNA" "NONTRANSITIONAL_TO_UNICODE"))))
      (flet ((optp (k) (or (find k options :test #'eq) (getf options k))))
        (when (optp :std3)
          (setf opts (logior opts (%jfield "com.ibm.icu.text.IDNA" "USE_STD3_RULES"))))
        (when (optp :check-bidi)
          (setf opts (logior opts (%jfield "com.ibm.icu.text.IDNA" "CHECK_BIDI"))))
        (when (optp :check-contextj)
          (setf opts (logior opts (%jfield "com.ibm.icu.text.IDNA" "CHECK_CONTEXTJ"))))
        (when (optp :check-contexto)
          (setf opts (logior opts (%jfield "com.ibm.icu.text.IDNA" "CHECK_CONTEXTO"))))
        (when (optp :transitional)
          (setf opts (logandc2 opts
                               (logior (%jfield "com.ibm.icu.text.IDNA" "NONTRANSITIONAL_TO_ASCII")
                                       (%jfield "com.ibm.icu.text.IDNA" "NONTRANSITIONAL_TO_UNICODE"))))))
      opts))

  (defun %idna-convert (name options direction)
    (let* ((idna (%jstatic "getUTS46Instance" "com.ibm.icu.text.IDNA" (%idna-options options)))
           (sb (%jnew "java.lang.StringBuilder"))
           (info (%jnew "com.ibm.icu.text.IDNA$Info"))
           (fn (ecase direction (:ascii "nameToASCII") (:unicode "nameToUnicode"))))
      (%jcall fn idna (string name) sb info)
      (when (%jcall "hasErrors" info)
        (error 'icu4j-error
               :message (format nil "IDNA ~A failed for ~S" direction name)))
      (%jstr sb)))

  (defun idna-name-to-ascii (name &key options)
    (%idna-convert name options :ascii))

  (defun idna-name-to-unicode (name &key options)
    (%idna-convert name options :unicode))

  ;;; BreakIterator — returns the Java BreakIterator object as opaque raw.

  (defun make-break-iterator (kind &key locale)
    (let ((loc (%locale locale)))
      (ecase kind
        (:grapheme (%jstatic "getCharacterInstance" "com.ibm.icu.text.BreakIterator" loc))
        (:word (%jstatic "getWordInstance" "com.ibm.icu.text.BreakIterator" loc))
        (:line (%jstatic "getLineInstance" "com.ibm.icu.text.BreakIterator" loc))
        (:sentence (%jstatic "getSentenceInstance" "com.ibm.icu.text.BreakIterator" loc)))))

  (defun break-set-text (bi text)
    (%jcall "setText" bi (string text))
    bi)

  (defun break-first (bi) (%jcall "first" bi))
  (defun break-last (bi) (%jcall "last" bi))
  (defun break-current (bi) (%jcall "current" bi))

  (defun break-next (bi)
    (let ((n (%jcall "next" bi)))
      (if (= n (%jfield "com.ibm.icu.text.BreakIterator" "DONE")) nil n)))

  (defun break-previous (bi)
    (let ((n (%jcall "previous" bi)))
      (if (= n (%jfield "com.ibm.icu.text.BreakIterator" "DONE")) nil n)))

  (defun break-following (bi offset)
    (let ((n (%jcall "following" bi offset)))
      (if (= n (%jfield "com.ibm.icu.text.BreakIterator" "DONE")) nil n)))

  (defun break-preceding (bi offset)
    (let ((n (%jcall "preceding" bi offset)))
      (if (= n (%jfield "com.ibm.icu.text.BreakIterator" "DONE")) nil n)))

  (defun break-is-boundary-p (bi offset)
    (%jcall "isBoundary" bi offset))

  ;;; UnicodeSet

  (defun make-unicode-set (&key pattern freeze)
    (let ((set (if pattern
                   (%jnew "com.ibm.icu.text.UnicodeSet" (string pattern))
                   (%jnew "com.ibm.icu.text.UnicodeSet"))))
      (when freeze (%jcall "freeze" set))
      set))

  (defun uset-contains-p (set object)
    (if (integerp object)
        (%jcall "contains" set object)
        (%jcall "contains" set (string object))))

  (defun %span-condition (contained)
    (%jfield "com.ibm.icu.text.UnicodeSet$SpanCondition"
             (if contained "CONTAINED" "NOT_CONTAINED")))

  (defun uset-span (set string &key contained)
    (%jcall "span" set (string string) (%span-condition contained)))

  (defun uset-span-back (set string &key contained)
    (%jcall "spanBack" set (string string) (%span-condition contained)))

  (defun uset-size (set) (%jcall "size" set))
  (defun uset-empty-p (set) (%jcall "isEmpty" set))

  (defun uset-complement (set)
    (%jcall "complement" set)
    set)

  (defun uset-add (set object)
    (if (integerp object)
        (%jcall "add" set object)
        (%jcall "add" set (string object)))
    set)

  (defun uset-remove (set object)
    (if (integerp object)
        (%jcall "remove" set object)
        (%jcall "remove" set (string object)))
    set)

  (defun uset-retain (set other)
    (%jcall "retainAll" set other)
    set)

  (defun uset-clear (set)
    (%jcall "clear" set)
    set)

  (defun uset-freeze (set)
    (%jcall "freeze" set)
    set)
) ; progn #+abcl
