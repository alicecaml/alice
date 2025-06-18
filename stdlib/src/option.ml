open! Stdlib
include Option

let map t ~f = map f t
let bind t ~f = bind t f
let iter t ~f = iter f t
let equal a b ~eq = Option.equal eq a b
