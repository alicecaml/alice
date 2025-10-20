open! Alice_stdlib

(** Print an error message and exit the program. Use for unrecoverable errors
    caused by a bug. For errors caused by user's actions, use the [User_error]
    module instead. *)
val panic : Ansi_style.t Pp.t list -> 'a

(** [panic] but it returns a [unit] so you can write [panic_u [ ... ];] on a
    single line. *)
val panic_u : Ansi_style.t Pp.t list -> unit

module User_error : sig
  type t = Ansi_style.t Pp.t list
  type nonrec 'a result = ('a, t) result

  exception E of t

  val eprint : t -> unit
  val get : 'a result -> 'a
end

type 'a user_result = 'a User_error.result

(** Raise a [User_error.E] exception. *)
val user_exn : User_error.t -> 'a
