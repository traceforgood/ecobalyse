module Page.Simulator exposing (Model, Msg, init, update, view)

import Array
import Data.Country as Country exposing (Country)
import Data.LifeCycle as LifeCycle exposing (LifeCycle)
import Data.Material as Material exposing (Material)
import Data.Material.Category as Category exposing (Category)
import Data.Product as Product exposing (Product)
import Data.Session exposing (Session)
import Data.Simulator as Simulator exposing (Simulator)
import Data.Step as Step exposing (Step)
import Data.Transport as Transport
import Html exposing (..)
import Html.Attributes as Attr exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Encode as Encode
import Route
import Views.Format as Format
import Views.Icon as Icon


type alias Model =
    Simulator


type Msg
    = Reset
    | UpdateMass Float
    | UpdateMaterial Material
    | UpdateMaterialCategory Category
    | UpdateStepCountry Step.Label Country
    | UpdateProduct Product


init : Session -> ( Model, Session, Cmd Msg )
init ({ store } as session) =
    -- TODO: is using store.simulator necessary? why should it be serialized in a first step?
    ( Simulator.compute store.simulator
    , session
    , Cmd.none
    )


update : Session -> Msg -> Model -> ( Model, Session, Cmd Msg )
update session msg model =
    case msg of
        Reset ->
            ( Simulator.compute Simulator.default, session, Cmd.none )

        UpdateMass mass ->
            ( Simulator.compute { model | mass = mass }
            , session
            , Cmd.none
            )

        UpdateMaterial material ->
            ( Simulator.compute { model | material = material }
            , session
            , Cmd.none
            )

        UpdateMaterialCategory category ->
            ( Simulator.compute
                { model
                    | material =
                        Material.choices
                            |> List.filter (.category >> (==) category)
                            |> List.head
                            |> Maybe.withDefault Material.cotton
                }
            , session
            , Cmd.none
            )

        UpdateStepCountry label country ->
            ( Simulator.compute { model | lifeCycle = model.lifeCycle |> LifeCycle.updateStepCountry label country }
            , session
            , Cmd.none
            )

        UpdateProduct product ->
            ( Simulator.compute { model | product = product, mass = product.mass }
            , session
            , Cmd.none
            )


massInput : Float -> Html Msg
massInput mass =
    div [ class "mb-3" ]
        [ label [ for "mass", class "form-label fw-bold" ] [ text "Masse du produit fini" ]
        , div
            [ class "input-group" ]
            [ input
                [ type_ "number"
                , class "form-control"
                , id "mass"
                , Attr.min "0.05"
                , step "0.05"
                , value <| String.fromFloat mass
                , onInput (String.toFloat >> Maybe.withDefault mass >> UpdateMass)
                ]
                []
            , span [ class "input-group-text" ] [ text "kg" ]
            ]
        ]


materialCategorySelect : Material -> Html Msg
materialCategorySelect material =
    div [ class "mb-2" ]
        [ div [ class "form-label fw-bold" ] [ text "Matières premières" ]
        , [ Category.Natural, Category.Synthetic, Category.Recycled ]
            |> List.map
                (\m ->
                    button
                        [ type_ "button"
                        , classList
                            [ ( "btn", True )
                            , ( "btn-outline-primary", material.category /= m )
                            , ( "btn-primary", material.category == m )
                            , ( "text-truncate", True )
                            ]
                        , onClick (UpdateMaterialCategory m)
                        ]
                        [ m |> Category.toString |> text ]
                )
            |> div [ class "btn-group w-100" ]
        ]


materialInput : Material -> Html Msg
materialInput material =
    div [ class "mb-3" ]
        [ Material.choices
            |> List.filter (.category >> (==) material.category)
            |> List.map
                (\m ->
                    option
                        [ value m.materialProcessUuid
                        , selected (material.materialProcessUuid == m.materialProcessUuid)
                        , title m.name
                        ]
                        [ text m.name ]
                )
            |> select
                [ id "material"
                , class "form-select"
                , onInput (Material.findByProcessUuid >> Maybe.withDefault Material.cotton >> UpdateMaterial)
                ]
        ]


productSelect : Product -> Html Msg
productSelect product =
    div [ class "mb-3" ]
        [ label [ for "product", class "form-label fw-bold" ] [ text "Type de produit" ]
        , Product.choices
            |> List.map (\p -> option [ value p.id, selected (product.id == p.id) ] [ text p.name ])
            |> select
                [ id "product"
                , class "form-select"
                , onInput (Product.findById >> Maybe.withDefault Product.tShirt >> UpdateProduct)
                ]
        ]


countrySelect : Step -> Html Msg
countrySelect step =
    div []
        [ Country.choices
            |> List.map (\c -> option [ selected (step.country == c) ] [ text (Country.toString c) ])
            |> select
                [ class "form-select"
                , disabled (not step.editable) -- ADEME enforce Asia as a default for these, prevent update
                , onInput (Country.fromString >> UpdateStepCountry step.label)
                ]
        , if not step.editable then
            div [ class "form-text fs-7" ]
                [ text "Champ non paramétrable"
                ]

          else
            text ""
        ]


