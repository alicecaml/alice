(* Expected to create a directory named "hello" *)

let () = Requires_unix.mkdir (Requires_str.first_word "hello world")
