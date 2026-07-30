{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

-- | The HTTP API.
--
-- The API is described as a Servant type. That type is the single source of
-- truth for the endpoints: the server handlers are checked against it at
-- compile time, so a handler that returns the wrong shape will not build. This
-- mirrors the "let the types prevent the bug" philosophy on the wire.
module Runway.Api
  ( RunwayApi
  , app
  ) where

import Data.Aeson (ToJSON (..), FromJSON (..), object, withObject, (.:), (.=))
import qualified Data.Map.Strict as Map
import Data.Scientific (Scientific)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import GHC.Generics (Generic)
import Network.Wai (Application)
import Network.Wai.Middleware.Cors (simpleCors)
import Servant

import Runway.Burn
import Runway.Forecast
import Runway.Ledger
import Runway.Money
import Runway.Scenario
import Runway.Transaction

-- JSON instances --------------------------------------------------------------
--
-- Money is serialised as a plain decimal number (its exact 'Scientific'
-- value). Enums serialise as their constructor name, which keeps the wire
-- format readable and stable.

moneyJson :: Money 'USD -> Scientific
moneyJson = amount

instance ToJSON Direction where toJSON = toJSON . show
instance ToJSON Cadence   where toJSON = toJSON . show
instance ToJSON Category  where toJSON = toJSON . show

instance ToJSON Transaction where
  toJSON t = object
    [ "id"        .= (case txnId t of TxnId i -> i)
    , "date"      .= txnDate t
    , "direction" .= txnDirection t
    , "cadence"   .= txnCadence t
    , "category"  .= txnCategory t
    , "amount"    .= moneyJson (txnAmount t)
    , "memo"      .= txnMemo t
    ]

instance ToJSON ForecastPoint where
  toJSON p = object
    [ "date"    .= fpDate p
    , "balance" .= moneyJson (fpBalance p)
    , "low"     .= moneyJson (fpLow p)
    , "high"    .= moneyJson (fpHigh p)
    ]

-- | The full dashboard payload, assembled once and returned to the frontend.
data Dashboard = Dashboard
  { dashBalance   :: Money 'USD
  , dashBurn      :: BurnProfile
  , dashRunway    :: Runway
  , dashBreakdown :: Map.Map Category (Money 'USD)
  , dashTxns      :: [Transaction]
  }

instance ToJSON Dashboard where
  toJSON d = object
    [ "balance"      .= moneyJson (dashBalance d)
    , "monthlyRevenue" .= moneyJson (bpMonthlyRevenue (dashBurn d))
    , "monthlyExpense" .= moneyJson (bpMonthlyExpense (dashBurn d))
    , "netBurn"      .= moneyJson (bpNetBurn (dashBurn d))
    , "runwayMonths" .= rwMonths (dashRunway d)
    , "depletionDate" .= rwDepletion (dashRunway d)
    , "projection"   .= rwProjection (dashRunway d)
    , "breakdown"    .= [ object ["category" .= show c, "amount" .= moneyJson m]
                        | (c, m) <- Map.toList (dashBreakdown d) ]
    , "transactions" .= dashTxns d
    ]

-- | Scenario request body. Adjustments arrive as a small tagged JSON union.
newtype ScenarioReq = ScenarioReq Scenario

instance FromJSON ScenarioReq where
  parseJSON = withObject "ScenarioReq" $ \o -> do
    name <- o .: "name"
    adjs <- o .: "adjustments"
    ScenarioReq . Scenario name <$> traverse parseAdj adjs
    where
      parseAdj = withObject "Adjustment" $ \o -> do
        kind <- o .: "kind"
        case (kind :: Text) of
          "hire"          -> Hire <$> o .: "count" <*> (money <$> o .: "costEach")
          "raise"         -> RaiseCapital . money <$> o .: "amount"
          "adjustExpense" -> AdjustExpense <$> o .: "factor"
          "adjustRevenue" -> AdjustRevenue <$> o .: "factor"
          _               -> fail ("unknown adjustment: " <> T.unpack kind)

instance ToJSON Runway where
  toJSON r = object
    [ "runwayMonths"  .= rwMonths r
    , "depletionDate" .= rwDepletion r
    , "projection"    .= rwProjection r
    ]

-- API definition --------------------------------------------------------------

-- | The API surface, as a type.
--
--   * @GET  /dashboard@         — everything the main view needs
--   * @POST /scenario@          — run a what-if scenario, get back a runway
type RunwayApi =
       "dashboard" :> Get '[JSON] Dashboard
  :<|> "scenario"  :> ReqBody '[JSON] ScenarioReq :> Post '[JSON] Runway

-- | Build the WAI application from a ledger and the "today" date used as the
-- forecast origin. CORS is enabled so the Vite dev server can call it.
app :: Day -> Ledger -> Application
app today ledger = simpleCors (serve api server)
  where
    api = Proxy :: Proxy RunwayApi

    profile = burnProfile ledger
    balance = currentBalance ledger

    server = getDashboard :<|> postScenario

    getDashboard :: Handler Dashboard
    getDashboard =
      pure Dashboard
        { dashBalance   = balance
        , dashBurn      = profile
        , dashRunway    = runway today balance profile
        , dashBreakdown = categoryBreakdown ledger
        , dashTxns      = transactions ledger
        }

    postScenario :: ScenarioReq -> Handler Runway
    postScenario (ScenarioReq s) =
      pure (runScenario today s balance profile)
