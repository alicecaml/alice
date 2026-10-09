let ( let= ) i f =
  match i with
  | 0 -> f ()
  | _ -> i
;;
