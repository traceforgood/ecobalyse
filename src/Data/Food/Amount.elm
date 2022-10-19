module Data.Food.Amount exposing
    ( Amount(..)
    , format
    , fromUnitAndFloat
    , getMass
    , kilometerToTonKilometer
    , multiplyBy
    , toDisplayTuple
    , toStandardFloat
    , tonKilometerToKilometer
    )

import Energy exposing (Energy)
import Length exposing (Length)
import Mass exposing (Mass)
import Quantity
import Views.Format as Format
import Volume exposing (Volume)


type Amount
    = EnergyInKWh Energy
    | EnergyInMJ Energy
    | Length Length
    | Mass Mass
    | TonKilometer Mass
    | Volume Volume


format : Mass -> Amount -> String
format totalWeight amount =
    case amount of
        TonKilometer tonKm ->
            let
                -- amount is in Ton.Km for the total weight. We instead want the total number of km.
                distanceInKm =
                    Mass.inMetricTons tonKm / Mass.inMetricTons totalWeight
            in
            Format.formatFloat 0 distanceInKm
                ++ "\u{00A0}km ("
                ++ Format.formatFloat 2 (Mass.inKilograms tonKm)
                ++ "\u{00A0}kg.km)"

        _ ->
            let
                ( quantity, unit ) =
                    toDisplayTuple amount
            in
            Format.formatFloat 2 quantity ++ "\u{00A0}" ++ unit


fromUnitAndFloat : String -> Float -> Result String Amount
fromUnitAndFloat unit amount =
    case unit of
        "m³" ->
            Ok <| Volume (Volume.cubicMeters amount)

        "kg" ->
            Ok <| Mass (Mass.kilograms amount)

        "km" ->
            Ok <| Length (Length.kilometers amount)

        "kWh" ->
            Ok <| EnergyInKWh (Energy.kilowattHours amount)

        "l" ->
            -- WARNING: at the point this code was written, there was only ONE
            -- ingredient with a unit different than "kg", and it was for Water,
            -- with a volumic mass close enough to 1 that we decided to treat 1l = 1kg.
            Ok <| Mass (Mass.kilograms amount)

        "MJ" ->
            Ok <| EnergyInMJ (Energy.megajoules amount)

        "ton.km" ->
            -- FIXME: we should rather express ton.km using elm-unit's Product type
            -- @see https://package.elm-lang.org/packages/ianmackenzie/elm-units/latest/Quantity#Product
            Ok <| TonKilometer (Mass.metricTons amount)

        _ ->
            Err <| "Could not convert the unit " ++ unit


getMass : Amount -> Mass
getMass amount =
    case amount of
        Mass mass ->
            mass

        _ ->
            Quantity.zero


kilometerToTonKilometer : Length -> Mass -> Mass
kilometerToTonKilometer length amount =
    -- FIXME: amount shouldn't be a Mass, but a TonKilometer
    (Mass.inMetricTons amount / Length.inKilometers length)
        |> Mass.metricTons


multiplyBy : Float -> Amount -> Amount
multiplyBy ratio amount =
    case amount of
        EnergyInKWh energy ->
            EnergyInKWh (Quantity.multiplyBy ratio energy)

        EnergyInMJ energy ->
            EnergyInMJ (Quantity.multiplyBy ratio energy)

        Length length ->
            Length (Quantity.multiplyBy ratio length)

        Mass mass ->
            Mass (Quantity.multiplyBy ratio mass)

        TonKilometer tonKm ->
            TonKilometer (Quantity.multiplyBy ratio tonKm)

        Volume volume ->
            Volume (Quantity.multiplyBy ratio volume)


toDisplayTuple : Amount -> ( Float, String )
toDisplayTuple amount =
    -- A tuple used for display: we display units differently than what's used in Agribalyse
    -- eg: kilograms in agribalyse, grams in our UI, ton.km in agribalyse, kg.km in our UI
    case amount of
        EnergyInKWh energy ->
            ( Energy.inKilowattHours energy, "kWh" )

        EnergyInMJ energy ->
            ( Energy.inMegajoules energy, "MJ" )

        Length length ->
            ( Length.inKilometers length, "km" )

        Mass mass ->
            ( Mass.inGrams mass, "g" )

        TonKilometer tonKm ->
            ( Mass.inKilograms tonKm, "kg.km" )

        Volume volume ->
            ( Volume.inMilliliters volume, "ml" )


tonKilometerToKilometer : Mass -> Mass -> Length
tonKilometerToKilometer mass amount =
    -- FIXME: amount shouldn't be a Mass, but a TonKilometer
    (Mass.inMetricTons amount / Mass.inMetricTons mass)
        |> Length.kilometers


toStandardFloat : Amount -> Float
toStandardFloat amount =
    -- Standard here means using agribalyse units
    case amount of
        EnergyInKWh energy ->
            Energy.inKilowattHours energy

        EnergyInMJ energy ->
            Energy.inMegajoules energy

        Length length ->
            Length.inKilometers length

        Mass mass ->
            Mass.inKilograms mass

        TonKilometer tonKm ->
            Mass.inMetricTons tonKm

        Volume volume ->
            Volume.inLiters volume