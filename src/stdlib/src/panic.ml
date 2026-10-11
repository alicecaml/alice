let panic message =
  let backtrace = Printexc.get_callstack Stdlib.Int.max_int in
  Printf.eprintf "Panic: %s\n%s" message (Printexc.raw_backtrace_to_string backtrace);
  exit 1
;;
