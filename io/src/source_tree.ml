module Dir = struct
  include Spice_source_tree.Dir

  let create ~dir =
    let x = Unix.opendir dir in
    let y = Unix.readdir x in
    ()
  ;;
end
