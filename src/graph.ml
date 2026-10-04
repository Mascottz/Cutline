module StringMap = Map.Make (String)
module StringSet = Set.Make (String)

type node = {
  id : string;
  lat_e6 : int;
  lon_e6 : int;
}

type segment = {
  id : string;
  way_id : string;
  sequence : int;
  from_node : string;
  to_node : string;
  highway : string;
  length_mm : int64;
  forward : bool;
  reverse : bool;
}

type arc = {
  id : string;
  segment_id : string;
  from_node : string;
  to_node : string;
  length_mm : int64;
}

type projection = {
  center_lat_e6 : int;
  cos_lat_ppm : int;
}

type graph = {
  node_map : node StringMap.t;
  segment_list : segment list;
  outgoing : arc list StringMap.t;
  projection : projection;
}

type route = {
  node_ids : string list;
  segment_ids : string list;
  length_mm : int64;
}

type analysis = {
  origin : string;
  destination : string;
  reachable_nodes : int;
  before : route option;
  after : route option;
  delta_basis_points : int64 option;
}

let max_nodes = 100_000
let max_segments = 100_000
let max_segment_length_mm = 1_000_000_000L

let error text = Error ("I found " ^ text)

let make ?projection ~nodes ~segments () =
  let projection =
    Option.value projection ~default:{ center_lat_e6 = 0; cos_lat_ppm = 1_000_000 }
  in
  if projection.center_lat_e6 < -90_000_000 || projection.center_lat_e6 > 90_000_000 then
    error "an invalid projection center"
  else if projection.cos_lat_ppm < 0 || projection.cos_lat_ppm > 1_000_000 then
    error "an invalid fixed-point longitude scale"
  else if List.length nodes > max_nodes then error "more than 100000 graph nodes"
  else if List.length segments > max_segments then error "more than 100000 street segments"
  else
    let node_result =
      List.fold_left
        (fun result (item : node) ->
          match result with
          | Error _ -> result
          | Ok map ->
              if String.trim item.id = "" then error "an empty node id"
              else if item.lat_e6 < -90_000_000 || item.lat_e6 > 90_000_000 then
                error ("an invalid latitude for node " ^ item.id)
              else if item.lon_e6 < -180_000_000 || item.lon_e6 > 180_000_000 then
                error ("an invalid longitude for node " ^ item.id)
              else if StringMap.mem item.id map then
                error ("a duplicate node id: " ^ item.id)
              else Ok (StringMap.add item.id item map))
        (Ok StringMap.empty) nodes
    in
    match node_result with
    | Error _ as failure -> failure
    | Ok node_map ->
        let segment_result =
          List.fold_left
            (fun result (item : segment) ->
              match result with
              | Error _ -> result
              | Ok (seen, ordered, arcs) ->
                  let invalid =
                    if String.trim item.id = "" then Some "an empty segment id"
                    else if String.trim item.way_id = "" then Some "an empty source way id"
                    else if item.sequence < 0 then Some ("a negative segment index: " ^ item.id)
                    else if String.trim item.highway = "" then Some ("a missing street type: " ^ item.id)
                    else if item.length_mm <= 0L then Some ("a nonpositive route weight: " ^ item.id)
                    else if item.length_mm > max_segment_length_mm then Some ("an oversized route weight: " ^ item.id)
                    else if item.from_node = item.to_node then Some ("a segment with identical endpoints: " ^ item.id)
                    else if not item.forward && not item.reverse then Some ("a segment with no permitted direction: " ^ item.id)
                    else if not (StringMap.mem item.from_node node_map) then Some ("a missing start node for segment " ^ item.id)
                    else if not (StringMap.mem item.to_node node_map) then Some ("a missing end node for segment " ^ item.id)
                    else if StringMap.mem item.id seen then Some ("a duplicate segment id: " ^ item.id)
                    else None
                  in
                  match invalid with
                  | Some reason -> error reason
                  | None ->
                      let seen = StringMap.add item.id item seen in
                      let add_arc direction source target arcs =
                        let arc =
                          {
                            id = item.id ^ ":" ^ direction;
                            segment_id = item.id;
                            from_node = source;
                            to_node = target;
                            length_mm = item.length_mm;
                          }
                        in
                        arc :: arcs
                      in
                      let arcs =
                        let arcs =
                          if item.forward then add_arc "f" item.from_node item.to_node arcs else arcs
                        in
                        if item.reverse then add_arc "r" item.to_node item.from_node arcs else arcs
                      in
                      Ok (seen, item :: ordered, arcs))
            (Ok (StringMap.empty, [], [])) segments
        in
        (match segment_result with
        | Error _ as failure -> failure
        | Ok (_, ordered, arcs) ->
            let outgoing =
              List.fold_left
                (fun map arc ->
                  let existing = Option.value (StringMap.find_opt arc.from_node map) ~default:[] in
                  StringMap.add arc.from_node (arc :: existing) map)
                StringMap.empty arcs
              |> StringMap.map (List.sort (fun left right -> String.compare left.id right.id))
            in
            Ok
              {
                node_map;
                segment_list = List.sort (fun (left : segment) (right : segment) -> String.compare left.id right.id) ordered;
                outgoing;
                projection;
              })

