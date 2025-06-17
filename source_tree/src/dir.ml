open! Spice_stdlib

type dir = { entries : entry list }

and kind =
  | File
  | Dir of dir

and entry =
  { name : Filename.t
  ; kind : kind
  }

type t =
  { path : Filename.t
  ; dir : dir
  }
