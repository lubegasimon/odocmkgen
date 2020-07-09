open Listm

let is_hidden x =
  let is_hidden s =
    let len = String.length s in
    let rec aux i =
        if i > len - 2 then false else
        if s.[i] = '_' && s.[i + 1] = '_' then true
        else aux (i + 1)
    in aux 0
  in
  is_hidden (Fpath.basename x)

let paths_of_package all_files package =
  let all_paths =
    all_files >>= fun file ->
    match Fpath.(segs (normalize file)) with
    | "odocs" :: pkg :: _ when pkg = package -> [fst (Fpath.split_base file)]
    | _ -> []
  in
  setify all_paths

let run path =
    (* Find all odoc files, result is list of Fpath.t with no extension *)
    let all_files = Inputs.find_files ["odoc"] path in

    (* Filter out only non-hidden files *)
    let files = all_files >>= filter (fun f -> not (is_hidden f)) in

    (* Find the set of directories that contain all of the files *)
    let dirs = Fpath.Set.of_list (List.map (fun f -> fst (Fpath.split_base f)) all_files) in

    (* For each directory, use odoc to find the union of the set of packages each odoc file requires *)
    let odoc_deps = Fpath.Set.fold (fun dir acc -> Fpath.Map.add dir (Odoc.link_deps dir) acc) dirs Fpath.Map.empty in

    Format.printf "default: link\n%!";
    List.iter (fun file ->
      (* The directory containing the odoc file *)
      let dir = fst (Fpath.split_base file) in

      (* Find the corresponding entry in the map of package dependencies odoc has calculated *)
      let deps = Option.get @@ Fpath.Map.find dir odoc_deps in

      (* Extract the packages and remove duplicates *)
      let dep_packages = setify @@ List.map (fun dep -> dep.Odoc.package) deps in

      (* Find the directories that contain these packages - note the mapping of package -> 
         directory is one-to-many *)
      let dirs = setify @@ dep_packages >>= fun package -> paths_of_package all_files package in
      (* List.iter (fun dir ->
        let deps = List.filter (fun file -> fst (Fpath.split_base file) = dir) all_files in
        List.iter (fun dep ->
          Format.printf "%a.odocl : %a.odoc\n%!" Fpath.pp file Fpath.pp dep) deps) dirs; *)
      let output_file = match Fpath.segs file with
      | "odocs" :: rest -> Fpath.(v (String.concat dir_sep ("odocls" :: rest)))
      | path :: _ -> Format.eprintf "odoc file unexpectedly found in path %s\n%!" path;
        exit 1
      | _ -> Format.eprintf "Something odd happening with the odoc paths\n%!";
        exit 1
      in
      Format.printf "%a.odocl : %a.odoc\n\todoc link %a.odoc -o %a.odocl %s\nlink: %a.odocl\n%!"
        Fpath.pp output_file Fpath.pp file Fpath.pp file Fpath.pp output_file
        (String.concat " " (List.map (fun dir -> Format.asprintf "-I %a" Fpath.pp dir) dirs))
        Fpath.pp output_file;
      Format.printf "generate : %a.odocl\n"
        Fpath.pp output_file
      ) files;
    Format.printf "generate:\n";
    List.iter (fun file ->
      let output_file = match Fpath.segs file with
      | "odocs" :: rest -> Fpath.(v (String.concat dir_sep ("odocls" :: rest)))
      | path :: _ -> Format.eprintf "odoc file unexpectedly found in path %s\n%!" path;
        exit 1
      | _ -> Format.eprintf "Something odd happening with the odoc paths\n%!";
        exit 1
      in
      Format.printf "\todoc generate %a.odocl --output-dir html\n" Fpath.pp output_file
    ) files
    