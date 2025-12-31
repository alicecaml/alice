include module type of Stdlib.Result

val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t
val map_error : ('a, 'e) t -> f:('e -> 'f) -> ('a, 'f) t
val bind : ('a, 'e) t -> f:('a -> ('b, 'e) t) -> ('b, 'e) t

module O : sig
  val ( >>| ) : ('a, 'error) t -> ('a -> 'b) -> ('b, 'error) t
  val ( >>= ) : ('a, 'error) t -> ('a -> ('b, 'error) t) -> ('b, 'error) t
  val ( let* ) : ('a, 'error) t -> ('a -> ('b, 'error) t) -> ('b, 'error) t
  val ( and+ ) : ('a, 'error) t -> ('b, 'error) t -> ('a * 'b, 'error) t
  val ( let+ ) : ('a, 'error) t -> ('a -> 'b) -> ('b, 'error) t
end

module List : sig
  type ('a, 'error) t = ('a, 'error) result list

  val all : ('a, 'error) t -> ('a list, 'error) result
end
