module Node_map = Map.Make (String)

let ( let* ) result next = Result.bind result next

type point = {
  node_id : string;
  lat_e6 : int;
  lon_e6 : int;
}

type road = {
  way_id : string;
  highway : string;
  forward : bool;
  reverse : bool;
  points : point list;
}

let max_features = 10_000
let max_coordinates = 500_000
let max_file_bytes = 20 * 1024 * 1024
let max_local_span_e6 = 250_000

let error text = Error ("I found " ^ text)

let member key = function
  | `Assoc fields -> List.assoc_opt key fields
  | _ -> None

let string_of_id = function
  | `String value when String.trim value <> "" -> Ok value
  | `Int value -> Ok (string_of_int value)
  | `Intlit value when String.trim value <> "" -> Ok value
  | _ -> error "a missing or invalid source id"

let float_of_json = function
  | `Float value when Float.is_finite value -> Ok value
  | `Int value -> Ok (float_of_int value)
  | `Intlit value ->
      (try
         let number = float_of_string value in
         if Float.is_finite number then Ok number else error "a non-finite coordinate"
       with Failure _ -> error "an invalid coordinate")
  | _ -> error "a coordinate that is not numeric"

let coordinate_e6 value low high =
  let* number = float_of_json value in
  let scaled = Float.round (number *. 1_000_000.) in
  if scaled < float_of_int low || scaled > float_of_int high then
    error "a coordinate outside the supported range"
  else Ok (int_of_float scaled)

let parse_point = function
  | `List (longitude :: latitude :: _) ->
      let* lon_e6 = coordinate_e6 longitude (-180_000_000) 180_000_000 in
      let* lat_e6 = coordinate_e6 latitude (-90_000_000) 90_000_000 in
      Ok (lat_e6, lon_e6)
  | _ -> error "a geojson coordinate pair"

let parse_node_ids properties coordinate_count =
  match member "osm_node_ids" properties with
  | None -> Ok None
  | Some (`List values) when List.length values = coordinate_count ->
      let rec collect acc = function
        | [] -> Ok (Some (List.rev acc))
        | value :: rest ->
            let* id = string_of_id value in
            collect (id :: acc) rest
      in
      collect [] values
  | Some _ -> error "an osm_node_ids array with the wrong length"

let parse_direction properties =
  match member "oneway" properties with
  | None -> Ok (true, true)
  | Some (`String value) ->
      (match String.lowercase_ascii (String.trim value) with
      | "yes" | "true" | "1" -> Ok (true, false)
      | "-1" -> Ok (false, true)
      | "no" | "false" | "0" -> Ok (true, true)
      | _ -> error "an unsupported oneway value")
  | Some _ -> error "a non-string oneway value"

let parse_coordinates properties coordinates =
  let* node_ids = parse_node_ids properties (List.length coordinates) in
  let rec loop acc coordinates ids =
    match (coordinates, ids) with
    | [], None | [], Some [] -> Ok (List.rev acc)
    | coordinate :: rest, None ->
        let* lat_e6, lon_e6 = parse_point coordinate in
        let node_id = "p:" ^ string_of_int lat_e6 ^ ":" ^ string_of_int lon_e6 in
        loop ({ node_id; lat_e6; lon_e6 } :: acc) rest None
    | coordinate :: rest, Some (source_id :: remaining_ids) ->
        let* lat_e6, lon_e6 = parse_point coordinate in
        loop ({ node_id = source_id; lat_e6; lon_e6 } :: acc) rest (Some remaining_ids)
    | _ -> error "an inconsistent coordinate and node id sequence"
  in
  loop [] coordinates node_ids

