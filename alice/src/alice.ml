open Climate
module Tools = Tools

let () =
  let open Command in
  group [ Tools.subcommand ] |> run
;;
