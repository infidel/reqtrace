(*
 * Copyright (c) 2015 Luke Dunstan <LukeDunstan81@gmail.com>
 * Copyright (c) 2015 David Sheets <sheets@alum.mit.edu>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

module Error = ReqtraceExtractCmd.Error
module Dir = ReqtraceUtil.Dir

let (/) = Filename.concat

let html_name_of path =
  (try
     let last_dot = String.rindex path '.' in
     String.sub path 0 last_dot
   with Not_found -> path
  )^ ".html"

(*
let uri_of_path ~scheme path =
  Uri.of_string begin
    if scheme <> "file" && Filename.check_suffix path "/index.html"
    then Filename.chop_suffix path "index.html"
    else path
  end

let normal_uri ~scheme uri =
  if scheme <> "file"
  then uri
  else Uri.(resolve "" uri (of_string "index.html"))

let pathloc ?pkg_root scheme unit = CodocDocHtml.pathloc
  ~unit
  ~index:CodocDoc.(fun root -> match root with
  | Html (path, _) -> Some (uri_of_path ~scheme path)
  | Xml (path, _) ->
    Some (uri_of_path ~scheme (html_name_of path)) (* TODO: fixme? *)
  | _ -> None (* TODO: log *)
  )
  ?pkg_root
  ~normal_uri:(normal_uri ~scheme)
*)

let write_html html_file html =
  let out_file = open_out html_file in
  let xout = Xmlm.make_output (`Channel out_file) in
  Xmlm.output_doc_tree (fun node -> node) xout (None, html);
  close_out out_file

(*
let render_interface ?pkg_root in_file out_file scheme css =
  let ic = open_in in_file in
  let input = Xmlm.make_input (`Channel ic) in
  match DocOckXmlParse.file CodocXml.doc_parser input with
  | DocOckXmlParse.Error (start, pos, s) ->
    close_in ic;
    [CodocIndex.Xml_error (in_file, pos, s)]
  | DocOckXmlParse.Ok unit ->
    close_in ic;
    let root, _ = CodocUtil.root_of_unit unit in
    (* TODO: use triangle for path, not assumption!!! don't keep stacking *)
    let html_root = CodocDoc.(match root with
      | Html (_,_) -> root
      | _ -> Html (Filename.basename out_file, root)
    ) in
    let id = unit.DocOckTypes.Unit.id in
    let id = CodocDoc.Maps.replace_ident_module_root html_root id in
    let unit = { unit with DocOckTypes.Unit.id } in

    let pathloc = pathloc ?pkg_root scheme unit in
    let html = CodocDocHtml.of_unit ~pathloc unit in
    let _, title = CodocUtil.root_of_unit unit in
    write_html ~css ~title out_file html;

    let oc = open_out in_file in
    let output = Xmlm.make_output (`Channel oc) in
    DocOckXmlFold.file CodocXml.doc_printer
      (fun () signal -> Xmlm.output output signal) () unit;
    close_out oc;
    [] (* TODO: issues *)

let print_issues in_file = List.iter (fun issue ->
  let `Error (_,msg) = CodocIndex.error_of_issue in_file issue in
  prerr_endline msg
)

let render_interface_ok in_file out_file scheme css =
  match Dir.make_exist ~perm:0o777 (Filename.dirname out_file) with
  | Some err -> err
  | None ->
    let issues =
      render_interface in_file (html_name_of in_file) scheme css
    in
    print_issues in_file issues; `Ok ()

let check_create_safe index out_dir = CodocIndex.(
  fold_down
    ~unit_f:(fun errs index ({ xml_file }) ->
      let html_file = html_name_of xml_file in
      let path = Filename.dirname (out_dir / index.path) / html_file in
      if not force && Sys.file_exists path
      then (Error.use_force path)::errs
      else
        (* here, we rely on umask to set the perms correctly *)
        match Dir.make_exist ~perm:0o777 (Filename.dirname path) with
        | Some err -> err::errs
        | None -> errs
    )
    ~pkg_f:(fun rc errs index ->
      let html_file = html_name_of index.path in
      let path = out_dir / html_file in
      if not force && Sys.file_exists path
      then rc ((Error.use_force path)::errs)
      else
        (* here, we rely on umask to set the perms correctly *)
        match Dir.make_exist ~perm:0o777 (Filename.dirname path) with
        | Some err -> err::errs (* don't recurse *)
        | None -> rc errs
    )
    [] index
)
*)

(*
let render_dir ~index in_index out_dir scheme css =
  let root = Filename.dirname in_index in
  let path = Filename.basename in_index in
  let idx = CodocIndex.read root path in
  match check_create_safe idx out_dir with
  | (_::_) as errs -> CodocCli.combine_errors errs
  | [] ->
    let open CodocIndex in
    let unit_f idxs idx gunit =
      let path = match Filename.dirname idx.path with "." -> "" | p -> p in
      let xml_file = idx.root / path / gunit.xml_file in
      let html_file = match gunit.html_file with
        | None -> html_name_of gunit.xml_file
        | Some html_file -> html_file
      in
      let pkg_root = CodocUtil.(ascent_of_depth "" (depth html_file)) in
      let html_path = path / html_file in
      let css = CodocUtil.(ascent_of_depth css (depth html_path)) in
      let html_root = out_dir / html_path in
      let issues = render_interface ~pkg_root xml_file html_root scheme css in
      if index
      then
        let out_index = read_cache { idx with root = out_dir } idx.path in
        let index = set_issues out_index gunit issues in
        let index = set_html_file index gunit (Some html_file) in
        write_cache index;
        idxs
      else (print_issues xml_file issues; idxs)
    in
    let pkg_f rc idxs idx = if index then rc (idx::idxs) else rc idxs in
    (* TODO: errors? XML errors? *)
    let idxs = fold_down ~unit_f ~pkg_f [] idx in
    List.iter (fun idx ->
      let idx = read_cache { idx with root = out_dir } idx.path in
      let html_file = html_name_of idx.path in
      let path = out_dir / html_file in
      let name = match Filename.dirname idx.path with
        | "." -> ""
        | dir -> dir
      in
      let css = CodocUtil.(ascent_of_depth css (depth idx.path)) in
      let `Ok () = render_index name idx path scheme css in
      ()
    ) idxs;
    flush_cache idx;
    `Ok ()
     *)

let maybe_copy path target_dir =
  let file_name = Filename.basename path in
  let target = target_dir / file_name in
  (* here, we rely on umask to set the perms correctly *)
  match Dir.make_exist ~perm:0o777 target_dir with
  | Some err -> err
  | None ->
    ReqtraceUtil.map_ret (fun _ -> file_name) (ReqtraceUtil.copy path target)

let css_name = "rfc_notes.css"
let js_name = "rfc_notes.js"

let shared_css share = share / css_name
let shared_js share = share / js_name

let render_with_css share css_dir render_f = function
  | Some css -> render_f (Uri.to_string css)
  | None ->
    let css = shared_css share in
    match maybe_copy css css_dir with
    | `Ok css -> render_f css
    | `Error _ as err -> err

let render_with_js share js_dir render_f = function
  | Some js -> render_f (Uri.to_string js)
  | None ->
    let js = shared_js share in
    match maybe_copy js js_dir with
    | `Ok js -> render_f js
    | `Error _ as err -> err

let render_rfc rfc out_file css js src_base refs =
  let html = ReqtraceDocHtml.of_rfc ~css ~js ~refs ~src_base rfc in
  write_html out_file html;
  `Ok ()

let render_file in_file out_file css js src_base share refs =
  let css_js_dir = Filename.dirname out_file in
  let rfc = ReqtraceDocXml.read in_file in
  render_with_js share css_js_dir (fun js ->
      render_with_css share css_js_dir (fun css ->
          render_rfc rfc out_file css js src_base refs) css) js

let only_req file path =
  Filename.check_suffix file ".req"

let all_reqs dir =
  ReqtraceUtil.foldp_paths (fun lst rel_req -> rel_req::lst) only_req [] dir

let load_refs_dir dir =
  let files = all_reqs dir in
  let file_count = List.length files in
  Printf.printf
    "%4d .req under %s\n" file_count dir;
  match List.fold_left (fun (units,errs) rel_file ->
      match ReqtraceRefXml.read (dir / rel_file) with
      | `Ok unit -> (unit::units, errs)
      | `Error err -> (units, (`Error err)::errs)
    ) ([],[]) files
  with
  | _, ((_::_) as errs) -> ReqtraceUtil.combine_errors errs
  | units, [] -> `Ok units

let load_refs = function
  | None -> `Ok []
  | Some (`Missing path) -> Error.source_missing path
  | Some (`File path) ->
    begin match ReqtraceRefXml.read path with
      | `Ok unit -> `Ok [unit]
      | `Error _ as err -> err
    end
  | Some (`Dir path) ->
    load_refs_dir path

let run_with_refs output path css js src_base share refs =
  match path, output with
  | `Missing path, _ -> Error.source_missing path
  | `File in_file, None ->
    render_file in_file (html_name_of in_file) css js src_base share refs
  | `File in_file, Some (`Missing out_file | `File out_file) ->
    render_file in_file out_file css js src_base share refs
  | `File in_file, Some (`Dir out_dir) ->
    let html_name = html_name_of (Filename.basename in_file) in
    render_file in_file (out_dir / html_name) css js src_base share refs
  | `Dir in_dir, None ->
    `Error (false, "unimplemented")
  | `Dir in_dir, Some (`Missing out_dir | `Dir out_dir) ->
    `Error (false, "unimplemented")
  | `Dir in_dir, Some (`File out_file) ->
    `Error (false, "unimplemented")
  (*
  | `Dir in_dir, None ->
    begin match ReqtraceUtil.search_for_source in_dir with
    | None -> Error.source_not_found in_dir
    | Some (source, Unknown) -> Error.unknown_file_type source
    | Some (source, Interface) ->
      let html_name = html_name_of source in
      let render_f = render_interface_ok source html_name scheme in
      render_with_css share in_dir render_f css
    | Some (source, Index) ->
      let render_f = render_dir ~index source in_dir scheme in
      render_with_css share in_dir render_f css
    end
  | `Dir in_dir, Some (`Missing out_dir | `Dir out_dir) ->
    begin match ReqtraceUtil.search_for_source in_dir with
    | None -> Error.source_not_found in_dir
    | Some (source, Unknown) -> Error.unknown_file_type source
    | Some (source, Interface) ->
      let html_name = out_dir / (html_name_of (Filename.basename source)) in
      let render_f = render_interface_ok source html_name scheme in
      render_with_css share out_dir render_f css
    | Some (source, Index) ->
      let render_f = render_dir ~index source out_dir scheme in
      render_with_css share out_dir render_f css
    end
  | `Dir in_dir, Some (`File out_file) ->
    begin match ReqtraceUtil.search_for_source in_dir with
    | None -> Error.source_not_found in_dir
    | Some (source, Unknown) -> Error.unknown_file_type source
    | Some (source, Interface) ->
      let render_f = render_interface_ok source out_file scheme in
      let css_dir = Filename.dirname out_file in
      render_with_css share css_dir render_f css
    | Some (source, Index) -> Error.index_to_file source out_file
    end
  *)

let run output path css js base share ref_path =
  let src_base = match base with None -> "" | Some uri -> Uri.to_string uri in
  match load_refs ref_path with
  | `Ok refs -> run_with_refs output path css js src_base share refs
  | `Error _ as err -> err