let parse_feature index feature =
  if member "type" feature <> Some (`String "Feature") then
    error ("a non-Feature item at index " ^ string_of_int index)
  else
    let properties = Option.value (member "properties" feature) ~default:(`Assoc []) in
    match properties with
    | `Assoc _ ->
        (match member "highway" properties with
        | None -> Ok None
        | Some (`String highway) when String.trim highway <> "" ->
            let way_id_value =
              match member "osm_way_id" properties with
              | Some value -> Some value
              | None -> member "id" feature
            in
            let* raw_way_id =
              match way_id_value with
              | Some value -> Ok value
              | None -> Error ("I found no source way id in feature " ^ string_of_int index)
            in
            let* way_id = string_of_id raw_way_id in
            let geometry = member "geometry" feature in
            (match geometry with
            | Some geometry when member "type" geometry = Some (`String "LineString") ->
                (match member "coordinates" geometry with
                | Some (`List coordinates) when List.length coordinates >= 2 ->
                    let* points = parse_coordinates properties coordinates in
                    let* forward, reverse = parse_direction properties in
                    Ok (Some { way_id; highway; forward; reverse; points })
                | Some (`List _) -> error ("a short street line in feature " ^ string_of_int index)
                | _ -> error ("missing coordinates in feature " ^ string_of_int index))
            | _ -> error ("a non-LineString street feature " ^ string_of_int index))
        | Some _ -> error ("a non-string street type in feature " ^ string_of_int index))
    | _ -> error ("invalid properties in feature " ^ string_of_int index)

let parse_roads json =
  if member "type" json <> Some (`String "FeatureCollection") then
    error "a geojson FeatureCollection"
  else
    match member "features" json with
    | Some (`List features) when List.length features <= max_features ->
        let rec collect index roads coordinate_count = function
          | [] -> Ok (List.rev roads, coordinate_count)
          | feature :: rest ->
              let* parsed = parse_feature index feature in
              (match parsed with
              | None -> collect (index + 1) roads coordinate_count rest
              | Some road ->
                  let next_count = coordinate_count + List.length road.points in
                  if next_count > max_coordinates then error "more than 500000 input coordinates"
                  else collect (index + 1) (road :: roads) next_count rest)
        in
        collect 0 [] 0 features
    | Some (`List _) -> error "more than 10000 geojson features"
    | _ -> error "a missing geojson feature list"

let integer_square_root value =
  if value <= 0L then 0L
  else
    let rec loop estimate =
      let next = Int64.div (Int64.add estimate (Int64.div value estimate)) 2L in
      if next >= estimate then estimate else loop next
    in
    loop value

let edge_length_mm projection first second =
  let delta_lon = Int64.of_int (second.lon_e6 - first.lon_e6) in
  let delta_lat = Int64.of_int (second.lat_e6 - first.lat_e6) in
  let dx_numerator =
    Int64.mul (Int64.mul delta_lon 11_132L) (Int64.of_int projection.Graph.cos_lat_ppm)
  in
  let dx = Int64.div dx_numerator 100_000_000L in
  let dy = Int64.div (Int64.mul delta_lat 110_574L) 1_000L in
  let squared = Int64.add (Int64.mul dx dx) (Int64.mul dy dy) in
  integer_square_root squared

let from_geojson json =
  let* roads, coordinate_count = parse_roads json in
  if roads = [] then error "no street features"
  else
    let points = List.concat_map (fun road -> road.points) roads in
    let min_lat = List.fold_left (fun best point -> min best point.lat_e6) max_int points in
    let max_lat = List.fold_left (fun best point -> max best point.lat_e6) min_int points in
    let min_lon = List.fold_left (fun best point -> min best point.lon_e6) max_int points in
    let max_lon = List.fold_left (fun best point -> max best point.lon_e6) min_int points in
    if max_lat - min_lat > max_local_span_e6 || max_lon - min_lon > max_local_span_e6 then
      error "a street extract wider than 0.25 degrees"
    else
      let latitude_sum =
        List.fold_left (fun total point -> Int64.add total (Int64.of_int point.lat_e6)) 0L points
      in
      let center_lat_e6 = Int64.to_int (Int64.div latitude_sum (Int64.of_int (max 1 coordinate_count))) in
      let radians = (float_of_int center_lat_e6 /. 1_000_000.) *. 3.141592653589793 /. 180. in
      let cos_lat_ppm = int_of_float (Float.round (cos radians *. 1_000_000.)) in
      let projection = { Graph.center_lat_e6; cos_lat_ppm } in
      let node_result =
        List.fold_left
          (fun result point ->
            match result with
            | Error _ -> result
            | Ok map ->
                (match Node_map.find_opt point.node_id map with
                | None ->
                    Ok
                      (Node_map.add point.node_id
                         { Graph.id = point.node_id; lat_e6 = point.lat_e6; lon_e6 = point.lon_e6 }
                         map)
                | Some existing when existing.lat_e6 = point.lat_e6 && existing.lon_e6 = point.lon_e6 ->
                    Ok map
                | Some _ -> error ("conflicting coordinates for node " ^ point.node_id)))
          (Ok Node_map.empty) points
      in
      let* node_map = node_result in
      let build_segments road =
        let rec walk sequence acc = function
          | first :: (second :: _ as rest) ->
              let acc =
                if first.node_id = second.node_id
                   || (first.lat_e6 = second.lat_e6 && first.lon_e6 = second.lon_e6)
                then acc
                else
                  let length_mm = edge_length_mm projection first second in
                  if length_mm <= 0L then acc
                  else
                    {
                      Graph.id = road.way_id ^ ":" ^ string_of_int sequence;
                      way_id = road.way_id;
                      sequence;
                      from_node = first.node_id;
                      to_node = second.node_id;
                      highway = road.highway;
                      length_mm;
                      forward = road.forward;
                      reverse = road.reverse;
                    }
                    :: acc
              in
              walk (sequence + 1) acc rest
          | _ -> List.rev acc
        in
        walk 0 [] road.points
      in
      let segments = List.concat_map build_segments roads in
      Graph.make ~projection ~nodes:(Node_map.bindings node_map |> List.map snd) ~segments ()

let read_geojson path =
  try
    let stat = Unix.stat path in
    if stat.Unix.st_size > max_file_bytes then error "a geojson file larger than 20 mib"
    else
      let channel = open_in_bin path in
      let contents = really_input_string channel stat.Unix.st_size in
      close_in channel;
      try from_geojson (Yojson.Safe.from_string contents)
      with Yojson.Json_error _ -> error "malformed json"
  with
  | Sys_error _ -> error ("an unreadable file: " ^ path)
  | Unix.Unix_error _ -> error ("an unreadable file: " ^ path)
  | End_of_file -> error "a truncated geojson file"
