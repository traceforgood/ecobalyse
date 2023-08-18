module Views.Textile.ComparativeChart exposing
    ( Entry
    , Stacks
    , chart
    , createEntry
    )

import Chart as C
import Chart.Attributes as CA
import Chart.Events as CE
import Chart.Item as CI
import Data.Impact as Impact
import Data.Impact.Definition exposing (Definition)
import Data.Textile.Db exposing (Db)
import Data.Textile.Inputs as Inputs exposing (Inputs)
import Data.Textile.LifeCycle as LifeCycle
import Data.Textile.Product as Product
import Data.Textile.Simulator as Simulator
import Data.Textile.Step.Label as Label
import Data.Unit as Unit
import Duration exposing (Duration)
import Html exposing (..)
import Html.Attributes exposing (..)
import Quantity
import Svg as S
import Svg.Attributes as SA
import Views.Dataviz as Dataviz
import Views.Format as Format


type alias Stacks =
    List (CI.Many Entry CI.Any)


type alias Entry =
    { label : String
    , highlight : Bool
    , knitted : Bool
    , score : Float
    , material : Float
    , spinning : Float
    , weavingKnitting : Float
    , ennobling : Float
    , making : Float
    , use : Float
    , endOfLife : Float
    , transport : Float
    , title : Html Never
    }


createEntry :
    Db
    -> Unit.Functional
    -> Definition
    -> { highlight : Bool, label : String }
    -> Inputs.Query
    -> Result String Entry
createEntry db funit { trigram } { highlight, label } query =
    query
        |> Simulator.compute db
        |> Result.map
            (\({ lifeCycle, inputs, daysOfWear, transport } as simulator) ->
                let
                    stepScore stepLabel =
                        lifeCycle
                            |> LifeCycle.getStepProp stepLabel
                                (.impacts >> Impact.getImpact trigram)
                                Quantity.zero
                            |> Unit.inFunctionalUnit funit daysOfWear
                            |> Unit.impactToFloat
                in
                { label = label
                , highlight = highlight
                , knitted = Product.isKnitted inputs.product
                , score = Impact.grabImpactFloat funit daysOfWear trigram simulator
                , material = stepScore Label.Material
                , spinning = stepScore Label.Spinning
                , weavingKnitting = stepScore Label.Fabric
                , ennobling = stepScore Label.Ennobling
                , making = stepScore Label.Making
                , use = stepScore Label.Use
                , endOfLife = stepScore Label.EndOfLife
                , transport = Impact.grabImpactFloat funit daysOfWear trigram transport
                , title =
                    query
                        |> Inputs.fromQuery db
                        |> Result.map toolTip
                        |> Result.withDefault (text "")
                }
            )


toolTip : Inputs -> Html msg
toolTip inputs =
    inputs
        |> Inputs.stepsToStrings
        |> List.map (String.join "\u{00A0}: ")
        |> List.map text
        |> List.intersperse (br [] [])
        |> p []


chartTextColor : String
chartTextColor =
    "#5d5b7e"


ellipsis : Int -> String -> String
ellipsis n str =
    if n < String.length str then
        String.slice 0 n str ++ "…"

    else
        str


{-| Create vertical labels from percentages on the x-axis.
-}
fillLabels : List Entry -> List (C.Element data msg)
fillLabels entries =
    let
        baseWidth =
            100 / toFloat (clamp 1 100 (List.length entries))

        leftPadding =
            baseWidth / 4.5

        createLabel ( { label, highlight }, xPosition ) =
            C.labelAt
                (CA.percent xPosition)
                (CA.percent 0)
                [ CA.rotate 90
                , CA.color chartTextColor
                , CA.attrs
                    [ SA.fontSize "14"
                    , SA.style "text-anchor: start"
                    , if highlight then
                        SA.fontWeight "500"

                      else
                        SA.fontWeight "normal"
                    ]
                ]
                [ label
                    |> ellipsis 58
                    |> S.text
                ]
    in
    entries
        |> List.indexedMap (\i entry -> ( entry, toFloat i * baseWidth + leftPadding ))
        |> List.map createLabel


formatLabel : Unit.Functional -> Definition -> Duration -> Float -> { x : String, y : String }
formatLabel funit { unit } daysOfWear num =
    let
        inFunctionalUnit =
            case funit of
                Unit.PerDayOfWear ->
                    num / Duration.inDays daysOfWear

                Unit.PerItem ->
                    num
    in
    { x = Format.formatFloat 2 inFunctionalUnit ++ "\u{202F}" ++ unit
    , y = Format.formatFloat 2 inFunctionalUnit
    }


type alias ChartOptions msg =
    { funit : Unit.Functional
    , impact : Definition
    , daysOfWear : Duration
    , size : Maybe ( Float, Float )
    , margins : Maybe { top : Float, bottom : Float, left : Float, right : Float }
    , chartHovering : List (CI.Many Entry CI.Any)
    , onChartHover : List (CI.Many Entry CI.Any) -> msg
    }


chart : ChartOptions msg -> List Entry -> Html msg
chart { funit, impact, daysOfWear, size, margins, onChartHover, chartHovering } entries =
    let
        knitted =
            entries |> List.head |> Maybe.map .knitted |> Maybe.withDefault False

        barStyleVariation _ { highlight } =
            if not highlight then
                [ CA.opacity 0.35 ]

            else
                []

        bars =
            [ entries
                |> C.bars [ CA.margin 0.28 ]
                    [ Dataviz.stepsLegendData { knitted = knitted }
                        |> List.map
                            (\( getter, label ) ->
                                C.bar getter []
                                    |> C.named label
                                    |> C.variation barStyleVariation
                            )
                        |> C.stacked
                    ]
            ]

        xLabels =
            [ C.binLabels (.score >> formatLabel funit impact daysOfWear >> .x)
                [ CA.moveDown 23
                , CA.color chartTextColor
                , CA.rotate 12
                , CA.attrs [ SA.fontSize "12" ]
                ]
            ]

        yLabels =
            [ C.yLabels
                [ CA.withGrid
                , CA.fontSize 11
                , CA.color chartTextColor
                , CA.format (formatLabel funit impact daysOfWear >> .y)
                ]
            ]

        legends =
            [ C.legendsAt
                .min
                .max
                [ CA.alignMiddle
                , CA.htmlAttrs [ class "ComparatorChartLegends" ]
                , CA.moveDown 20
                ]
                [ CA.spacing 3
                , CA.fontSize 12
                , CA.htmlAttrs [ class "ComparatorChartLegend" ]
                ]
            ]

        verticalLabels =
            fillLabels entries

        tooltips =
            [ C.each chartHovering <|
                \_ item ->
                    let
                        title =
                            item
                                |> CI.getMember
                                |> CI.getData
                                |> .title
                    in
                    [ C.tooltip item [] [] [ title ] ]
            ]
    in
    [ xLabels, yLabels, bars, legends, verticalLabels, tooltips ]
        |> List.concat
        |> C.chart
            [ CA.width (size |> Maybe.map Tuple.first |> Maybe.withDefault 550)
            , CA.height (size |> Maybe.map Tuple.second |> Maybe.withDefault 250)
            , CA.margin (margins |> Maybe.withDefault { top = 22, bottom = 10, left = 40, right = 0 })
            , CA.htmlAttrs [ class "ComparatorChart" ]
            , CE.onMouseMove onChartHover (CE.getNearest CI.stacks)
            , CE.onMouseLeave (onChartHover [])
            ]
