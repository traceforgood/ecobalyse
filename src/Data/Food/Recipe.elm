module Data.Food.Recipe exposing
    ( compute
    , example
    , fromQuery
    , serialize
    , toQuery
    )

import Data.Country as Country
import Data.Food.Db as FoodDb
import Data.Food.Product as Product exposing (ProcessName)
import Data.Impact as Impact exposing (Impacts)
import Json.Encode as Encode
import Mass exposing (Mass)


type alias Ingredient =
    { processName : ProcessName
    , mass : Mass
    , country : Maybe Country.Code
    , labels : List String
    }


type alias Processing =
    { processName : ProcessName
    , mass : Mass
    }


type alias Inputs =
    ()


type alias Query =
    { ingredients : List Ingredient
    , processing : Maybe Processing
    , plant : PlantOptions
    }


type alias PlantOptions =
    { country : Maybe Country.Code }


fromQuery : FoodDb.Db -> Query -> Result String Inputs
fromQuery _ _ =
    Ok ()


toQuery : Inputs -> Query
toQuery _ =
    example


example : Query
example =
    { ingredients =
        [ { processName = Product.stringToProcessName "i1", mass = Mass.grams 10, country = Nothing, labels = [] }
        , { processName = Product.stringToProcessName "i2", mass = Mass.grams 40, country = Nothing, labels = [] }
        ]
    , processing =
        Just { processName = Product.stringToProcessName "p1", mass = Mass.grams 10 }
    , plant =
        { country = Just (Country.codeFromString "FR")
        }
    }


encode : Query -> Encode.Value
encode q =
    Encode.object
        [ ( "ingredients", Encode.list encodeIngredient q.ingredients )
        , ( "processing", q.processing |> Maybe.map encodeProcessing |> Maybe.withDefault Encode.null )
        , ( "plant", encodePlantOptions q.plant )
        ]


encodeIngredient : Ingredient -> Encode.Value
encodeIngredient i =
    Encode.object
        [ ( "processName", i.processName |> Product.processNameToString |> Encode.string )
        , ( "mass", Encode.float (Mass.inKilograms i.mass) )
        , ( "country", i.country |> Maybe.map Country.encodeCode |> Maybe.withDefault Encode.null )
        , ( "labels", Encode.list Encode.string i.labels )
        ]


encodeProcessing : Processing -> Encode.Value
encodeProcessing p =
    Encode.object
        [ ( "processName", p.processName |> Product.processNameToString |> Encode.string )
        , ( "mass", Encode.float (Mass.inKilograms p.mass) )
        ]


encodePlantOptions : PlantOptions -> Encode.Value
encodePlantOptions p =
    Encode.object
        [ ( "country", p.country |> Maybe.map Country.encodeCode |> Maybe.withDefault Encode.null )
        ]


serialize : Query -> String
serialize query =
    query
        |> encode
        |> Encode.encode 2


compute : FoodDb.Db -> Query -> Result String Impacts
compute db _ =
    -- query
    -- |> fromQuery
    Ok (Impact.impactsFromDefinitons db.impacts)