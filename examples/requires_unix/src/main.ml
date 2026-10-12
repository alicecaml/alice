let () =
  let text = "Hello, World!" in
  let _ = Unix.write_substring Unix.stdout text 0 (String.length text) in
  ()
;;
