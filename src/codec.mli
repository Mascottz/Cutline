val to_json : Graph.graph -> Yojson.Safe.t
val from_json : Yojson.Safe.t -> (Graph.graph, string) result
val read_file : string -> (Graph.graph, string) result
val write_file : string -> Graph.graph -> (unit, string) result
