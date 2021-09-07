module Views.Chart exposing (..)

import Array
import Data.Simulator exposing (Simulator)
import Data.Step as Step
import Html exposing (..)
import Html.Attributes exposing (..)
import Views.Format as Format


type alias Bar =
    { label : String
    , co2 : Float
    , width : Float
    , percent : Float
    }


makeBars : Simulator -> List Bar
makeBars simulator =
    let
        maxScore =
            simulator.lifeCycle
                |> Array.map .co2
                |> Array.push simulator.transport.co2
                |> Array.toList
                |> List.maximum
                |> Maybe.withDefault 0

        stepBars =
            simulator.lifeCycle
                |> Array.toList
                |> List.filter (\{ label } -> label /= Step.Distribution)
                |> List.map
                    (\step ->
                        { label = Step.labelToString step.label
                        , co2 = step.co2
                        , width = step.co2 / maxScore * toFloat 100
                        , percent = step.co2 / simulator.co2 * toFloat 100
                        }
                    )

        transportBar =
            { label = "Transport total"
            , co2 = simulator.transport.co2
            , width = simulator.transport.co2 / maxScore * toFloat 100
            , percent = simulator.transport.co2 / simulator.co2 * toFloat 100
            }
    in
    stepBars ++ [ transportBar ]


barView : Bar -> Html msg
barView bar =
    tr [ class "fs-7" ]
        [ th [ class "text-end text-truncate py-1 pe-2" ] [ text bar.label ]
        , td [ class "d-none d-sm-block text-center py-1 ps-2 pe-3 text-truncate" ]
            [ bar.co2 |> Format.formatFloat "kg eq, CO₂" |> text ]
        , td [ class "w-100 py-1" ]
            [ div
                [ class "bg-primary"
                , style "height" "1rem"
                , style "line-height" "1rem"
                , style "width" (String.fromFloat bar.width ++ "%")
                ]
                []
            ]
        , td [ class "d-none d-sm-block text-end py-1 ps-2 text-truncate" ]
            [ bar.percent |> Format.formatFloat "%" |> text ]
        ]


view : Simulator -> Html msg
view simulator =
    div [ class "card mb-3" ]
        [ div [ class "card-body py-2" ]
            [ table [ class "mb-0" ]
                [ makeBars simulator
                    |> List.map barView
                    |> tbody []
                ]
            ]
        ]