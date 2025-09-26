open! Alice_stdlib
open Alice_hierarchy
module Log = Alice_log

let read_etc_issue () =
  let etc_issue = Path.absolute "/etc/issue" in
  if File_ops.exists etc_issue then Some (File_ops.read_text_file etc_issue) else None
;;

(* Chooses statically-linked tools on Alpine and NixOS.
   XXX Is there a more robust way to choose whether statically-linked tools
       should be used than the OS distro? *)
let current_distro_requires_statically_linked_tools () =
  match read_etc_issue () with
  | None -> false
  | Some etc_issue ->
    let re_nixos = Re.str "NixOS" |> Re.compile in
    let re_alpine = Re.str "Alpine" |> Re.compile in
    if not (Re.all re_nixos etc_issue |> List.is_empty)
    then (
      Log.debug [ Pp.text "Detected distro as NixOS." ];
      true)
    else if not (Re.all re_alpine etc_issue |> List.is_empty)
    then (
      Log.debug [ Pp.text "Detected distro as Alpine." ];
      true)
    else false
;;
