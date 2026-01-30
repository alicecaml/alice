#!/bin/sh
_build/default/alice/src/alice.exe internal completions bash \
    --program-name=alice \
    --program-exe-for-reentrant-query=alice \
    --global-symbol-prefix=__alice \
    --no-command-hash-in-function-names \
    --no-comments \
    --no-whitespace \
    --minify-global-names \
    --minify-local-variables \
    --optimize-case-statements
