open! Alice_stdlib

module Parallel_with_eio = struct
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

  type 'a t =
    { proc_mgr : 'a Eio.Process.mgr
    ; limit : Limit.t
    }
end

type 'proc_mgr_tags t =
  | Sequential
  | Parallel_with_eio of 'proc_mgr_tags Parallel_with_eio.t

let sequential = Sequential

let parallel_with_eio proc_mgr num_jobs =
  let limit = Parallel_with_eio.Limit.of_num_jobs num_jobs in
  Parallel_with_eio { Parallel_with_eio.proc_mgr; limit }
;;
