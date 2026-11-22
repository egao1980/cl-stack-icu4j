# cl-stack-icu4j

**ICU4J 79.1** on **ABCL** — classpath bootstrap + Lisp API for unicode / i18n / l10n backends.

| Piece | Role |
|-------|------|
| `ensure-icu4j` | Resolve jar (`CL_STACK_ICU4J_JAR` → `lib/icu4j-79.1.jar` → XDG cache download) + `java:add-to-classpath` |
| Lisp API | Thin wrappers over `com.ibm.icu.*` (UCharacter, Normalizer2, IDNA, BreakIterator, UnicodeSet, MF2, PluralRules, Collator, formats) |

Consumers: `unicode-backend-icu4j`, `i18n-backend-icu4j`, `l10n-backend-icu4j`.

```lisp
(asdf:load-system :cl-stack-icu4j) ; auto-loads jar on ABCL
(cl-stack-icu4j:normalize "é" :nfc)
(cl-stack-icu4j:mf2-format-message "Hi {$name}!" '(("name" . "Ada")))
```

Non-ABCL loads stubs that error if called.

## Jar verification

Every resolved jar (`CL_STACK_ICU4J_JAR`, `lib/`, cache, fresh download) is hashed with SHA-256 through `crypto-protocol` (`crypto-backend-ironclad`) and compared with the pinned digest before it reaches the classpath. A download is written to a temporary file and only renamed into the cache after it verifies.

A mismatch signals `icu4j-checksum-mismatch` (an `icu4j-error`). Nothing continues past it unless a handler invokes the restart `use-unverified-jar`, the one explicit override for a jar you trust anyway:

```lisp
(handler-bind ((cl-stack-icu4j:icu4j-checksum-mismatch
                 (lambda (c) (declare (ignore c))
                   (invoke-restart (quote cl-stack-icu4j:use-unverified-jar)))))
  (cl-stack-icu4j:ensure-icu4j))
```

`(verify-icu4j-jar path &key expected)` runs the same check on any file.
