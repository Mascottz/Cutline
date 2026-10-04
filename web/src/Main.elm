module Main exposing
    ( Analysis
    , Bootstrap
    , Model(..)
    , Msg(..)
    , State
    , bootstrapDecoder
    , formatBasisPoints
    , formatDistance
    , initState
    , main
    , update
    )

import Browser
import Dict
import Html exposing (Html, button, dd, div, dl, dt, figcaption, figure, footer, h1, h2, header, label, main_, option, p, section, select, span, text)
import Html.Attributes as H
import Html.Events as E
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Set exposing (Set)
import Svg as S
import Svg.Attributes as A
import Svg.Events as SE


type alias Node =
    { id : String
    , latE6 : Int
    , lonE6 : Int
    }


type alias Segment =
    { id : String
    , wayId : String
    , sequence : Int
    , fromNode : String
    , toNode : String
    , highway : String
    , lengthMm : Int
    , forward : Bool
    , reverse : Bool
    }


type alias Projection =
    { centerLatE6 : Int
    , cosLatPpm : Int
    }


type alias Source =
    { name : String
    , snapshotDate : Maybe String
    , sourceUrl : Maybe String
    , attribution : Maybe String
    , scenarioNote : String
    }


type alias Route =
    { nodeIds : List String
    , segmentIds : List String
    , lengthMm : Int
    }


type alias Analysis =
    { origin : String
    , destination : String
    , reachableNodes : Int
    , before : Maybe Route
    , after : Maybe Route
    , deltaBasisPoints : Maybe Int
    }


type alias Bootstrap =
    { schemaVersion : Int
    , projection : Projection
    , nodes : List Node
    , segments : List Segment
    , source : Source
    , analysis : Analysis
    , closedSegments : List String
    }


type alias GraphData =
    { projection : Projection
    , nodes : List Node
    , segments : List Segment
    }


type alias MapBounds =
    { minLat : Int
    , maxLat : Int
    , minLon : Int
    , maxLon : Int
    , cosLatPpm : Int
    , spanXmm : Float
    , spanYmm : Float
    }


type alias State =
    { graph : GraphData
    , source : Source
    , origin : String
    , destination : String
    , closed : Set String
    , selectedSegment : Maybe String
    , analysis : Analysis
    , requestId : Int
    , pending : Bool
    , error : Maybe String
    }


type Model
    = Loading
    | LoadFailed String
    | Loaded State


type Msg
    = GotBootstrap (Result Http.Error Bootstrap)
    | ChangedOrigin String
    | ChangedDestination String
    | ChangedSegment String
    | ToggleClosure
    | GotAnalysis Int (Result Http.Error Analysis)


nodeDecoder : Decode.Decoder Node
nodeDecoder =
    Decode.map3
        (\id latE6 lonE6 ->
            { id = id, latE6 = latE6, lonE6 = lonE6 }
        )
        (Decode.field "id" Decode.string)
        (Decode.field "lat_e6" Decode.int)
        (Decode.field "lon_e6" Decode.int)


segmentDecoder : Decode.Decoder Segment
segmentDecoder =
    Decode.map4
        (\id wayId sequence fromNode ->
            { id = id
            , wayId = wayId
            , sequence = sequence
            , fromNode = fromNode
            , toNode = ""
            , highway = ""
            , lengthMm = 0
            , forward = False
            , reverse = False
            }
        )
        (Decode.field "id" Decode.string)
        (Decode.field "way_id" Decode.string)
        (Decode.field "sequence" Decode.int)
        (Decode.field "from_node" Decode.string)
        |> Decode.andThen
            (\partial ->
                Decode.map5
                    (\toNode highway lengthMm forward reverse ->
                        { partial
                            | toNode = toNode
                            , highway = highway
                            , lengthMm = lengthMm
                            , forward = forward
                            , reverse = reverse
                        }
                    )
                    (Decode.field "to_node" Decode.string)
                    (Decode.field "highway" Decode.string)
                    (Decode.field "length_mm" Decode.int)
                    (Decode.field "forward" Decode.bool)
                    (Decode.field "reverse" Decode.bool)
            )


projectionDecoder : Decode.Decoder Projection
projectionDecoder =
    Decode.map2
        (\centerLatE6 cosLatPpm ->
            { centerLatE6 = centerLatE6, cosLatPpm = cosLatPpm }
        )
        (Decode.field "center_lat_e6" Decode.int)
        (Decode.field "cos_lat_ppm" Decode.int)


