open! Alice_stdlib
open Alice_package
open Alice_hierarchy

type t = string

let to_string_uppercase_first_letter t = t

let string_split_on_first string =
  let length = String.length string in
  let first = String.sub string ~pos:0 ~len:1 in
  let rest = String.sub string ~pos:1 ~len:(length - 1) in
  first, rest
;;

let basename_without_extension t =
  let first, rest = string_split_on_first t in
  let first_lower = String.lowercase_ascii first in
  String.cat first_lower rest |> Basename.of_filename
;;

let of_package_name package_name =
  let package_name_s = Package_name.to_string package_name in
  let first, rest = string_split_on_first package_name_s in
  let first_upper = String.uppercase_ascii first in
  String.cat first_upper rest
;;

let internal_modules package_name =
  let package_name_s = Package_name.to_string package_name in
  String.cat "Internal_modules_of_" package_name_s
;;

let public_interface_to_open package_name =
  let package_name_s = Package_name.to_string package_name in
  String.cat "Public_interface_to_open_of_" package_name_s
;;
