let max_file_bytes = 20 * 1024 * 1024

let error text = Error ("I found " ^ text)
let field key = function `Assoc fields -> List.assoc_opt key fields | _ -> None

let as_string = function
  | Some (`String value) when String.trim value <> "" -> Ok value
  | _ -> error "a missing string field"

let as_int = function
  | Some (`Int value) -> Ok value
  | Some (`Intlit value) ->
      (try Ok (int_of_string value) with Failure _ -> error "an integer outside the supported range")
  | _ -> error "a missing integer field"

let as_int64 = function
  | Some (`Int value) -> Ok (Int64.of_int value)
  | Some (`Intlit value) ->
      (try Ok (Int64.of_string value) with Failure _ -> error "an invalid 64-bit integer")
  | _ -> error "a missing 64-bit integer field"

let as_bool = function
  | Some (`Bool value) -> Ok value
  | _ -> error "a missing boolean field"

let assoc key value = (key, value)

let to_json graph =
  let projection = Graph.projection graph in
  let nodes =
    Graph.nodes graph
    |> List.map (fun (node : Graph.node) ->
           `Assoc
             [ assoc "id" (`String node.Graph.id);
               assoc "lat_e6" (`Int node.lat_e6);
               assoc "lon_e6" (`Int node.lon_e6) ])
  in
  let segments =
    Graph.segments graph
    |> List.map (fun (segment : Graph.segment) ->
           `Assoc
             [ assoc "id" (`String segment.Graph.id);
               assoc "way_id" (`String segment.way_id);
               assoc "sequence" (`Int segment.sequence);
               assoc "from_node" (`String segment.from_node);
               assoc "to_node" (`String segment.to_node);
               assoc "highway" (`String segment.highway);
               assoc "length_mm" (`Intlit (Int64.to_string segment.length_mm));
               assoc "forward" (`Bool segment.forward);
               assoc "reverse" (`Bool segment.reverse) ])
  in
  `Assoc
    [ assoc "schema_version" (`Int 1);
      assoc "projection"
        (`Assoc
          [ assoc "center_lat_e6" (`Int projection.center_lat_e6);
            assoc "cos_lat_ppm" (`Int projection.cos_lat_ppm) ]);
      assoc "nodes" (`List nodes);
      assoc "segments" (`List segments) ]

let parse_node value =
  match (field "id" value, field "lat_e6" value, field "lon_e6" value) with
  | id, latitude, longitude ->
      (match as_string id with
      | Error _ as failure -> failure
      | Ok id ->
          match as_int latitude with
          | Error _ as failure -> failure
          | Ok lat_e6 ->
              match as_int longitude with
              | Error _ as failure -> failure
              | Ok lon_e6 -> Ok { Graph.id; lat_e6; lon_e6 })

let parse_segment value =
  match
    ( field "id" value,
      field "way_id" value,
      field "sequence" value,
      field "from_node" value,
      field "to_node" value,
      field "highway" value,
      field "length_mm" value,
      field "forward" value,
      field "reverse" value )
  with
  | id, way_id, sequence, from_node, to_node, highway, length_mm, forward, reverse ->
      (match as_string id with
      | Error _ as failure -> failure
      | Ok id ->
          match as_string way_id with
          | Error _ as failure -> failure
          | Ok way_id ->
              match as_int sequence with
              | Error _ as failure -> failure
              | Ok sequence ->
                  match as_string from_node with
                  | Error _ as failure -> failure
                  | Ok from_node ->
                      match as_string to_node with
                      | Error _ as failure -> failure
                      | Ok to_node ->
                          match as_string highway with
                          | Error _ as failure -> failure
                          | Ok highway ->
                              match as_int64 length_mm with
                              | Error _ as failure -> failure
                              | Ok length_mm ->
                                  match as_bool forward with
                                  | Error _ as failure -> failure
                                  | Ok forward ->
                                      match as_bool reverse with
                                      | Error _ as failure -> failure
                                      | Ok reverse ->
                                          Ok
                                            {
                                              Graph.id;
                                              way_id;
                                              sequence;
                                              from_node;
                                              to_node;
                                              highway;
                                              length_mm;
                                              forward;
                                              reverse;
                                            })

let list_field name parse json =
  match field name json with
  | Some (`List values) ->
      let rec collect acc = function
        | [] -> Ok (List.rev acc)
        | value :: rest ->
            (match parse value with
            | Error _ as failure -> failure
            | Ok parsed -> collect (parsed :: acc) rest)
      in
      collect [] values
  | _ -> error ("a missing " ^ name ^ " array")

let from_json json =
  match field "schema_version" json with
  | Some (`Int 1) ->
      (match field "projection" json with
      | Some projection_json ->
          (match
             ( as_int (field "center_lat_e6" projection_json),
               as_int (field "cos_lat_ppm" projection_json) )
           with
          | Error reason, _ | _, Error reason -> Error reason
          | Ok center_lat_e6, Ok cos_lat_ppm ->
              (match list_field "nodes" parse_node json with
              | Error _ as failure -> failure
              | Ok nodes ->
                  match list_field "segments" parse_segment json with
                  | Error _ as failure -> failure
                  | Ok segments ->
                      Graph.make ~projection:{ center_lat_e6; cos_lat_ppm } ~nodes ~segments ()))
      | _ -> error "a graph projection")
  | Some (`Int version) -> error ("graph schema version " ^ string_of_int version)
  | _ -> error "graph schema version 1"

let read_file path =
  try
    let stat = Unix.stat path in
    if stat.Unix.st_size > max_file_bytes then error "a graph file larger than 20 mib"
    else
      let channel = open_in_bin path in
      let contents = really_input_string channel stat.Unix.st_size in
      close_in channel;
      try from_json (Yojson.Safe.from_string contents)
      with Yojson.Json_error _ -> error "malformed graph json"
  with
  | Sys_error _ -> error ("an unreadable graph file: " ^ path)
  | Unix.Unix_error _ -> error ("an unreadable graph file: " ^ path)
  | End_of_file -> error "a truncated graph file"

let write_file path graph =
  try
    let channel = open_out_bin path in
    output_string channel (Yojson.Safe.pretty_to_string (to_json graph));
    output_char channel '\n';
    close_out channel;
    Ok ()
  with Sys_error _ -> error ("an unwritable graph path: " ^ path)
