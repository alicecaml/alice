open! Alice_stdlib

let tag_error = Ansi_style.create ~color:`Red ~bold:true ()

let panic pps =
  Alice_print.Raw.pps_eprint (Pp.newline :: Pp.tag tag_error (Pp.text "Panic: ") :: pps);
  let backtrace = Printexc.get_callstack Int.max_int in
  Alice_print.Raw.pps_eprint
    [ Pp.newline
    ; Pp.newline
    ; Pp.tag tag_error (Pp.text "Backtrace:")
    ; Pp.newline
    ; Pp.text (Printexc.raw_backtrace_to_string backtrace)
    ];
  exit 1
;;

let panic_u = panic

module User_error = struct
  type t = Ansi_style.t Pp.t list
  type nonrec 'a result = ('a, t) result

  exception E of t

  let eprint t = Alice_print.Raw.pps_eprint (Pp.newline :: t)
  let get = Result.get_ok

  let get_or_panic = function
    | Ok t -> t
    | Error pps -> panic pps
  ;;
end

type 'a user_result = 'a User_error.result

let user_exn pps = raise (User_error.E pps)
