open! Alice_stdlib

let read_etc_issue () =
  let in_channel = In_channel.open_text "/etc/issue" in
  let text = In_channel.input_all in_channel in
  In_channel.close in_channel;
  text
;;

(* Chooses statically-linked tools on Alpine and NixOS *)
let current_distro_requires_statically_linked_tools () =
  let etc_issue = read_etc_issue () in
  let re_nixos = Re.str "NixOS" |> Re.compile in
  let re_alpine = Re.str "Alpine" |> Re.compile in
  if Re.all re_nixos etc_issue |> List.is_empty
  then true
  else if Re.all re_alpine etc_issue |> List.is_empty
  then true
  else false
;;
