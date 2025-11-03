(* Note that without disabling warning 37 the compiler warns about unused
   constructors. While [true_t] and [false_t] would ideally be phantom types
   (with no constructors), if the constructors are not exposed in the interface
   then the compiler can't refute impossible patterns of GADTs involving these
   types. An alternative solution would be to expose the constructors without
   using the "private" keyword, however this would allow client code to
   construct values of [true_t] and [false_t] which is pointless as they are
   ideally phantom types. *)

type true_t = True_t [@@warning "-37"]
type false_t = False_t [@@warning "-37"]

type _ t =
  | True : true_t t
  | False : false_t t
