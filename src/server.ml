open Lwt.Infix

let max_request_bytes = 64 * 1024
let max_response_bytes = 32 * 1024 * 1024
let max_closed_segments = 500
let max_asset_bytes = 4 * 1024 * 1024

let error text = Error ("I found " ^ text)

let text_response status text =
  Cohttp_lwt_unix.Server.respond_string ~status
    ~headers:
      (Cohttp.Header.init_with "content-type" "text/plain; charset=utf-8"
      |> fun headers -> Cohttp.Header.add headers "cache-control" "no-store"
      |> fun headers -> Cohttp.Header.add headers "x-content-type-options" "nosniff")
    ~body:text ()

let json_response status value =
  let body = Yojson.Safe.to_string value in
  if String.length body > max_response_bytes then
    text_response `Internal_server_error "I could not serve a response larger than 32 mib."
  else
    Cohttp_lwt_unix.Server.respond_string ~status
      ~headers:
        (Cohttp.Header.init_with "content-type" "application/json; charset=utf-8"
        |> fun headers -> Cohttp.Header.add headers "cache-control" "no-store"
        |> fun headers -> Cohttp.Header.add headers "x-content-type-options" "nosniff")
      ~body ()

let asset_response ~assets_dir ~name ~content_type =
  let path = Filename.concat assets_dir name in
  try
    let stat = Unix.stat path in
    if stat.Unix.st_size > max_asset_bytes then
      text_response `Internal_server_error "I found an oversized local asset"
    else
      let channel = open_in_bin path in
      let body = really_input_string channel stat.Unix.st_size in
      close_in channel;
      Cohttp_lwt_unix.Server.respond_string ~status:`OK
        ~headers:
          (Cohttp.Header.init_with "content-type" content_type
          |> fun headers -> Cohttp.Header.add headers "cache-control" "no-store"
          |> fun headers -> Cohttp.Header.add headers "x-content-type-options" "nosniff"
          |> fun headers ->
          Cohttp.Header.add headers "content-security-policy"
            "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
        ~body ()
  with
  | Sys_error _ | Unix.Unix_error _ ->
      text_response `Service_unavailable
        "I could not find the compiled interface; i run make web-build before demo"

let safe_host request port =
  let expected = "127.0.0.1:" ^ string_of_int port in
  Cohttp.Header.get (Cohttp.Request.headers request) "host" = Some expected

let safe_origin request port =
  match Cohttp.Header.get (Cohttp.Request.headers request) "origin" with
  | None -> true
  | Some origin -> origin = "http://127.0.0.1:" ^ string_of_int port

let rec read_body_limited stream total pieces =
  Lwt_stream.get stream >>= function
  | None -> Lwt.return (Ok (String.concat "" (List.rev pieces)))
  | Some piece ->
      let next_total = total + String.length piece in
      if next_total > max_request_bytes then Lwt.return (error "a request body larger than 64 kib")
      else read_body_limited stream next_total (piece :: pieces)

let route_to_json = function
  | None -> `Null
  | Some route ->
      `Assoc
        [ ("node_ids", `List (List.map (fun id -> `String id) route.Graph.node_ids));
          ("segment_ids", `List (List.map (fun id -> `String id) route.Graph.segment_ids));
          ("length_mm", `Intlit (Int64.to_string route.Graph.length_mm)) ]

let analysis_to_json analysis =
  `Assoc
    [ ("origin", `String analysis.Graph.origin);
      ("destination", `String analysis.destination);
      ("reachable_nodes", `Int analysis.reachable_nodes);
      ("before", route_to_json analysis.before);
      ("after", route_to_json analysis.after);
      ( "delta_basis_points",
        match analysis.delta_basis_points with
        | None -> `Null
        | Some value -> `Intlit (Int64.to_string value) ) ]

let default_analysis graph (origin, destination, closed) =
  match Graph.analyze graph ~origin ~destination ~closed with
  | Ok analysis -> Ok analysis
  | Error _ as failure -> failure

let bootstrap_json graph source analysis (_, _, closed) =
  let graph_json = Codec.to_json graph in
  match graph_json with
  | `Assoc fields ->
      `Assoc
        (fields
        @ [ ("dataset", source);
            ("analysis", analysis_to_json analysis);
            ("closed_segments", `List (List.map (fun id -> `String id) closed)) ])
  | _ -> `Assoc []

let string_field key json =
  match json with
  | `Assoc fields ->
      (match List.assoc_opt key fields with
      | Some (`String value) when String.trim value <> "" -> Ok value
      | _ -> error ("a missing " ^ key ^ " string"))
  | _ -> error "a json object"

let closed_field json =
  match json with
  | `Assoc fields ->
      (match List.assoc_opt "closed" fields with
      | Some (`List values) when List.length values <= max_closed_segments ->
          let rec collect acc = function
            | [] -> Ok (List.rev acc)
            | `String id :: rest when String.trim id <> "" -> collect (id :: acc) rest
            | _ -> error "a closure list containing nonempty segment ids"
          in
          collect [] values
      | Some (`List _) -> error "more than 500 closure ids"
      | _ -> error "a missing closure list")
  | _ -> error "a json object"

