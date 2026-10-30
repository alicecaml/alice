open! Alice_stdlib
open Alice_ocaml_toolchain

type t =
  { profile : Profile.t
  ; ocaml_toolchain : Ocaml_toolchain.t
  ; compiler_backend : Compiler_backend.t
  ; num_jobs : Alice_io.Num_jobs.t
  ; os_type : Alice_env.Os_type.t
  }

let for_config_script t =
  { t with profile = Profile.minimal; compiler_backend = Bytecode }
;;
