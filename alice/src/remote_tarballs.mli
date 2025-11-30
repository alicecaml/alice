open! Alice_stdlib

type t

module Root_5_3_1 : sig
  val aarch64_linux_musl_static_5_3_1 : t
  val aarch64_linux_gnu_5_3_1 : t
  val aarch64_macos_5_3_1 : t
  val x86_64_linux_musl_static_5_3_1 : t
  val x86_64_linux_gnu_5_3_1 : t
  val x86_64_macos_5_3_1 : t
  val x86_64_windows_5_3_1 : t
end

val install_all
  :  t
  -> Alice_stdlib.Env.t
  -> dst:'a Alice_hierarchy.Absolute_path.t
  -> unit

val install_compiler
  :  t
  -> Alice_stdlib.Env.t
  -> dst:'a Alice_hierarchy.Absolute_path.t
  -> unit
