open! Alice_stdlib
open Climate

let panic_if_hashes_don't_match path expected_hash =
  let actual_hash = Sha256.file path in
  if Sha256.equal actual_hash expected_hash
  then ()
  else
    Alice_error.panic
      [ Pp.textf "Hash mismatch for file: %s" path
      ; Pp.newline
      ; Pp.textf "Expected hash: %s" (Sha256.to_hex expected_hash)
      ; Pp.newline
      ; Pp.textf "Actual hash: %s" (Sha256.to_hex actual_hash)
      ]
;;

module Remote_tarball = struct
  open Alice_io

  type t =
    { name : string
    ; version : string
    ; url : Url.t
    ; top_level_dir : Filename.t
    ; sha256 : Sha256.t
    }

  let create ~name ~version ~url ~top_level_dir ~sha256 =
    { name; version; url; top_level_dir; sha256 }
  ;;

  let get { name; version; url; top_level_dir; sha256 } ~dst =
    let open Alice_print in
    Temp_dir.with_ ~prefix:"alice." ~suffix:".tools" ~f:(fun dir ->
      let tarball_file = Filename.concat dir (sprintf "%s.tar.gz" name) in
      pp_print (Pp.textf "Fetching %s.%s..." name version);
      Fetch.fetch ~url ~output_file:tarball_file;
      panic_if_hashes_don't_match tarball_file sha256;
      pp_println (Pp.text "Done!" |> Pp.tag (Ansi_style.default_with_color `Green));
      pp_print (Pp.textf "Unpacking %s.%s..." name version);
      Extract.extract ~tarball_file ~output_dir:dir;
      File_ops.recursive_move_between_dirs ~src:(Filename.concat dir top_level_dir) ~dst;
      pp_println (Pp.text "Done!" |> Pp.tag (Ansi_style.default_with_color `Green));
      pp_println
        (Pp.textf "Successfully installed %s.%s!\n" name version
         |> Pp.tag (Ansi_style.default_with_color `Green)))
  ;;
end

module Remote_tarballs = struct
  type t =
    { compiler : Remote_tarball.t
    ; ocamllsp : Remote_tarball.t
    ; ocamlformat : Remote_tarball.t
    }

  let rt = Remote_tarball.create
  let all { compiler; ocamllsp; ocamlformat } = [ compiler; ocamllsp; ocamlformat ]

  let url_base =
    "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/"
  ;;

  let url_base = "http://localhost:8000/"
  let mk_url rel = String.cat url_base rel

  (* Just hard-code these for now to keep things simple! *)
  let macos_aarch64_5_3_1 =
    { compiler =
        rt
          ~name:"ocaml"
          ~version:"5.3.1+relocatable"
          ~url:(mk_url "5.3.1/ocaml-macos-aarch64.5.3.1%2Brelocatable.tar.gz")
          ~top_level_dir:"ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "5df182e10051f927a04f186092f34472a5a12d837ddb2531acbc2d4d2544e5d6")
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url:
            (mk_url
               "5.3.1/ocamllsp-macos-aarch64.1.22.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz")
          ~top_level_dir:"ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "f3165deb01ff54f77628a0b7d83e78553c24705e20e2c3d240b591eb809f59a3")
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url:
            (mk_url
               "5.3.1/ocamlformat-macos-aarch64.0.27.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz")
          ~top_level_dir:"ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "24408bbd0206ad32d49ee75c3a63085c66c57c789ca38d14c71dda3555d2902f")
    }
  ;;

  let get_all t ~dst = List.iter (all t) ~f:(fun rt -> Remote_tarball.get rt ~dst)
end

let xdg () = Alice_io.Xdg.create ()
let base_dir () = Filename.concat (Xdg.home_dir (xdg ())) ".alice"
let roots_dir () = Filename.concat (base_dir ()) "roots"
let current_path () = Filename.concat (base_dir ()) "current"

module Root = struct
  type t =
    { name : string
    ; remote_tarballs_by_target : Remote_tarballs.t Target.Map.t
    }

  let root_5_3_1 =
    { name = "5.3.1"
    ; remote_tarballs_by_target =
        Target.Map.of_list_exn
          [ ( Target.create ~os:Macos ~arch:Aarch64 ~linked:Dynamic
            , Remote_tarballs.macos_aarch64_5_3_1 )
          ]
    }
  ;;

  let choose_remote_tarballs t ~target =
    Target.Map.find_exn t.remote_tarballs_by_target target
  ;;

  let dir { name; _ } = Filename.concat (roots_dir ()) name

  let get t =
    let target = Target.poll () in
    let remote_tarballs = choose_remote_tarballs t ~target in
    let dst = dir t in
    Alice_io.File_ops.mkdir_p dst;
    Remote_tarballs.get_all remote_tarballs ~dst
  ;;

  let make_current t =
    let current_path = current_path () in
    if Sys.file_exists current_path then Unix.unlink current_path;
    Unix.symlink (dir t) current_path
  ;;

  let is_installed t = Sys.file_exists (dir t)
  let latest = root_5_3_1

  let conv =
    let open Arg_parser in
    enum
      ~eq:(fun a b -> String.equal a.name b.name)
      ~default_value_name:"ROOT"
      [ "5.3.1", root_5_3_1 ]
  ;;
end

module Shell = struct
  type t =
    | Bash
    | Zsh
    | Fish

  let equal a b =
    match a, b with
    | Bash, Bash | Zsh, Zsh | Fish, Fish -> true
    | _ -> false
  ;;

  let conv =
    let open Arg_parser in
    enum ~eq:equal ~default_value_name:"SHELL" [ "bash", Bash; "zsh", Zsh; "fish", Fish ]
  ;;

  let of_string_opt = function
    | "bash" -> Some Bash
    | "zsh" -> Some Zsh
    | "fish" -> Some Fish
    | _ -> None
  ;;

  let from_env () =
    match Alice_io.Env.shell () with
    | None -> Bash
    | Some shell_basename ->
      (match of_string_opt shell_basename with
       | Some shell -> shell
       | None ->
         Alice_error.panic
           [ Pp.textf "Don't know how to handle shell: %s" shell_basename ])
  ;;

  let update_path t ~root =
    let base_dir =
      match root with
      | None -> current_path ()
      | Some root -> Root.dir root
    in
    let bin_dir = Filename.concat base_dir "bin" in
    match t with
    | Bash | Zsh -> sprintf "export PATH=\"%s:$PATH\"" bin_dir
    | Fish -> sprintf "fish_add_path --prepend --path \"%s\"" bin_dir
  ;;
end

let get =
  let open Arg_parser in
  let+ root = named_with_default [ "r"; "root" ] Root.conv ~default:Root.latest in
  Root.get root;
  if not (Sys.file_exists (current_path ()))
  then (
    Alice_print.pp_println
      (Pp.textf "No current root was found so making %s the current root." root.name);
    Root.make_current root)
;;

let env =
  let open Arg_parser in
  let+ shell =
    named_opt
      [ "s"; "shell" ]
      Shell.conv
      ~doc:"Print the env in the syntax for this shell rather than the current shell."
  and+ root =
    named_opt [ "r"; "root" ] Root.conv ~doc:"Use this root rather than the current root."
  in
  let shell =
    match shell with
    | Some shell -> shell
    | None -> Shell.from_env ()
  in
  print_endline (Shell.update_path shell ~root)
;;

let change =
  let open Arg_parser in
  let+ root = pos_req 0 Root.conv in
  if Root.is_installed root
  then Root.make_current root
  else
    Alice_error.panic
      [ Pp.textf
          "Root %s is not installed. Run `alice tools get %s` first."
          root.name
          root.name
      ]
;;

let subcommand =
  let open Command in
  subcommand
    "tools"
    (group
       [ subcommand "get" (singleton get)
       ; subcommand "env" (singleton env)
       ; subcommand "change" (singleton change)
       ])
;;