transportWidget : Bool -> Transport.Summary -> Html Msg
transportWidget fullWidth { road, air, sea } =
    div
        [ classList
            [ ( "d-flex fs-7", True )
            , ( "justify-content-between", fullWidth )
            , ( "justify-content-center", not fullWidth )
            ]
        ]
        [ span [ class "mx-2" ]
            [ span [ class "me-1" ] [ Icon.plane ]
            , air |> Format.formatInt "km" |> text
            ]
        , span [ class "mx-2" ]
            [ span [ class "me-1" ] [ Icon.boat ]
            , sea |> Format.formatInt "km" |> text
            ]
        , span [ class "mx-2" ]
            [ span [ class "me-1" ] [ Icon.bus ]
            , road |> Format.formatInt "km" |> text
            ]
        ]


downArrow : Html Msg
downArrow =
    img [ src "img/down-arrow-icon.png" ] []


stepView : Int -> Step -> Html Msg
stepView index current =
    div [ class "card-group" ]
        [ div [ class "card" ]
            [ div [ class "card-header d-flex align-items-center" ]
                [ span [ class "badge rounded-pill bg-primary me-1" ]
                    [ text (String.fromInt (index + 1)) ]
                , text <| Step.labelToString current.label
                ]
            , div [ class "card-body" ]
                [ countrySelect current
                ]
            ]
        , div
            [ class "card text-center" ]
            [ div [ class "card-header text-muted" ]
                [ span [ class "fw-bold" ]
                    [ (current.co2 + current.transport.co2)
                        |> Format.formatFloat "kg eq, CO₂"
                        |> text
                    ]
                ]
            , div [ class "card-body text-muted fs-7" ]
                [ div [ class "text-muted mb-2" ]
                    [ text "Masse: "
                    , Format.formatFloat "kg" current.mass |> text
                    , text " - Perte: "
                    , Format.formatFloat "kg" current.waste |> text
                    ]
                , transportWidget True current.transport
                , div [ class "text-muted mt-2" ]
                    [ strong [] [ text "Transport\u{00A0}:\u{00A0}" ]
                    , current.transport.co2 |> Format.formatFloat "kg eq, CO₂" |> text
                    ]
                ]
            ]
        ]


lifeCycleStepsView : LifeCycle -> Html Msg
lifeCycleStepsView lifeCycle =
    div []
        [ h2 [ class "mb-3" ] [ text "Étapes" ]
        , lifeCycle
            |> Array.indexedMap (\index -> stepView index)
            |> Array.toList
            |> List.intersperse (div [ class "text-center" ] [ downArrow ])
            |> div []
        ]


summaryView : Model -> Html Msg
summaryView model =
    div [ class "mb-3" ]
        [ div [ class "card text-white bg-primary mb-3" ]
            [ div [ class "card-header" ]
                [ em [] [ text model.product.name ]
                , text " en "
                , em [] [ text model.material.name ]
                , text " de "
                , em [] [ text (String.fromFloat model.mass ++ "kg") ]
                ]
            , div [ class "card-body" ]
                [ p [ class "display-5 text-center" ]
                    [ model.co2 |> Format.formatFloat "kg eq, CO₂" |> text ]
                , model.lifeCycle
                    |> LifeCycle.computeTransportSummary
                    |> transportWidget False
                ]
            ]
        ]


view : Session -> Model -> ( String, List (Html Msg) )
view _ model =
    ( "Simulateur"
    , [ h1 [ class "mb-3" ] [ text "Simulateur" ]
      , div [ class "row" ]
            [ div [ class "col-lg-7 col-xl-6" ]
                [ div [ class "row" ]
                    [ div [ class "col-md-6" ]
                        [ productSelect model.product
                        ]
                    , div [ class "col-md-6" ]
                        [ massInput model.mass
                        ]
                    ]
                , materialCategorySelect model.material
                , materialInput model.material
                , lifeCycleStepsView model.lifeCycle
                , div [ class "d-flex align-items-center justify-content-between my-3" ]
                    [ a [ Route.href Route.Home ] [ text "« Retour à l'accueil" ]
                    , button
                        [ class "btn btn-secondary"
                        , onClick Reset
                        , disabled (Simulator.default == model)
                        ]
                        [ text "Réinitialiser le simulateur" ]
                    ]
                ]
            , div [ class "col-lg-5 col-xl-6" ]
                [ summaryView model
                , img [ class "w-100 mb-3", src "https://via.placeholder.com/400x200?text=Graphic+goes+here" ] []
                , details []
                    [ summary [] [ text "Debug" ]
                    , pre [ class "mt-3" ]
                        [ Simulator.encode model |> Encode.encode 2 |> text
                        ]
                    ]
                ]
            ]
      ]
    )