let analyze_request graph body =
  try
    let json = Yojson.Safe.from_string body in
    match (string_field "origin" json, string_field "destination" json, closed_field json) with
    | Error reason, _, _ | _, Error reason, _ | _, _, Error reason -> Error reason
    | Ok origin, Ok destination, Ok closed -> Graph.analyze graph ~origin ~destination ~closed
  with Yojson.Json_error _ -> error "malformed request json"

let callback ~graph ~source ~initial ~assets_dir ~port _connection request body =
  if not (safe_host request port) then
    text_response `Forbidden "I rejected a host outside the local preview"
  else if not (safe_origin request port) then
    text_response `Forbidden "I rejected a cross-origin request"
  else
    let path = Uri.path (Cohttp.Request.uri request) in
    match (Cohttp.Request.meth request, path) with
    | `GET, "/" -> asset_response ~assets_dir ~name:"index.html" ~content_type:"text/html; charset=utf-8"
    | `GET, "/main.js" -> asset_response ~assets_dir ~name:"main.js" ~content_type:"text/javascript; charset=utf-8"
    | `GET, "/boot.js" -> asset_response ~assets_dir ~name:"boot.js" ~content_type:"text/javascript; charset=utf-8"
    | `GET, "/style.css" -> asset_response ~assets_dir ~name:"style.css" ~content_type:"text/css; charset=utf-8"
    | `GET, "/api/bootstrap" ->
        (match default_analysis graph initial with
        | Error reason -> text_response `Internal_server_error reason
        | Ok analysis -> json_response `OK (bootstrap_json graph source analysis initial))
    | `POST, "/api/analyze" ->
        let stream = Cohttp_lwt.Body.to_stream body in
        read_body_limited stream 0 [] >>= (function
        | Error reason -> text_response `Bad_request reason
        | Ok contents ->
            match analyze_request graph contents with
            | Error reason -> text_response `Bad_request reason
            | Ok analysis -> json_response `OK (analysis_to_json analysis))
    | (`GET | `POST), "/api/health" -> json_response `OK (`Assoc [ ("status", `String "ready") ])
    | (`GET | `POST), _ -> text_response `Not_found "I found no local route at this path"
    | _ -> text_response `Method_not_allowed "I accept only the documented local methods"

let reserve_socket requested_port =
  let open Lwt.Infix in
  let socket = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Lwt_unix.setsockopt socket Unix.SO_REUSEADDR true;
  let address = Unix.ADDR_INET (Unix.inet_addr_loopback, requested_port) in
  Lwt_unix.bind socket address >>= fun () ->
  Lwt_unix.listen socket 64;
  let port =
    match Lwt_unix.getsockname socket with
    | Unix.ADDR_INET (_, port) -> port
    | Unix.ADDR_UNIX _ -> requested_port
  in
  Lwt.return (socket, port)

let run ~graph ~source ~initial ~assets_dir ~port =
  let run_server () =
    reserve_socket port >>= fun (socket, port) ->
    let callback = callback ~graph ~source ~initial ~assets_dir ~port in
    let server = Cohttp_lwt_unix.Server.make ~callback () in
    Printf.printf "I serve the local atlas at http://127.0.0.1:%d/\n%!" port;
    Printf.printf "I press ctrl-c to stop the local server\n%!";
    Lwt.finalize
      (fun () -> Cohttp_lwt_unix.Server.create ~mode:(`TCP (`Socket socket)) server)
      (fun () -> Lwt_unix.close socket)
  in
  try Lwt_main.run (run_server ()) with
  | Unix.Unix_error (error, operation, _) ->
      prerr_endline ("I could not start the local server: " ^ Unix.error_message error ^ " in " ^ operation);
      exit 1
  | Failure reason ->
      prerr_endline ("I could not start the local server: " ^ reason);
      exit 1
