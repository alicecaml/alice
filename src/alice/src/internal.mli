val subcommand : unit Climate.Command.subcommand

(** Ref cell for the Alice command. This is a ref cell to break a circular
    dependency, since the "internal" subcommand is part of the command object,
    but the command object is required to generate the completion script which
    is part of the "internal" subcommand. *)
val command_for_completion_script : unit Climate.Command.t option ref