let projection graph = graph.projection
let nodes graph = StringMap.bindings graph.node_map |> List.map snd
let segments graph = graph.segment_list
let node graph id = StringMap.find_opt id graph.node_map

module Work = Set.Make (struct
  type t = int64 * string list * string

  let compare (left_distance, left_path, left_node) (right_distance, right_path, right_node) =
    let by_distance = Int64.compare left_distance right_distance in
    if by_distance <> 0 then by_distance
    else
      let by_path = Stdlib.compare left_path right_path in
      if by_path <> 0 then by_path else String.compare left_node right_node
end)

let shortest_path graph ~origin ~destination ~closed =
  let first = (0L, [], origin) in
  let rec search pending best previous =
    match Work.min_elt_opt pending with
    | None -> Ok None
    | Some ((distance, path_key, current) as state) ->
        let pending = Work.remove state pending in
        let current_best = StringMap.find_opt current best in
        if current_best <> Some (distance, path_key) then search pending best previous
        else if current = destination then
          let rec trace current node_acc segment_acc =
            if current = origin then Some (origin :: node_acc, segment_acc)
            else
              match StringMap.find_opt current previous with
              | None -> None
              | Some arc -> trace arc.from_node (current :: node_acc) (arc.segment_id :: segment_acc)
          in
          (match trace destination [] [] with
          | None -> error "a broken predecessor chain"
          | Some (node_ids, segment_ids) ->
              Ok (Some { node_ids; segment_ids; length_mm = distance }))
        else
          let arcs = Option.value (StringMap.find_opt current graph.outgoing) ~default:[] in
          let updates =
            List.fold_left
              (fun (queue, distances, predecessors, failure) arc ->
                match failure with
                | Some _ -> (queue, distances, predecessors, failure)
                | None when StringSet.mem arc.segment_id closed ->
                    (queue, distances, predecessors, None)
                | None ->
                    if arc.length_mm > Int64.sub Int64.max_int distance then
                      (queue, distances, predecessors, Some "a route distance overflow")
                    else
                      let candidate_distance = Int64.add distance arc.length_mm in
                      let candidate_path = path_key @ [ arc.id ] in
                      let improves =
                        match StringMap.find_opt arc.to_node distances with
                        | None -> true
                        | Some (old_distance, old_path) ->
                            candidate_distance < old_distance
                            || (candidate_distance = old_distance && Stdlib.compare candidate_path old_path < 0)
                      in
                      if improves then
                        ( Work.add (candidate_distance, candidate_path, arc.to_node) queue,
                          StringMap.add arc.to_node (candidate_distance, candidate_path) distances,
                          StringMap.add arc.to_node arc predecessors,
                          None )
                      else (queue, distances, predecessors, None))
              (pending, best, previous, None) arcs
          in
          let queue, distances, predecessors, failure = updates in
          (match failure with
          | Some reason -> error reason
          | None -> search queue distances predecessors)
  in
  search (Work.singleton first) (StringMap.singleton origin (0L, [])) StringMap.empty

let reachable_count graph ~origin ~closed =
  let found = ref (StringSet.singleton origin) in
  let queue = Queue.create () in
  Queue.add origin queue;
  while not (Queue.is_empty queue) do
    let current = Queue.take queue in
    let arcs = Option.value (StringMap.find_opt current graph.outgoing) ~default:[] in
    List.iter
      (fun arc ->
        if not (StringSet.mem arc.segment_id closed) && not (StringSet.mem arc.to_node !found) then (
          found := StringSet.add arc.to_node !found;
          Queue.add arc.to_node queue))
      arcs
  done;
  StringSet.cardinal !found

