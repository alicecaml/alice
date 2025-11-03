open! Alice_stdlib
open Alice_hierarchy
open Alice_error

let manifest_name = Basename.of_filename "Alice.toml"

let read_table path =
  let filename = Absolute_path.to_filename path in
  let channel = In_channel.open_text filename in
  let toml_result = Toml.Parser.parse (Lexing.from_channel channel) filename in
  In_channel.close channel;
  match toml_result with
  | `Ok table -> table
  | `Error (message, { source; line; column = _; position = _ }) ->
    user_exn
      [ Pp.text "Failed to parse toml file!\n"; Pp.textf "%s:%d: %s" source line message ]
;;

let read_package_manifest ~manifest_path =
  read_table manifest_path |> Package.of_toml ~manifest_path_for_messages:manifest_path
;;

let read_package_dir ~dir_path =
  read_package_manifest ~manifest_path:(dir_path / manifest_name)
;;

let write_package_manifest ~manifest_path package =
  let package_string = Package.to_toml package |> Toml.Printer.string_of_table in
  Alice_io.File_ops.write_text_file manifest_path package_string
;;
