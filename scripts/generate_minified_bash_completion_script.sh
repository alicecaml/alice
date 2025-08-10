#!/bin/sh
DUNE_CONFIG__PKG_BUILD_PROGRESS=disabled
dune exec --display=quiet alice -- internal completions bash \
    --program-name=alice \
    --program-exe-for-reentrant-query=alice \
    --global-symbol-prefix=__alice \
    --no-command-hash-in-function-names \
    --no-comments \
    --no-whitespace \
    --minify-global-names \
    --minify-local-variables \
    --optimize-case-statements
