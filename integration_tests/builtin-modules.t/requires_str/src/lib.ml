let first_word x =
  let r = Str.regexp {|\([A-Za-z]+\).*|} in
  Str.replace_first r {|\1|} "hello world"
;;
