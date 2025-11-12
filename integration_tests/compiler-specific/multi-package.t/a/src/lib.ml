module C = B.C
module C_again = B.Another_alias_of_c

module B_plus = struct
  include B

  let yet_another_message = "foo bar baz"
end
