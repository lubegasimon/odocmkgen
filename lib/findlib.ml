
  open Listm
  
  type t = {
    package : string;
    dir : Fpath.t;
    dependencies : Fpath.t list;
  }

  let lines_of_process p =
    let ic = Unix.open_process_in p in
    let lines = Fun.protect
      ~finally:(fun () -> ignore(Unix.close_process_in ic))
      (fun () ->
        let rec inner acc =
          try
            let l = input_line ic in
            inner (l::acc)
          with End_of_file -> List.rev acc
        in inner [])
    in
    lines

  let find_all_packages () =
    let get_package line =
      try
        let xs = Astring.String.cuts ~sep:" " line in
        [List.hd xs]
      with _ -> []
    in
    lines_of_process "ocamlfind list" >>= get_package
  
  let get_package_info package =
    let dir_res = lines_of_process ("ocamlfind query " ^ package) |> List.hd |> Fpath.of_string in
    match dir_res with
    | Ok dir ->
      let dependencies =
        lines_of_process ("ocamlfind query -recursive " ^ package) >>= fun x -> match Fpath.of_string x with | Ok p when dir <> p -> [p] | _ -> [] 
      in
      {package; dir; dependencies}
    | Error (`Msg m) ->
      Format.eprintf "`ocamlfind query %s` result could not be parsed as a directory: %s" package m;
      exit 1


  let read_all () =
    let packages = find_all_packages () in
    List.map get_package_info packages

  let rec list pp fmt = function
    | x::y::xs -> Format.fprintf fmt "%a %a" pp x (list pp) (y::xs)
    | [x] -> pp fmt x
    | [] -> ()

  let pp fmt x =
    Format.fprintf fmt "%s: %a [%a]" x.package Fpath.pp x.dir (list Fpath.pp) x.dependencies