sourceDecoder : Decode.Decoder Source
sourceDecoder =
    Decode.map5
        (\name snapshotDate sourceUrl attribution scenarioNote ->
            { name = name
            , snapshotDate = snapshotDate
            , sourceUrl = sourceUrl
            , attribution = attribution
            , scenarioNote = scenarioNote
            }
        )
        (Decode.field "name" Decode.string)
        (Decode.field "snapshot_date" (Decode.nullable Decode.string))
        (Decode.field "source_url" (Decode.nullable Decode.string))
        (Decode.field "attribution" (Decode.nullable Decode.string))
        (Decode.field "scenario_note" Decode.string)


routeDecoder : Decode.Decoder Route
routeDecoder =
    Decode.map3
        (\nodeIds segmentIds lengthMm ->
            { nodeIds = nodeIds, segmentIds = segmentIds, lengthMm = lengthMm }
        )
        (Decode.field "node_ids" (Decode.list Decode.string))
        (Decode.field "segment_ids" (Decode.list Decode.string))
        (Decode.field "length_mm" Decode.int)


analysisDecoder : Decode.Decoder Analysis
analysisDecoder =
    Decode.map6
        (\origin destination reachableNodes before after deltaBasisPoints ->
            { origin = origin
            , destination = destination
            , reachableNodes = reachableNodes
            , before = before
            , after = after
            , deltaBasisPoints = deltaBasisPoints
            }
        )
        (Decode.field "origin" Decode.string)
        (Decode.field "destination" Decode.string)
        (Decode.field "reachable_nodes" Decode.int)
        (Decode.field "before" (Decode.nullable routeDecoder))
        (Decode.field "after" (Decode.nullable routeDecoder))
        (Decode.field "delta_basis_points" (Decode.nullable Decode.int))


bootstrapDecoder : Decode.Decoder Bootstrap
bootstrapDecoder =
    Decode.field "schema_version" Decode.int
        |> Decode.andThen
            (\version ->
                if version /= 1 then
                    Decode.fail "I found a graph schema outside version 1."

                else
                    Decode.map6
                        (\projection nodes segments source analysis closedSegments ->
                            { schemaVersion = version
                            , projection = projection
                            , nodes = nodes
                            , segments = segments
                            , source = source
                            , analysis = analysis
                            , closedSegments = closedSegments
                            }
                        )
                        (Decode.field "projection" projectionDecoder)
                        (Decode.field "nodes" (Decode.list nodeDecoder))
                        (Decode.field "segments" (Decode.list segmentDecoder))
                        (Decode.field "dataset" sourceDecoder)
                        (Decode.field "analysis" analysisDecoder)
                        (Decode.field "closed_segments" (Decode.list Decode.string))
            )


