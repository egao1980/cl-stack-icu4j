(in-package #:cl-stack-icu4j)

#-abcl
(macrolet ((stub (&rest names)
             `(progn ,@(mapcar (lambda (n)
                                 `(defun ,n (&rest args)
                                    (declare (ignore args))
                                    (error 'icu4j-error :message "ABCL required")))
                               names))))
  (stub parse-locale-tag locale-language locale-script locale-region locale-tag
        available-locale-tags mf2-format-message plural-select
        open-catalog catalog-get catalog-has-p catalog-locale-tag))

#+abcl
(progn
  (defun parse-locale-tag (tag)
    "Return (values language script region bcp47-tag) from a language tag."
    (let ((loc (%jstatic "forLanguageTag" "com.ibm.icu.util.ULocale" (string tag))))
      (values (let ((s (%jstr (%jcall "getLanguage" loc)))) (if (plusp (length s)) s nil))
              (let ((s (%jstr (%jcall "getScript" loc)))) (if (plusp (length s)) s nil))
              (let ((s (%jstr (%jcall "getCountry" loc)))) (if (plusp (length s)) s nil))
              (%jstr (%jcall "toLanguageTag" loc)))))

  (defun locale-language (uloc) (%jstr (%jcall "getLanguage" uloc)))
  (defun locale-script (uloc) (%jstr (%jcall "getScript" uloc)))
  (defun locale-region (uloc) (%jstr (%jcall "getCountry" uloc)))
  (defun locale-tag (uloc) (%jstr (%jcall "toLanguageTag" uloc)))

  (defun available-locale-tags ()
    "Return BCP 47 tags for ICU4J available ULocales.
ABCL may return a Lisp vector of Java objects rather than a Java array."
    (let ((arr (%jstatic "getAvailableLocales" "com.ibm.icu.util.ULocale")))
      (flet ((ref (i)
               (cond ((typep arr 'sequence) (elt arr i))
                     (t (java:jarray-ref arr i))))
             (len ()
               (cond ((typep arr 'sequence) (length arr))
                     (t (java:jarray-length arr)))))
        (loop for i below (len)
              collect (%jstr (%jcall "toLanguageTag" (ref i)))))))

  (defun %args→jmap (arguments)
    (let ((m (%jnew "java.util.HashMap")))
      (labels ((put (k v)
                 (%jcall "put" m
                         (if (stringp k) k (string-downcase (string k)))
                         (cond
                           ((stringp v) v)
                           ((integerp v) (%jnew "java.lang.Long" v))
                           ((floatp v) (%jnew "java.lang.Double" (float v 1d0)))
                           (t (princ-to-string v))))))
        (cond
          ((null arguments))
          ((hash-table-p arguments)
           (maphash #'put arguments))
          ((listp arguments)
           (dolist (pair arguments)
             (put (car pair) (cdr pair))))
          (t (error 'icu4j-error :message "MF2 arguments must be alist or hash-table"))))
      m))

  (defun mf2-format-message (pattern args &key (locale "en"))
    (let* ((b (%jstatic "builder" "com.ibm.icu.message2.MessageFormatter"))
           (b (%jcall "setPattern" b (string pattern)))
           (b (%jcall "setLocale" b (%locale locale)))
           (fmt (%jcall "build" b)))
      (%jstr (%jcall "formatToString" fmt (%args→jmap args)))))

  (defun plural-select (locale number &key (type :cardinal))
    (let* ((ptype (%jfield "com.ibm.icu.text.PluralRules$PluralType"
                           (ecase (or type :cardinal)
                             (:cardinal "CARDINAL")
                             (:ordinal "ORDINAL"))))
           (rules (%jstatic "forLocale" "com.ibm.icu.text.PluralRules"
                            (%ulocale locale) ptype))
           (s (%jstr (%jcall "select" rules (float number 1d0)))))
      (cond ((string= s "zero") :zero)
            ((string= s "one") :one)
            ((string= s "two") :two)
            ((string= s "few") :few)
            ((string= s "many") :many)
            (t :other))))

  (defun open-catalog (&key package locale)
    "Open UResourceBundle. PACKAGE NIL → ICU data; string → base name."
    (let ((loc (%ulocale locale)))
      (if package
          (%jstatic "getBundleInstance" "com.ibm.icu.util.UResourceBundle"
                    (string package) loc)
          (%jstatic "getBundleInstance" "com.ibm.icu.util.UResourceBundle" loc))))

  (defun %catalog-get-node (bundle key)
    (let ((parts (remove "" (uiop:split-string (string key) :separator "/")
                         :test #'string=))
          (cur bundle))
      (dolist (part parts cur)
        (handler-case
            (setf cur (%jcall "get" cur part))
          (error ()
            (return-from %catalog-get-node nil))))))

  (defun catalog-get (bundle key &key default)
    (let ((node (%catalog-get-node bundle key)))
      (if node
          (handler-case (%jstr (%jcall "getString" node))
            (error () default))
          default)))

  (defun catalog-has-p (bundle key)
    (not (null (%catalog-get-node bundle key))))

  (defun catalog-locale-tag (bundle)
    (%jstr (%jcall "toLanguageTag" (%jcall "getULocale" bundle))))
) ; progn #+abcl
