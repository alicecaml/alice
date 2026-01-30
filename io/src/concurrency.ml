open! Alice_stdlib

module Num_jobs = struct
  type t =
    | Limited of int
    | Unlimited

  let limited n =
    if n < 1
    then
      Alice_error.user_exn
        [ Pp.textf "Jobs may only be limited to a positive integer (got %d)." n ]
    else Limited n
  ;;

  let unlimited = Unlimited
end

module Limit = struct
  type t =
    | Limited of Eio.Semaphore.t
    | Unlimited

  let of_num_jobs = function
    | Num_jobs.Limited n -> Limited (Eio.Semaphore.make n)
    | Unlimited -> Unlimited
  ;;

  let acquire = function
    | Limited s -> Eio.Semaphore.acquire s
    | Unlimited -> ()
  ;;

  let release = function
    | Limited s -> Eio.Semaphore.release s
    | Unlimited -> ()
  ;;

  let run t ~f =
    acquire t;
    let x = f () in
    release t;
    x
  ;;
end