initState : Bootstrap -> State
initState bootstrap =
    let
        selected =
            case List.head bootstrap.closedSegments of
                Just segmentId ->
                    Just segmentId

                Nothing ->
                    List.head (List.map .id bootstrap.segments)
    in
    { graph =
        { projection = bootstrap.projection
        , nodes = bootstrap.nodes
        , segments = bootstrap.segments
        }
    , source = bootstrap.source
    , origin = bootstrap.analysis.origin
    , destination = bootstrap.analysis.destination
    , closed = Set.fromList bootstrap.closedSegments
    , selectedSegment = selected
    , analysis = bootstrap.analysis
    , requestId = 0
    , pending = False
    , error = Nothing
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading
    , Http.get
        { url = "/api/bootstrap"
        , expect = Http.expectJson GotBootstrap bootstrapDecoder
        }
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case ( message, model ) of
        ( GotBootstrap (Ok bootstrap), _ ) ->
            ( Loaded (initState bootstrap), Cmd.none )

        ( GotBootstrap (Err reason), _ ) ->
            ( LoadFailed (httpErrorText reason)
            , Cmd.none
            )

        ( ChangedOrigin origin, Loaded state ) ->
            let
                changed =
                    { state
                        | origin = origin
                        , requestId = state.requestId + 1
                        , pending = True
                        , error = Nothing
                    }
            in
            ( Loaded changed, requestAnalysis changed )

        ( ChangedDestination destination, Loaded state ) ->
            let
                changed =
                    { state
                        | destination = destination
                        , requestId = state.requestId + 1
                        , pending = True
                        , error = Nothing
                    }
            in
            ( Loaded changed, requestAnalysis changed )

        ( ChangedSegment segmentId, Loaded state ) ->
            ( Loaded { state | selectedSegment = Just segmentId }, Cmd.none )

        ( ToggleClosure, Loaded state ) ->
            case state.selectedSegment of
                Nothing ->
                    ( Loaded state, Cmd.none )

                Just segmentId ->
                    let
                        nextClosed =
                            if Set.member segmentId state.closed then
                                Set.remove segmentId state.closed

                            else
                                Set.insert segmentId state.closed

                        changed =
                            { state
                                | closed = nextClosed
                                , requestId = state.requestId + 1
                                , pending = True
                                , error = Nothing
                            }
                    in
                    ( Loaded changed, requestAnalysis changed )

        ( GotAnalysis requestId (Ok analysis), Loaded state ) ->
            if requestId == state.requestId then
                ( Loaded { state | analysis = analysis, pending = False, error = Nothing }
                , Cmd.none
                )

            else
                ( Loaded state, Cmd.none )

        ( GotAnalysis requestId (Err reason), Loaded state ) ->
            if requestId == state.requestId then
                ( Loaded
                    { state
                        | pending = False
                        , error = Just (httpErrorText reason)
                    }
                , Cmd.none
                )

            else
                ( Loaded state, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )


requestAnalysis : State -> Cmd Msg
requestAnalysis state =
    Http.post
        { url = "/api/analyze"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "origin", Encode.string state.origin )
                    , ( "destination", Encode.string state.destination )
                    , ( "closed", Encode.list Encode.string (Set.toList state.closed) )
                    ]
                )
        , expect = Http.expectJson (GotAnalysis state.requestId) analysisDecoder
        }


