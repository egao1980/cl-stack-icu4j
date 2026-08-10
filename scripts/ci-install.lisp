;;;; Phase 1: install SUT dependency closure via cl-repository-client.

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&UNHANDLED: ~A~%" c)
        (uiop:quit 1)))

(setf asdf:*compile-file-failure-behaviour* :warn)

(asdf:load-system "cl-repository-client")
(cl-repo:add-registry "https://ghcr.io" :namespace "egao1980/cl-systems" :priority :prepend)
(cl-repo:ensure-system-dependencies "cl-stack-icu4j"
  :also-tests t
  :sources '(("rove" :ql)))
(format t "~&; ci: install phase done~%")
(uiop:quit 0)
