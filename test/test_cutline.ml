let int64 = Alcotest.testable (fun formatter value -> Format.fprintf formatter "%Ld" value) Int64.equal

let node id lat_e6 lon_e6 : Graph.node = { id; lat_e6; lon_e6 }

let segment id sequence from_node to_node length_mm : Graph.segment =
  {
    id;
    way_id = "way-" ^ id;
    sequence;
    from_node;
    to_node;
    highway = "residential";
    length_mm;
    forward = true;
    reverse = true;
  }

let graph_or_fail nodes segments =
  match Graph.make ~nodes ~segments () with
  | Ok graph -> graph
  | Error reason -> Alcotest.fail reason

let four_node_graph () =
  graph_or_fail
    [ node "a" 0 0; node "b" 0 1; node "c" 1 0; node "d" 1 1 ]
    [ segment "a-b" 0 "a" "b" 100L;
      segment "b-d" 0 "b" "d" 100L;
      segment "a-c" 0 "a" "c" 130L;
      segment "c-d" 0 "c" "d" 130L ]

let get_analysis graph closed =
  match Graph.analyze graph ~origin:"a" ~destination:"d" ~closed with
  | Ok analysis -> analysis
  | Error reason -> Alcotest.fail reason

let test_detour () =
  let analysis = get_analysis (four_node_graph ()) [ "a-b" ] in
  Alcotest.(check int64) "I keep the baseline distance" 200L
    (Option.get analysis.Graph.before).Graph.length_mm;
  Alcotest.(check int64) "I find the longer route" 260L
    (Option.get analysis.after).Graph.length_mm;
  Alcotest.(check int64) "I report an exact integer ratio" 3_000L
    (Option.get analysis.delta_basis_points);
  Alcotest.(check (list string)) "I return stable route segments" [ "a-c"; "c-d" ]
    (Option.get analysis.after).Graph.segment_ids;
  Alcotest.(check int) "I count reachable nodes after closure" 4 analysis.reachable_nodes

let test_disconnection () =
  let analysis = get_analysis (four_node_graph ()) [ "a-b"; "a-c" ] in
  Alcotest.(check (option int64)) "I expose no remaining route" None
    (Option.map (fun route -> route.Graph.length_mm) analysis.after);
  Alcotest.(check int) "I keep the origin reachable" 1 analysis.reachable_nodes

let test_one_way () =
  let graph =
    graph_or_fail [ node "a" 0 0; node "b" 0 1 ]
      [ { (segment "only-forward" 0 "a" "b" 50L) with reverse = false } ]
  in
  match Graph.analyze graph ~origin:"b" ~destination:"a" ~closed:[] with
  | Error reason -> Alcotest.fail reason
  | Ok analysis ->
      Alcotest.(check (option int64)) "I preserve one-way direction" None
        (Option.map (fun route -> route.Graph.length_mm) analysis.before);
      Alcotest.(check int) "I count only the origin" 1 analysis.reachable_nodes

let test_equal_cost_tie () =
  let graph =
    graph_or_fail
      [ node "a" 0 0; node "b" 0 1; node "c" 1 0; node "d" 1 1 ]
      [ segment "a-c" 0 "a" "c" 10L;
        segment "c-d" 0 "c" "d" 10L;
        segment "a-b" 0 "a" "b" 10L;
        segment "b-d" 0 "b" "d" 10L ]
  in
  match Graph.analyze graph ~origin:"a" ~destination:"d" ~closed:[] with
  | Error reason -> Alcotest.fail reason
  | Ok analysis ->
      Alcotest.(check (list string)) "I choose the same tied route" [ "a-b"; "b-d" ]
        (Option.get analysis.before).Graph.segment_ids

let test_bad_closure () =
  match Graph.analyze (four_node_graph ()) ~origin:"a" ~destination:"d" ~closed:[ "missing" ] with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "I reject an unknown closure id"

let test_import_and_roundtrip () =
  match Import.read_geojson "fixtures/mini.geojson" with
  | Error reason -> Alcotest.fail reason
  | Ok graph ->
      Alcotest.(check int) "I read two fixture nodes" 2 (List.length (Graph.nodes graph));
      Alcotest.(check int) "I read one fixture segment" 1 (List.length (Graph.segments graph));
      (match Codec.from_json (Codec.to_json graph) with
      | Error reason -> Alcotest.fail reason
      | Ok copy ->
          Alcotest.(check int) "I round-trip every node" (List.length (Graph.nodes graph))
            (List.length (Graph.nodes copy));
          Alcotest.(check int) "I round-trip every segment" (List.length (Graph.segments graph))
            (List.length (Graph.segments copy)))

let test_yaba_extract () =
  match Import.read_geojson "../data/demo/yaba.geojson" with
  | Error reason -> Alcotest.fail reason
  | Ok graph ->
      Alcotest.(check int) "I keep the frozen node count" 1_513 (List.length (Graph.nodes graph));
      Alcotest.(check int) "I keep the frozen segment count" 1_555 (List.length (Graph.segments graph));
      (match Graph.default_query graph with
      | Error reason -> Alcotest.fail reason
      | Ok (origin, destination, closed) ->
          Alcotest.(check bool) "I choose a usable origin" true (Graph.node graph origin <> None);
          Alcotest.(check bool) "I choose a usable destination" true (Graph.node graph destination <> None);
          Alcotest.(check bool) "I start with one visible closure" true (List.length closed = 1))

let () =
  Alcotest.run "cutline"
    [ ( "graph",
        [ Alcotest.test_case "I route around a closed segment" `Quick test_detour;
          Alcotest.test_case "I report a disconnected destination" `Quick test_disconnection;
          Alcotest.test_case "I preserve one-way direction" `Quick test_one_way;
          Alcotest.test_case "I resolve equal-cost routes" `Quick test_equal_cost_tie;
          Alcotest.test_case "I reject an unknown closure" `Quick test_bad_closure ] );
      ( "import",
        [ Alcotest.test_case "I import and round-trip geojson" `Quick test_import_and_roundtrip;
          Alcotest.test_case "I verify the frozen yaba graph" `Quick test_yaba_extract ] ) ]
