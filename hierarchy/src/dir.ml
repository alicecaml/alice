open! Spice_stdlib

type file_kind =
  | Regular
  | Dir of file list
  | Link of Filename.t

and file =
  { name : Filename.t
  ; kind : file_kind
  }

type t =
  { path : Filename.t
  ; entries : file list
  }

module Entry = struct
  type t =
    { path : Filename.t
    ; kind : file_kind
    }

  let as_dir { path; kind } =
    match kind with
    | Dir entries -> Some { path; entries }
    | _ -> None
  ;;
end

let traverse { path; entries } ~descend_into_subdirs =
  let rec loop path entries =
    List.to_seq entries
    |> Seq.flat_map ~f:(fun file ->
      let file_path = Filename.concat path file.name in
      let entry = { Entry.path = file_path; kind = file.kind } in
      match file.kind with
      | Regular | Link _ -> Seq.return entry
      | Dir dir ->
        if descend_into_subdirs
        then (
          let descendants = loop file_path dir in
          Seq.cons entry descendants)
        else Seq.return entry)
  in
  loop path entries
;;
