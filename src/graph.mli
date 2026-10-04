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

type projection = {
  center_lat_e6 : int;
  cos_lat_ppm : int;
}

type graph

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

val make : ?projection:projection -> nodes:node list -> segments:segment list -> unit -> (graph, string) result
val projection : graph -> projection
val nodes : graph -> node list
val segments : graph -> segment list
val node : graph -> string -> node option
val analyze : graph -> origin:string -> destination:string -> closed:string list -> (analysis, string) result
val default_query : graph -> (string * string * string list, string) result
