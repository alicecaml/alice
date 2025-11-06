open! Alice_stdlib
open Alice_package
open Alice_hierarchy

type t

val to_string_uppercase_first_letter : t -> string
val basename_without_extension : t -> Basename.t
val of_package_name : Package_name.t -> t

(** The name of the module packing all internal modules of a package. Part of
    Alice's packaging protocol. *)
val internal_modules : Package_name.t -> t

(** The name of the module containing the public interface to a package which
    will be opened when compiling code which depends on the package. Part of
    Alice's packaging protocol. *)
val public_interface_to_open : Package_name.t -> t
