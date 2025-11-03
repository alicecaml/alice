(** Type-level booleans *)

type true_t = private True_t
type false_t = private False_t

type _ t =
  | True : true_t t
  | False : false_t t
