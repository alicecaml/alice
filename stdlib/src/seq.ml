open! Stdlib
include Seq

let map t ~f = map f t
let filter_map t ~f = filter_map f t
let flat_map t ~f = flat_map f t
let filter t ~f = filter f t
let iter t ~f = iter f t
