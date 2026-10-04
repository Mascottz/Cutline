open Cmdliner

let fail action reason =
  prerr_endline ("I could not " ^ action ^ ": " ^ reason);
  exit 2

let unwrap action = function Ok value -> value | Error reason -> fail action reason

let load_source path =
  try Yojson.Safe.from_file path with
  | Sys_error _ -> fail "read the dataset notes" ("an unreadable metadata file: " ^ path)
  | Yojson.Json_error _ -> fail "read the dataset notes" "malformed metadata json"

let serve_graph graph source assets_dir port initial =
  if port < 0 || port > 65_535 then fail "start the local preview" "a port outside the valid range";
  Server.run ~graph ~source ~initial ~assets_dir ~port

let demo data_path metadata_path assets_dir port =
  let graph = Import.read_geojson data_path |> unwrap "load the demo graph" in
  let source = load_source metadata_path in
  let initial = Graph.default_query graph |> unwrap "choose a demo route" in
  serve_graph graph source assets_dir port initial

let import_file input output =
  let graph = Import.read_geojson input |> unwrap "import the street extract" in
  match Codec.write_file output graph with
  | Ok () -> Printf.printf "I wrote the normalized graph to %s\n" output
  | Error reason -> fail "write the normalized graph" reason

let serve_file input assets_dir port =
  let graph = Codec.read_file input |> unwrap "load the normalized graph" in
  let source =
    `Assoc
      [ ("name", `String (Filename.basename input));
        ("snapshot_date", `Null);
        ("source_url", `Null);
        ("attribution", `Null);
        ("scenario_note", `String "I analyze the supplied graph as a local experiment.") ]
  in
  let initial = Graph.default_query graph |> unwrap "choose a route" in
  serve_graph graph source assets_dir port initial

let data_arg =
  Arg.(value & opt string "data/demo/yaba.geojson" & info [ "data" ] ~docv:"PATH"
       ~doc:"I read the bundled street extract from this path.")

let metadata_arg =
  Arg.(value & opt string "data/demo/metadata.json" & info [ "metadata" ] ~docv:"PATH"
       ~doc:"I read the source notes from this path.")

let assets_arg =
  Arg.(value & opt string "web/static" & info [ "assets" ] ~docv:"PATH"
       ~doc:"I read the compiled interface from this directory.")

let port_arg =
  Arg.(value & opt int 0 & info [ "port" ] ~docv:"PORT"
       ~doc:"I bind the preview to an ephemeral local port by default.")

let demo_command =
  let term = Term.(const demo $ data_arg $ metadata_arg $ assets_arg $ port_arg) in
  Cmd.v (Cmd.info "demo" ~doc:"I open the bundled street graph as a local atlas.") term

let serve_input_arg =
  Arg.(required & pos 0 (some string) None & info [] ~docv:"GRAPH"
       ~doc:"I read a normalized graph from this path.")

let serve_command =
  let term = Term.(const serve_file $ serve_input_arg $ assets_arg $ port_arg) in
  Cmd.v (Cmd.info "serve" ~doc:"I open a normalized graph as a local atlas.") term

let import_input_arg =
  Arg.(required & pos 0 (some string) None & info [] ~docv:"GEOJSON"
       ~doc:"I read a local street FeatureCollection from this path.")

let output_arg =
  Arg.(value & opt string "network.cutline.json" & info [ "out" ] ~docv:"PATH"
       ~doc:"I write the normalized graph to this path.")

let import_command =
  let term = Term.(const import_file $ import_input_arg $ output_arg) in
  Cmd.v (Cmd.info "import" ~doc:"I normalize local street geometry into a graph.") term

let command =
  Cmd.group
    (Cmd.info "cutline" ~version:"0.1.0" ~doc:"I measure route changes in a local street graph.")
    [ demo_command; import_command; serve_command ]

let () = exit (Cmd.eval command)
