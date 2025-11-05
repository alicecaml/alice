open! Alice_stdlib
open Alice_package
open Alice_hierarchy

type t

val to_string : t -> string
val basename_without_extension : t -> Basename.t
val of_package_name : Package_name.t -> t
val internal_modules : Package_name.t -> t