formatDistance : Int -> String
formatDistance lengthMm =
    if lengthMm < 0 then
        "not available"

    else if lengthMm < 1000000 then
        String.fromInt ((lengthMm + 500) // 1000) ++ " m"

    else
        let
            tenths =
                (lengthMm + 50000) // 100000
        in
        String.fromInt (tenths // 10) ++ "." ++ String.fromInt (modBy 10 tenths) ++ " km"


formatBasisPoints : Int -> String
formatBasisPoints value =
    let
        absolute =
            abs value

        whole =
            absolute // 100

        remainder =
            modBy 100 absolute

        sign =
            if value < 0 then
                "−"

            else
                "+"

        fraction =
            if remainder == 0 then
                ""

            else if modBy 10 remainder == 0 then
                "." ++ String.fromInt (remainder // 10)

            else if remainder < 10 then
                ".0" ++ String.fromInt remainder

            else
                "." ++ String.fromInt remainder
    in
    sign ++ String.fromInt whole ++ fraction ++ "%"


formatCoordinate : Int -> String
formatCoordinate value =
    let
        absolute =
            abs value

        whole =
            absolute // 1000000

        fraction =
            String.fromInt (modBy 1000000 absolute)
                |> String.padLeft 6 '0'
    in
    (if value < 0 then "−" else "") ++ String.fromInt whole ++ "." ++ fraction


nodeLabel : Node -> String
nodeLabel node =
    node.id ++ " · " ++ formatCoordinate node.latE6 ++ ", " ++ formatCoordinate node.lonE6


segmentLabel : Segment -> String
segmentLabel segment =
    "way " ++ segment.wayId ++ " · " ++ segment.highway ++ " · segment " ++ String.fromInt segment.sequence


httpErrorText : Http.Error -> String
httpErrorText error =
    case error of
        Http.BadUrl _ ->
            "I found an invalid local route."

        Http.Timeout ->
            "I could not reach the local route service."

        Http.NetworkError ->
            "I could not reach the local route service."

        Http.BadStatus status ->
            "I found a local response with status " ++ String.fromInt status ++ "."

        Http.BadBody _ ->
            "I could not read the local route response."


view : Model -> Html Msg
view model =
    case model of
        Loading ->
            main_ [ H.class "shell loading" ]
                [ p [ H.class "loading-note" ] [ text "I am loading the frozen street graph." ] ]

        LoadFailed reason ->
            main_ [ H.class "shell loading" ]
                [ h1 [] [ text "CutLine" ]
                , p [ H.class "error-note" ] [ text reason ]
                ]

        Loaded state ->
            viewReady state


viewReady : State -> Html Msg
viewReady state =
    main_ [ H.class "shell" ]
        [ header [ H.class "masthead" ]
            [ p [ H.class "eyebrow" ] [ text "I close a street, then measure the detour." ]
            , h1 [] [ text "CutLine" ]
            , p [ H.class "lede" ]
                [ text "I work from a frozen street graph; i do not predict live traffic." ]
            , div [ H.class "dataset-line" ]
                [ span [ H.class "dataset-name" ] [ text state.source.name ]
                , span [ H.class "dataset-date" ]
                    [ text (Maybe.withDefault "local extract" state.source.snapshotDate) ]
                ]
            ]
        , section [ H.class "atlas" ]
            [ figure [ H.class "map-figure", H.attribute "aria-label" "I compare routes in the selected street graph." ]
                [ viewMap state
                , figcaption [ H.class "map-caption" ]
                    [ p [] [ text "I show graph distance only; i draw no live traffic or street status." ]
                    , p [ H.class "credit" ]
                        [ text "I credit "
                        , Html.a
                            [ H.href "https://www.openstreetmap.org/copyright"
                            , H.target "_blank"
                            , H.rel "noopener noreferrer"
                            ]
                            [ text "openstreetmap contributors" ]
                        , text "; i keep the data under odbl 1.0."
                        , text " i follow "
                        , Html.a
                            [ H.href "https://osmfoundation.org/wiki/Licence/Attribution_Guidelines"
                            , H.target "_blank"
                            , H.rel "noopener noreferrer"
                            ]
                            [ text "the attribution guidance" ]
                        , text "."
                        ]
                    ]
                ]
            , section [ H.class "readout" ]
                [ h2 [] [ text "I read the route change" ]
                , measureStrip state
                , viewStatus state
                ]
            , div [ H.class "atlas-rail" ]
                [ section [ H.class "legend-strip", H.attribute "aria-label" "map key" ]
                    [ legendItem "baseline route" "legend-baseline"
                    , legendItem "route after closure" "legend-after"
                    , legendItem "hypothetical closure" "legend-closed"
                    ]
                , section [ H.class "controls" ]
                    [ h2 [] [ text "I choose the graph experiment" ]
                    , p [ H.class "rail-note" ] [ text "I begin with one hypothetical closure; i can change the endpoints or segment." ]
                    , div [ H.class "control-grid" ]
                        [ nodeControl "origin node" state.origin ChangedOrigin state.graph.nodes
                        , nodeControl "destination node" state.destination ChangedDestination state.graph.nodes
                        , segmentControl state
                        ]
                    , button
                        [ H.class "text-button"
                        , H.type_ "button"
                        , E.onClick ToggleClosure
                        , H.disabled (state.pending || state.selectedSegment == Nothing)
                        ]
                        [ text (toggleLabel state) ]
                    , Maybe.map (\message -> p [ H.class "error-note", H.attribute "role" "alert" ] [ text message ]) state.error
                        |> Maybe.withDefault (text "")
                    ]
                ]
            ]
        , footer [ H.class "colophon" ]
            [ p [] [ text state.source.scenarioNote ]
            , p [ H.class "colophon-note" ]
                [ text "I store no account data; i fetch nothing outside this local atlas while it is open." ]
            ]
        ]


legendItem : String -> String -> Html Msg
legendItem labelText styleName =
    div [ H.class "legend-item" ]
        [ span [ H.class ("legend-mark " ++ styleName), H.attribute "aria-hidden" "true" ] []
        , span [] [ text labelText ]
        ]


measureStrip : State -> Html Msg
measureStrip state =
    let
        baseline =
            state.analysis.before
                |> Maybe.map (.lengthMm >> formatDistance)
                |> Maybe.withDefault "no baseline route"

        changed =
            state.analysis.after
                |> Maybe.map (.lengthMm >> formatDistance)
                |> Maybe.withDefault "no route after closure"

        delta =
            state.analysis.deltaBasisPoints
                |> Maybe.map formatBasisPoints
                |> Maybe.withDefault "not comparable"
    in
    dl [ H.class "measure-grid" ]
        [ div [ H.class "measure" ] [ dt [] [ text "baseline distance" ], dd [ H.class "number" ] [ text baseline ] ]
        , div [ H.class "measure" ] [ dt [] [ text "changed distance" ], dd [ H.class "number" ] [ text changed ] ]
        , div [ H.class "measure" ] [ dt [] [ text "detour change" ], dd [ H.class "number" ] [ text delta ] ]
        , div [ H.class "measure" ] [ dt [] [ text "reachable nodes" ], dd [ H.class "number" ] [ text (String.fromInt state.analysis.reachableNodes) ] ]
        ]


viewStatus : State -> Html Msg
viewStatus state =
    let
        routeText =
            if state.pending then
                "i am recalculating this graph."

            else if state.error /= Nothing then
                "i keep the previous result because the latest query failed."

            else
                case state.analysis.after of
                    Nothing ->
                        "i find no route after this closure."

                    Just _ ->
                        "i find a route under the current closure set."
    in
    p [ H.class "status-line", H.attribute "aria-live" "polite" ]
        [ text
            ("I compare "
                ++ state.origin
                ++ " with "
                ++ state.destination
                ++ "; "
                ++ routeText
            )
        ]


nodeControl : String -> String -> (String -> Msg) -> List Node -> Html Msg
nodeControl labelText selectedId message nodes =
    label [ H.class "control" ]
        [ span [ H.class "control-label" ] [ text labelText ]
        , select [ H.value selectedId, E.onInput message ]
            (List.map
                (\node ->
                    option [ H.value node.id, H.selected (node.id == selectedId) ]
                        [ text (nodeLabel node) ]
                )
                nodes
            )
        ]


segmentControl : State -> Html Msg
segmentControl state =
    label [ H.class "control" ]
        [ span [ H.class "control-label" ] [ text "street segment" ]
        , select
            [ H.value (Maybe.withDefault "" state.selectedSegment)
            , E.onInput ChangedSegment
            ]
            (List.map
                (\segment ->
                    option [ H.value segment.id, H.selected (Just segment.id == state.selectedSegment) ]
                        [ text (segmentLabel segment) ]
                )
                state.graph.segments
            )
        ]


toggleLabel : State -> String
toggleLabel state =
    if state.pending then
        "I am recalculating this scenario"

    else
        case state.selectedSegment of
            Nothing ->
                "I need a selected street segment"

            Just segmentId ->
                if Set.member segmentId state.closed then
                    "I reopen the selected segment"

                else
                    "I close the selected segment"


viewMap : State -> Html Msg
viewMap state =
    let
        bounds =
            mapBounds state.graph.projection state.graph.nodes

        positions =
            Dict.fromList
                (List.map (\node -> ( node.id, mapPosition bounds node )) state.graph.nodes)

        position id =
            Dict.get id positions |> Maybe.withDefault ( 0, 0 )

        baseLines =
            List.map
                (\segment ->
                    segmentLine "network-segment" segment position (Just (ChangedSegment segment.id))
                )
                state.graph.segments

        beforeIds =
            state.analysis.before |> Maybe.map .segmentIds |> Maybe.withDefault []

        afterIds =
            state.analysis.after |> Maybe.map .segmentIds |> Maybe.withDefault []

        beforeLines =
            state.graph.segments
                |> List.filter (\segment -> List.member segment.id beforeIds)
                |> List.map (\segment -> segmentLine "baseline-segment" segment position Nothing)

        afterLines =
            state.graph.segments
                |> List.filter (\segment -> List.member segment.id afterIds)
                |> List.map (\segment -> segmentLine "after-segment" segment position Nothing)

        closedSegments =
            List.filter (\segment -> Set.member segment.id state.closed) state.graph.segments

        closedLines =
            List.map (\segment -> segmentLine "closed-segment" segment position Nothing) closedSegments

        closureMarks =
            List.map (\segment -> closureMark segment position) closedSegments

        selectedLines =
            state.graph.segments
                |> List.filter (\segment -> Just segment.id == state.selectedSegment)
                |> List.map (\segment -> segmentLine "selected-segment" segment position Nothing)

        markers =
            [ nodeMarker "origin-marker" state.origin position
            , nodeMarker "destination-marker" state.destination position
            ]
    in
    S.svg
        [ A.viewBox "0 0 1000 640"
        , A.preserveAspectRatio "xMidYMid meet"
        , A.class "street-map"
        , H.attribute "aria-hidden" "true"
        , H.attribute "focusable" "false"
        ]
        ([ S.desc [] [ S.text "I draw a quiet street graph, the baseline route, the changed route, and each hypothetical closure." ] ]
            ++ baseLines
            ++ afterLines
            ++ beforeLines
            ++ selectedLines
            ++ closedLines
            ++ closureMarks
            ++ markers
        )


segmentLine : String -> Segment -> (String -> ( Float, Float )) -> Maybe Msg -> S.Svg Msg
segmentLine className segment position onSelect =
    let
        ( x1, y1 ) = position segment.fromNode
        ( x2, y2 ) = position segment.toNode
    in
    S.line
        ([ A.x1 (String.fromFloat x1)
         , A.y1 (String.fromFloat y1)
         , A.x2 (String.fromFloat x2)
         , A.y2 (String.fromFloat y2)
         , A.class className
         ]
            ++ (case onSelect of
                    Nothing ->
                        []

                    Just message ->
                        [ SE.onClick message ]
               )
        )
        []


closureMark : Segment -> (String -> ( Float, Float )) -> S.Svg Msg
closureMark segment position =
    let
        ( x1, y1 ) = position segment.fromNode
        ( x2, y2 ) = position segment.toNode
        middleX =
            (x1 + x2) / 2

        middleY =
            (y1 + y2) / 2

        deltaX =
            x2 - x1

        deltaY =
            y2 - y1

        length =
            sqrt (deltaX * deltaX + deltaY * deltaY)

        normalX =
            if length < 0.001 then
                5

            else
                -deltaY / length * 7

        normalY =
            if length < 0.001 then
                0

            else
                deltaX / length * 7
    in
    S.line
        [ A.x1 (String.fromFloat (middleX - normalX))
        , A.y1 (String.fromFloat (middleY - normalY))
        , A.x2 (String.fromFloat (middleX + normalX))
        , A.y2 (String.fromFloat (middleY + normalY))
        , A.class "closure-crossbar"
        ]
        []


mapBounds : Projection -> List Node -> MapBounds
mapBounds projection nodes =
    let
        finish bounds =
            { bounds
                | spanXmm =
                    max 1
                        (toFloat (bounds.maxLon - bounds.minLon)
                            * 11132
                            * toFloat (max 1 projection.cosLatPpm)
                            / 100000000
                        )
                , spanYmm =
                    max 1 (toFloat (bounds.maxLat - bounds.minLat) * 110574 / 1000)
            }
    in
    case nodes of
        [] ->
            { minLat = 0
            , maxLat = 1
            , minLon = 0
            , maxLon = 1
            , cosLatPpm = projection.cosLatPpm
            , spanXmm = 1
            , spanYmm = 1
            }
                |> finish

        first :: rest ->
            List.foldl
                (\node bounds ->
                    { bounds
                        | minLat = min node.latE6 bounds.minLat
                        , maxLat = max node.latE6 bounds.maxLat
                        , minLon = min node.lonE6 bounds.minLon
                        , maxLon = max node.lonE6 bounds.maxLon
                    }
                )
                { minLat = first.latE6
                , maxLat = first.latE6
                , minLon = first.lonE6
                , maxLon = first.lonE6
                , cosLatPpm = projection.cosLatPpm
                , spanXmm = 1
                , spanYmm = 1
                }
                rest
                |> finish


mapPosition : MapBounds -> Node -> ( Float, Float )
mapPosition bounds node =
    let
        drawWidth =
            900

        drawHeight =
            540

        padding =
            50

        scale =
            min (toFloat drawWidth / bounds.spanXmm) (toFloat drawHeight / bounds.spanYmm)

        usedWidth =
            bounds.spanXmm * scale

        usedHeight =
            bounds.spanYmm * scale

        xDistance =
            toFloat (node.lonE6 - bounds.minLon)
                * 11132
                * toFloat (max 1 bounds.cosLatPpm)
                / 100000000

        yDistance =
            toFloat (node.latE6 - bounds.minLat) * 110574 / 1000

        x =
            toFloat padding + (toFloat drawWidth - usedWidth) / 2 + xDistance * scale

        y =
            toFloat padding + (toFloat drawHeight - usedHeight) / 2 + (bounds.spanYmm - yDistance) * scale
    in
    ( x, y )


nodeMarker : String -> String -> (String -> ( Float, Float )) -> S.Svg Msg
nodeMarker className nodeId position =
    let
        ( x, y ) = position nodeId
    in
    S.circle
        [ A.cx (String.fromFloat x)
        , A.cy (String.fromFloat y)
        , A.r "7"
        , A.class className
        ]
        []


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }
