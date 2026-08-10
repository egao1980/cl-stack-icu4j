(in-package #:cl-stack-icu4j)

#-abcl
(progn
  (defun %jcall (method obj &rest args)
    (declare (ignore method obj args))
    (error 'icu4j-error :message "ABCL required"))
  (defun %jstatic (method class &rest args)
    (declare (ignore method class args))
    (error 'icu4j-error :message "ABCL required"))
  (defun %jfield (class name)
    (declare (ignore class name))
    (error 'icu4j-error :message "ABCL required"))
  (defun %jnew (class &rest args)
    (declare (ignore class args))
    (error 'icu4j-error :message "ABCL required"))
  (defun %jstr (obj)
    (declare (ignore obj))
    "")
  (defun icu4j-version-string () "unavailable"))

#+abcl
(progn
  (defun %jcall (method obj &rest args)
    (apply #'java:jcall method obj args))

  (defun %jstatic (method class &rest args)
    (apply #'java:jstatic method class args))

  (defun %jfield (class name)
    (java:jfield class name))

  (defun %jnew (class &rest args)
    (apply #'java:jnew class args))

  (defun %jstr (obj)
    (if (null obj)
        nil
        (java:jcall "toString" obj)))

  (defun %locale (tag)
    "BCP 47 / ICU locale tag → java.util.Locale."
    (%jstatic "forLanguageTag" "java.util.Locale"
              (if (and tag (plusp (length (string tag))))
                  (string tag)
                  "en")))

  (defun %ulocale (tag)
    (%jstatic "forLanguageTag" "com.ibm.icu.util.ULocale"
              (if (and tag (plusp (length (string tag))))
                  (string tag)
                  "en")))

  (defun %uproperty (property)
    "Protocol/Lisp keyword → UProperty int field."
    (let ((name
            (ecase property
              (:white-space "WHITE_SPACE")
              (:general-category "GENERAL_CATEGORY")
              (:bidi-class "BIDI_CLASS")
              (:canonical-combining-class "CANONICAL_COMBINING_CLASS")
              (:block "BLOCK")
              (:script "SCRIPT")
              (:east-asian-width "EAST_ASIAN_WIDTH")
              (:alphabetic "ALPHABETIC")
              (:lowercase "LOWERCASE")
              (:uppercase "UPPERCASE")
              (:emoji "EMOJI")
              (:emoji-presentation "EMOJI_PRESENTATION")
              (:extended-pictographic "EXTENDED_PICTOGRAPHIC"))))
      (%jfield "com.ibm.icu.lang.UProperty" name)))

  (defun icu4j-version-string ()
    (%jstr (%jfield "com.ibm.icu.util.VersionInfo" "ICU_VERSION")))
) ; progn #+abcl
