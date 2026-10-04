val run :
  graph:Graph.graph ->
  source:Yojson.Safe.t ->
  initial:(string * string * string list) ->
  assets_dir:string ->
  port:int ->
  unit
