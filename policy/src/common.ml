open! Alice_stdlib
open Alice_hierarchy

let all_files_with_extension (dir : _ Dir.t) ~ext =
  List.filter_map dir.contents ~f:(fun (file : _ File.t) ->
    if File.is_regular_or_link file && Path.has_extension file.path ~ext
    then Some file.path
    else None)
;;
