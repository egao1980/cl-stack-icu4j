(defsystem "cl-stack-icu4j"
  :version "78.1"
  :description "ICU4J (78.1) Java interop for ABCL — classpath bootstrap + Lisp API"
  :author "egao1980"
  :license "MIT"
  :depends-on ("uiop")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "classpath")
               (:file "java")
               (:file "unicode")
               (:file "i18n")
               (:file "l10n"))
  :in-order-to ((test-op (test-op "cl-stack-icu4j/tests")))
  :properties
  (:cl-repo (:provides ("cl-stack-icu4j"))))

(defsystem "cl-stack-icu4j/tests"
  :depends-on ("cl-stack-icu4j" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "smoke-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
