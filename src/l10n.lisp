(in-package #:cl-stack-icu4j)

#-abcl
(macrolet ((stub (&rest names)
             `(progn ,@(mapcar (lambda (n)
                                 `(defun ,n (&rest args)
                                    (declare (ignore args))
                                    (error 'icu4j-error :message "ABCL required")))
                               names))))
  (stub make-collator collate sort-key
        format-number format-percent format-currency
        format-date format-time format-datetime parse-number parse-date
        format-list format-relative-time
        locale-downcase locale-upcase locale-titlecase))

#+abcl
(progn
  (defun make-collator (&key locale strength)
    (let ((c (%jstatic "getInstance" "com.ibm.icu.text.Collator" (%locale locale))))
      (when strength
        (%jcall "setStrength" c
                (%jfield "com.ibm.icu.text.Collator"
                         (ecase strength
                           (:primary "PRIMARY")
                           (:secondary "SECONDARY")
                           (:tertiary "TERTIARY")
                           (:quaternary "QUATERNARY")
                           (:identical "IDENTICAL")))))
      c))

  (defun collate (collator string-a string-b)
    (%jcall "compare" collator (string string-a) (string string-b)))

  (defun sort-key (collator string)
    (let* ((ck (%jcall "getCollationKey" collator (string string)))
           (bytes (%jcall "toByteArray" ck))
           (n (java:jarray-length bytes))
           (out (make-array n :element-type '(unsigned-byte 8))))
      (dotimes (i n out)
        (setf (aref out i) (logand (java:jarray-ref bytes i) #xff)))))

  (defun %number-style (style)
    (%jfield "com.ibm.icu.text.NumberFormat"
             (ecase (or style :decimal)
               (:decimal "NUMBERSTYLE")
               (:percent "PERCENTSTYLE")
               (:scientific "SCIENTIFICSTYLE")
               (:currency "CURRENCYSTYLE")
               (:currency-iso "ISOCURRENCYSTYLE")
               (:currency-plural "PLURALCURRENCYSTYLE")
               (:currency-accounting "ACCOUNTINGCURRENCYSTYLE")
               (:cash-currency "CASHCURRENCYSTYLE")
               (:currency-standard "STANDARDCURRENCYSTYLE")
               (:default "NUMBERSTYLE"))))

  (defun format-number (value &key locale style)
    (let ((fmt (%jstatic "getInstance" "com.ibm.icu.text.NumberFormat"
                         (%locale locale) (%number-style (or style :decimal)))))
      (%jstr (%jcall "format" fmt (float value 1d0)))))

  (defun format-percent (value &key locale)
    (let ((fmt (%jstatic "getPercentInstance" "com.ibm.icu.text.NumberFormat"
                         (%locale locale))))
      (%jstr (%jcall "format" fmt (float value 1d0)))))

  (defun format-currency (value currency &key locale)
    (let* ((fmt (%jstatic "getCurrencyInstance" "com.ibm.icu.text.NumberFormat"
                          (%locale locale)))
           (cur (%jstatic "getInstance" "com.ibm.icu.util.Currency" (string currency))))
      (%jcall "setCurrency" fmt cur)
      (%jstr (%jcall "format" fmt (float value 1d0)))))

  (defun parse-number (string &key locale style)
    (let* ((fmt (%jstatic "getInstance" "com.ibm.icu.text.NumberFormat"
                          (%locale locale) (%number-style (or style :decimal))))
           (n (%jcall "parse" fmt (string string))))
      (float (%jcall "doubleValue" n) 1d0)))

  (defun %date-style (style)
    (%jfield "com.ibm.icu.text.DateFormat"
             (ecase (or style :short)
               (:full "FULL")
               (:long "LONG")
               (:medium "MEDIUM")
               (:short "SHORT")
               (:default "DEFAULT")
               (:none "NONE"))))

  (defun %udate-ms (value)
    (cond ((numberp value)
           (if (> (abs value) 1d12)
               (float value 1d0)
               (* (float value 1d0) 1000d0)))
          (t 0d0)))

  (defun format-date (value &key locale style)
    (let* ((fmt (%jstatic "getDateInstance" "com.ibm.icu.text.DateFormat"
                          (%date-style style) (%locale locale)))
           (d (%jnew "java.util.Date" (round (%udate-ms value)))))
      (%jstr (%jcall "format" fmt d))))

  (defun format-time (value &key locale style)
    (let* ((fmt (%jstatic "getTimeInstance" "com.ibm.icu.text.DateFormat"
                          (%date-style (or style :short)) (%locale locale)))
           (d (%jnew "java.util.Date" (round (%udate-ms value)))))
      (%jstr (%jcall "format" fmt d))))

  (defun format-datetime (value &key locale date-style time-style)
    (let* ((fmt (%jstatic "getDateTimeInstance" "com.ibm.icu.text.DateFormat"
                          (%date-style (or date-style :short))
                          (%date-style (or time-style :short))
                          (%locale locale)))
           (d (%jnew "java.util.Date" (round (%udate-ms value)))))
      (%jstr (%jcall "format" fmt d))))

  (defun parse-date (string &key locale style)
    "Parse STRING → universal-time seconds (float). STYLE defaults :short."
    (let* ((fmt (%jstatic "getDateInstance" "com.ibm.icu.text.DateFormat"
                          (%date-style (or style :short)) (%locale locale)))
           (d (%jcall "parse" fmt (string string))))
      (/ (float (%jcall "getTime" d) 1d0) 1000d0)))

  (defun format-list (items &key locale (type :and) (width :wide))
    (let* ((jtype (%jfield "com.ibm.icu.text.ListFormatter$Type"
                           (ecase (or type :and)
                             (:and "AND")
                             (:or "OR")
                             ((:unit :units) "UNITS"))))
           (jwidth (%jfield "com.ibm.icu.text.ListFormatter$Width"
                            (ecase (or width :wide)
                              (:wide "WIDE")
                              (:short "SHORT")
                              (:narrow "NARROW"))))
           (fmt (%jstatic "getInstance" "com.ibm.icu.text.ListFormatter"
                          (%locale locale) jtype jwidth))
           (al (%jnew "java.util.ArrayList")))
      (dolist (it items)
        (%jcall "add" al (string it)))
      (%jstr (%jcall "format" fmt al))))

  (defun format-relative-time (value unit &key locale numeric (style :long))
    "VALUE is signed offset; UNIT ∈ :second :minute :hour :day :week :month :year.
STYLE ∈ :long :short :narrow."
    (let* ((jstyle (%jfield "com.ibm.icu.text.RelativeDateTimeFormatter$Style"
                            (ecase (or style :long)
                              (:long "LONG")
                              (:short "SHORT")
                              (:narrow "NARROW"))))
           (fmt (%jstatic "getInstance" "com.ibm.icu.text.RelativeDateTimeFormatter"
                          (%ulocale locale)
                          java:+null+
                          jstyle
                          (%jfield "com.ibm.icu.text.DisplayContext"
                                   "CAPITALIZATION_NONE")))
           (u (%jfield "com.ibm.icu.text.RelativeDateTimeFormatter$RelativeDateTimeUnit"
                       (ecase unit
                         (:second "SECOND")
                         (:minute "MINUTE")
                         (:hour "HOUR")
                         (:day "DAY")
                         (:week "WEEK")
                         (:month "MONTH")
                         (:year "YEAR")
                         (:quarter "QUARTER")))))
      (%jstr (if numeric
                 (%jcall "formatNumeric" fmt (float value 1d0) u)
                 (%jcall "format" fmt (float value 1d0) u)))))

  (defun locale-downcase (string &key locale)
    (to-lower string :locale locale))

  (defun locale-upcase (string &key locale)
    (to-upper string :locale locale))

  (defun locale-titlecase (string &key locale)
    (to-title string :locale locale))
) ; progn #+abcl
