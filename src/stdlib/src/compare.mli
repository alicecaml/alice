(** Convenient way to build comparisons for
    records/tuples by chaining together multiple
    comparisons.

    For example:

      let compare t { foo; bar } =
        let open Compare in
        let= () = Foo.compare t.foo foo in
        let= () = Bar.compare t.bar bar in
        0
*)
val ( let= ) : int -> (unit -> int) -> int
