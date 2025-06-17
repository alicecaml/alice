open! Spice_stdlib
module Command = Spice_engine.Command
module Abstract_rule = Spice_engine.Abstract_rule

module Ctx = struct
  type t =
    { optimization_level : [ `O0 | `O1 | `O2 | `O3 ] option
    ; debug : bool
    ; override_c_compiler : string option
    }

  let cc_command t ~args =
    let prog = Option.value t.override_c_compiler ~default:"cc" in
    let args =
      (if t.debug then [ "-g" ] else [])
      @ (match t.optimization_level with
         | None -> []
         | Some `O0 -> [ "-O0" ]
         | Some `O1 -> [ "-O1" ]
         | Some `O2 -> [ "-O2" ]
         | Some `O3 -> [ "-O3" ])
      @ args
    in
    Command.create prog ~args
  ;;
end

let c_to_o_rule ctx =
  Abstract_rule.create ~f:(fun target ->
    match Filename.extension target with
    | ".o" ->
      let without_extension = Filename.chop_extension target in
      let with_c_extension = Filename.concat without_extension ".c" in
      Some
        ( `Inputs [ with_c_extension ]
        , `Actions [ Ctx.cc_command ctx ~args:[ "-c"; with_c_extension ] ] )
    | _ -> None)
;;
