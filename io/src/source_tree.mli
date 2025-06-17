module Dir : sig
  include module type of struct
    include Spice_source_tree.Dir
  end
end
