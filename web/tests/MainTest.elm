module MainTest exposing (tests)

import Expect
import Json.Decode as Decode
import Main
import Set
import Test exposing (Test, describe, test)


sampleBootstrap : Main.Bootstrap
sampleBootstrap =
    { schemaVersion = 1
    , projection = { centerLatE6 = 6510000, cosLatPpm = 993500 }
    , nodes =
        [ { id = "a", latE6 = 6510000, lonE6 = 3370000 }
        , { id = "b", latE6 = 6510001, lonE6 = 3370001 }
        ]
    , segments =
        [ { id = "way-a:0"
          , wayId = "way-a"
          , sequence = 0
          , fromNode = "a"
          , toNode = "b"
          , highway = "residential"
          , lengthMm = 12000
          , forward = True
          , reverse = True
          }
        ]
    , source =
        { name = "yaba, lagos"
        , snapshotDate = Just "2026-10-04"
        , sourceUrl = Nothing
        , attribution = Nothing
        , scenarioNote = "I use a hypothetical closure."
        }
    , analysis =
        { origin = "a"
        , destination = "b"
        , reachableNodes = 1
        , before = Just { nodeIds = [ "a", "b" ], segmentIds = [ "way-a:0" ], lengthMm = 12000 }
        , after = Nothing
        , deltaBasisPoints = Nothing
        }
    , closedSegments = [ "way-a:0" ]
    }


bootstrapJson : String
bootstrapJson =
    "{\"schema_version\":1"
        ++ ",\"projection\":{\"center_lat_e6\":6510000,\"cos_lat_ppm\":993500}"
        ++ ",\"nodes\":[{\"id\":\"a\",\"lat_e6\":6510000,\"lon_e6\":3370000},{\"id\":\"b\",\"lat_e6\":6510001,\"lon_e6\":3370001}]"
        ++ ",\"segments\":[{\"id\":\"way-a:0\",\"way_id\":\"way-a\",\"sequence\":0,\"from_node\":\"a\",\"to_node\":\"b\",\"highway\":\"residential\",\"length_mm\":12000,\"forward\":true,\"reverse\":true}]"
        ++ ",\"dataset\":{\"name\":\"yaba, lagos\",\"snapshot_date\":\"2026-10-04\",\"source_url\":null,\"attribution\":null,\"scenario_note\":\"I use a hypothetical closure.\"}"
        ++ ",\"analysis\":{\"origin\":\"a\",\"destination\":\"b\",\"reachable_nodes\":1,\"before\":{\"node_ids\":[\"a\",\"b\"],\"segment_ids\":[\"way-a:0\"],\"length_mm\":12000},\"after\":null,\"delta_basis_points\":null}"
        ++ ",\"closed_segments\":[\"way-a:0\"]}"


tests : Test
tests =
    describe "I format and update integer graph state"
        [ test "I decode the version one bootstrap contract" <|
            \_ ->
                case Decode.decodeString Main.bootstrapDecoder bootstrapJson of
                    Ok decoded ->
                        Expect.equal ( 1, "yaba, lagos", [ "way-a:0" ] )
                            ( decoded.schemaVersion, decoded.source.name, decoded.closedSegments )

                    Err problem ->
                        Expect.fail (Decode.errorToString problem)
        , test "I format a route below one kilometer" <|
            \_ ->
                Expect.equal "125 m" (Main.formatDistance 125000)
        , test "I round a longer route to tenths of a kilometer" <|
            \_ ->
                Expect.equal "1.3 km" (Main.formatDistance 1250000)
        , test "I format integer basis points without floats" <|
            \_ ->
                Expect.equal "+18.4%" (Main.formatBasisPoints 1840)
        , test "I keep two digits for small percentage fractions" <|
            \_ ->
                Expect.equal "+0.05%" (Main.formatBasisPoints 5)
        , test "I remove the selected closure as a pure state update" <|
            \_ ->
                let
                    initial =
                        Main.initState sampleBootstrap

                    ( changedModel, _ ) =
                        Main.update Main.ToggleClosure (Main.Loaded initial)
                in
                case changedModel of
                    Main.Loaded changed ->
                        Expect.equal Set.empty changed.closed

                    _ ->
                        Expect.fail "I keep the graph state loaded."
        , test "I accept a new origin without changing the closure set" <|
            \_ ->
                let
                    initial =
                        Main.initState sampleBootstrap

                    ( changedModel, _ ) =
                        Main.update (Main.ChangedOrigin "b") (Main.Loaded initial)
                in
                case changedModel of
                    Main.Loaded changed ->
                        Expect.equal ( "b", Set.fromList [ "way-a:0" ] ) ( changed.origin, changed.closed )

                    _ ->
                        Expect.fail "I keep the graph state loaded."
        , test "I ignore an older route response after an endpoint change" <|
            \_ ->
                let
                    initial =
                        Main.initState sampleBootstrap

                    ( changedModel, _ ) =
                        Main.update (Main.ChangedOrigin "b") (Main.Loaded initial)
                in
                case changedModel of
                    Main.Loaded current ->
                        let
                            ( finalModel, _ ) =
                                Main.update
                                    (Main.GotAnalysis (current.requestId - 1) (Ok sampleBootstrap.analysis))
                                    (Main.Loaded current)
                        in
                        case finalModel of
                            Main.Loaded final ->
                                Expect.equal ( "b", "a", True ) ( final.origin, final.analysis.origin, final.pending )

                            _ ->
                                Expect.fail "I keep the graph state loaded."

                    _ ->
                        Expect.fail "I keep the graph state loaded."
        ]
