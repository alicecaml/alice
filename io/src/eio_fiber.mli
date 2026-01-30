open! Alice_stdlib
include module type of Eio.Fiber

val all_values : (unit -> 'a) list -> 'a list
