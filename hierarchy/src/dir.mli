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

module Entry : sig
  type dir := t

  type t =
    { path : Filename.t
    ; kind : file_kind
    }

  val as_dir : t -> dir option
end

val traverse : t -> descend_into_subdirs:bool -> Entry.t Seq.t
