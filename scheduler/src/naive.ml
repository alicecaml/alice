open! Alice_stdlib
open Alice_hierarchy
module Build_plan = Alice_engine.Build_plan
module Traverse = Alice_engine.Build_plan.Traverse

let run ~src_dir ~out_dir traverse =
  let panic_context () =
    [ Pp.textf "src_dir: %s\n" (Path.to_filename src_dir)
    ; Pp.textf "out_dir: %s\n" (Path.to_filename out_dir)
    ]
  in
  let src_dir =
    Path.match_ src_dir ~absolute:Fun.id ~relative:(fun src_dir ->
      Path.concat (Path.absolute (Sys.getcwd ())) src_dir)
  in
  let rec loop traverse =
    let output = Traverse.output traverse in
    match (Traverse.origin traverse : Build_plan.Origin.t) with
    | Source ->
      Alice_io.File_ops.cp ~src:(Path.concat src_dir output) ~dst:Path.current_dir
    | Build (build : Build_plan.Build.t) ->
      List.iter (Traverse.deps traverse) ~f:loop;
      Path.Relative.Set.iter build.inputs ~f:(fun path ->
        let path = Path.concat out_dir path in
        if not (Alice_io.File_ops.exists path)
        then
          Alice_error.panic
            (Pp.textf "Missing input file: %s\n" (Path.to_filename path)
             :: panic_context ()));
      List.iter build.commands ~f:(fun command ->
        let status = Alice_io.Process.Blocking.run_command command |> Result.get_ok in
        match status with
        | Exited 0 -> ()
        | _ ->
          Alice_error.panic
            (Pp.textf "Command failed: %s\n" (Command.to_string command)
             :: panic_context ()))
  in
  Alice_io.File_ops.mkdir_p out_dir;
  Alice_io.File_ops.with_working_dir out_dir ~f:(fun () -> loop traverse)
;;