let analyze graph ~origin ~destination ~closed =
  if not (StringMap.mem origin graph.node_map) then error ("an unknown origin id: " ^ origin)
  else if not (StringMap.mem destination graph.node_map) then error ("an unknown destination id: " ^ destination)
  else
    let unknown = List.find_opt (fun id -> not (List.exists (fun (segment : segment) -> segment.id = id) graph.segment_list)) closed in
    match unknown with
    | Some id -> error ("an unknown closure id: " ^ id)
    | None ->
        let closed = List.fold_left (fun set id -> StringSet.add id set) StringSet.empty closed in
        (match shortest_path graph ~origin ~destination ~closed:StringSet.empty with
        | Error _ as failure -> failure
        | Ok before ->
            match shortest_path graph ~origin ~destination ~closed with
            | Error _ as failure -> failure
            | Ok after ->
                let delta_basis_points =
                  match (before, after) with
                  | Some baseline, Some changed when baseline.length_mm > 0L ->
                      let delta = Int64.max 0L (Int64.sub changed.length_mm baseline.length_mm) in
                      Some (Int64.div (Int64.mul delta 10_000L) baseline.length_mm)
                  | _ -> None
                in
                Ok
                  {
                    origin;
                    destination;
                    reachable_nodes = reachable_count graph ~origin ~closed;
                    before;
                    after;
                    delta_basis_points;
                  })

let compare_coordinate (left : node) (right : node) =
  let latitude = Int.compare left.lat_e6 right.lat_e6 in
  if latitude <> 0 then latitude
  else
    let longitude = Int.compare left.lon_e6 right.lon_e6 in
    if longitude <> 0 then longitude else String.compare left.id right.id

let default_query graph =
  let all_nodes = nodes graph in
  if List.length all_nodes < 2 then error "fewer than two graph nodes"
  else
    let ordered = List.sort compare_coordinate all_nodes in
    let by_longitude =
      List.sort
        (fun (left : node) (right : node) ->
          let longitude = Int.compare left.lon_e6 right.lon_e6 in
          if longitude <> 0 then longitude else compare_coordinate left right)
        all_nodes
    in
    let extremes : node list =
      [ List.hd ordered; List.hd (List.rev ordered); List.hd by_longitude; List.hd (List.rev by_longitude) ]
      |> List.sort_uniq (fun (left : node) (right : node) -> String.compare left.id right.id)
    in
    let pairs =
      List.concat_map
        (fun (origin : node) ->
          List.filter_map
            (fun (destination : node) ->
              if origin.id = destination.id then None else Some (origin.id, destination.id))
            extremes)
        extremes
    in
    let best_pair =
      List.fold_left
        (fun best (origin, destination) ->
          match shortest_path graph ~origin ~destination ~closed:StringSet.empty with
          | Error _ | Ok None -> best
          | Ok (Some route) when route.length_mm <= 0L -> best
          | Ok (Some route) ->
              (match best with
              | None -> Some (origin, destination, route)
              | Some (old_origin, old_destination, old_route) ->
                  if route.length_mm > old_route.length_mm
                     || (route.length_mm = old_route.length_mm
                         && (String.compare origin old_origin < 0
                            || (origin = old_origin && String.compare destination old_destination < 0)))
                  then Some (origin, destination, route)
                  else best))
        None pairs
    in
    match best_pair with
    | None -> error "a connected origin and destination pair"
    | Some (origin, destination, baseline) ->
        let detour = ref None in
        let disconnection = ref None in
        baseline.segment_ids
        |> List.sort_uniq String.compare
        |> List.iter (fun segment_id ->
               let closed = StringSet.singleton segment_id in
               match shortest_path graph ~origin ~destination ~closed with
               | Error _ -> ()
               | Ok None -> if !disconnection = None then disconnection := Some segment_id
               | Ok (Some changed) ->
                   let increase = Int64.sub changed.length_mm baseline.length_mm in
                   if increase > 0L then
                     match !detour with
                     | None -> detour := Some (segment_id, increase)
                     | Some (old_id, old_increase) ->
                         if increase > old_increase
                            || (increase = old_increase && String.compare segment_id old_id < 0)
                         then detour := Some (segment_id, increase));
        (match !detour with
        | Some (segment_id, _) -> Ok (origin, destination, [ segment_id ])
        | None ->
            match !disconnection with
            | Some segment_id -> Ok (origin, destination, [ segment_id ])
            | None -> Ok (origin, destination, []))
