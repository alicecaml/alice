open! Alice_stdlib
open Climate

module Os = struct
  type t =
    | Macos
    | Linux
    | Windows

  let to_dyn = function
    | Macos -> Dyn.variant "Macos" []
    | Linux -> Dyn.variant "Linux" []
    | Windows -> Dyn.variant "Windows" []
  ;;

  let to_string = function
    | Macos -> "macos"
    | Linux -> "linux"
    | Windows -> "windows"
  ;;

  let poll () =
    if Sys.win32
    then Windows
    else (
      match Alice_io.Uname.uname_s () with
      | "Darwin" -> Macos
      | "Linux" -> Linux
      | other -> Alice_error.panic [ Pp.textf "Unknown system: %s" other ])
  ;;

  let all = [ Macos; Linux; Windows ]

  let equal a b =
    match a, b with
    | Macos, Macos -> true
    | Macos, _ -> false
    | Linux, Linux -> true
    | Linux, _ -> false
    | Windows, Windows -> true
    | Windows, _ -> false
  ;;

  let conv =
    let open Arg_parser in
    enum ~eq:equal ~default_value_name:"OS" (List.map all ~f:(fun x -> to_string x, x))
  ;;
end

module Arch = struct
  type t =
    | Aarch64
    | X86_64

  let to_dyn = function
    | Aarch64 -> Dyn.variant "Aarch64" []
    | X86_64 -> Dyn.variant "X86_64" []
  ;;

  let to_string = function
    | Aarch64 -> "aarch64"
    | X86_64 -> "x86_64"
  ;;

  let poll () =
    if Sys.win32
    then (
      let var = "PROCESSOR_ARCHITECTURE" in
      match Sys.getenv_opt var with
      | Some "AMD64" -> X86_64
      | Some other -> Alice_error.panic [ Pp.textf "Unknown architecture: %s" other ]
      | None ->
        Alice_log.warn
          [ Pp.textf
              "Can't determine CPU architecture becasue environment variable %S is \
               unset. Assuming x68_64."
              var
          ];
        X86_64)
    else (
      match Alice_io.Uname.uname_m () with
      | "arm64" -> Aarch64
      | "x86_64" -> X86_64
      | other -> Alice_error.panic [ Pp.textf "Unknown architecture: %s" other ])
  ;;

  let equal a b =
    match a, b with
    | Aarch64, Aarch64 -> true
    | Aarch64, _ -> false
    | X86_64, X86_64 -> true
    | X86_64, _ -> false
  ;;

  let all = [ Aarch64; X86_64 ]

  let conv =
    let open Arg_parser in
    enum ~eq:equal ~default_value_name:"ARCH" (List.map all ~f:(fun x -> to_string x, x))
  ;;
end

module Linked = struct
  type t =
    | Dynamic
    | Static

  let to_dyn = function
    | Dynamic -> Dyn.variant "Dynamic" []
    | Static -> Dyn.variant "Static" []
  ;;

  let to_string = function
    | Dynamic -> "dynamic"
    | Static -> "static"
  ;;

  let equal a b =
    match a, b with
    | Dynamic, Dynamic -> true
    | Dynamic, _ -> false
    | Static, Static -> true
    | Static, _ -> false
  ;;

  let all = [ Dynamic; Static ]

  let conv =
    let open Arg_parser in
    enum
      ~eq:equal
      ~default_value_name:"LINKED"
      (List.map all ~f:(fun x -> to_string x, x))
  ;;
end

module T = struct
  type t =
    { os : Os.t
    ; arch : Arch.t
    ; linked : Linked.t
    }

  let to_dyn { os; arch; linked } =
    Dyn.record
      [ "os", Os.to_dyn os; "arch", Arch.to_dyn arch; "linked", Linked.to_dyn linked ]
  ;;

  let create ~os ~arch ~linked = { os; arch; linked }

  let to_string { os; arch; linked } =
    sprintf "%s-%s-%s" (Os.to_string os) (Arch.to_string arch) (Linked.to_string linked)
  ;;

  let compare a b = String.compare (to_string a) (to_string b)
end

include T
module Map = Map.Make (T)
module Set = Set.Make (T)

let poll () =
  let os = Os.poll () in
  let arch = Arch.poll () in
  let linked =
    match os with
    | Linux ->
      if Alice_io.Infer_linux_distro.current_distro_requires_statically_linked_tools ()
      then Linked.Static
      else Dynamic
    | _ -> Dynamic
  in
  create ~os ~arch ~linked
;;

let arg_parser =
  let open Arg_parser in
  let+ os = named_opt [ "os" ] Os.conv ~doc:"Choose the operating system name."
  and+ arch = named_opt [ "arch" ] Arch.conv ~doc:"Choose the CPU architecture."
  and+ linked =
    named_opt [ "linked" ] Linked.conv ~doc:"Choose between static and dynamic linking."
  in
  let polled = poll () in
  { os = Option.value os ~default:polled.os
  ; arch = Option.value arch ~default:polled.arch
  ; linked = Option.value linked ~default:polled.linked
  }
;;
