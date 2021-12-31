module Server.RouteTest exposing (..)

import Data.Db exposing (Db)
import Data.Impact as Impact
import Data.Inputs as Inputs
import Dict
import Expect exposing (Expectation)
import Json.Encode as Encode
import Server.Route as Route
import Test exposing (..)
import TestDb exposing (testDb)


asTest : String -> Expectation -> Test
asTest label =
    always >> test label


getEndpoint : Db -> String -> String -> Maybe Route.Endpoint
getEndpoint db method url =
    Route.endpoint db
        { method = method
        , url = url
        , jsResponseHandler = Encode.null
        }


suite_ : Db -> Test
suite_ db =
    describe "Server.endpoint"
        [ getEndpoint db "GET" "/simulator?mass=0.17&product=13&material=f211bbdb-415c-46fd-be4d-ddf199575b44&countries=CN,FR,FR,FR,FR"
            |> Expect.equal (Just <| Route.Get <| Route.Simulator <| Ok Inputs.tShirtCotonFrance)
            |> asTest "should handle the /simulator endpoint"
        , getEndpoint db "GET" "/simulator/fwe?mass=0.17&product=13&material=f211bbdb-415c-46fd-be4d-ddf199575b44&countries=CN,FR,FR,FR,FR"
            |> Expect.equal (Just <| Route.Get <| Route.SimulatorSingle (Impact.trg "fwe") <| Ok Inputs.tShirtCotonFrance)
            |> asTest "should handle the /simulator/{impact} endpoint"
        , getEndpoint db "GET" "/simulator/detailed?mass=0.17&product=13&material=f211bbdb-415c-46fd-be4d-ddf199575b44&countries=CN,FR,FR,FR,FR"
            |> Expect.equal (Just <| Route.Get <| Route.SimulatorDetailed <| Ok Inputs.tShirtCotonFrance)
            |> asTest "should handle the /simulator/detailed endpoint"
        , getEndpoint db "GET" "/simulator"
            |> Expect.equal
                (Just <|
                    Route.Get <|
                        Route.Simulator <|
                            Err <|
                                Dict.fromList
                                    [ ( "countries", "La liste de pays doit contenir 5 pays." )
                                    , ( "mass", "La masse doit être supérieure ou égale à zéro." )
                                    , ( "material", "Identifiant de la matière manquant ou invalide." )
                                    , ( "product", "Identifiant du type de produit manquant ou invalide." )
                                    ]
                )
            |> asTest "should expose query validation errors"
        ]


suite : Test
suite =
    describe "Server"
        [ case testDb of
            Ok db ->
                suite_ db

            Err error ->
                test "should load test database" <|
                    \_ -> Expect.fail <| "Couldn't parse test database: " ++ error
        ]