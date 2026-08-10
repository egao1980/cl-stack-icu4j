# cl-stack-icu4j

**ICU4J 78.1** on **ABCL** — classpath bootstrap + Lisp API for unicode / i18n / l10n backends.

| Piece | Role |
|-------|------|
| `ensure-icu4j` | Resolve jar (`CL_STACK_ICU4J_JAR` → `lib/icu4j-78.1.jar` → XDG cache download) + `java:add-to-classpath` |
| Lisp API | Thin wrappers over `com.ibm.icu.*` (UCharacter, Normalizer2, IDNA, BreakIterator, UnicodeSet, MF2, PluralRules, Collator, formats) |

Consumers: `unicode-backend-icu4j`, `i18n-backend-icu4j`, `l10n-backend-icu4j`.

```lisp
(asdf:load-system :cl-stack-icu4j) ; auto-loads jar on ABCL
(cl-stack-icu4j:normalize "é" :nfc)
(cl-stack-icu4j:mf2-format-message "Hi {$name}!" '(("name" . "Ada")))
```

Non-ABCL loads stubs that error if called.
