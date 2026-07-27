{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | A realistic seed dataset: roughly six months of transactions for a
-- fictional seed-stage SaaS startup ("Photon Labs") that raised a $2.5M round
-- and is steadily burning it down. This gives the frontend something
-- believable to render and the forecaster something meaningful to project.
module Runway.Seed
  ( seedOpeningBalance
  , seedTransactions
  , loadSeed
  ) where

import Data.Time (Day, fromGregorian)
import Database.SQLite.Simple (Connection)
import Runway.Currency (Currency (USD))
import Runway.Money (Money, money)
import Runway.Store (insertTransaction, setOpeningBalance)
import Runway.Transaction

-- | Cash in the bank at the start of the window (post-raise).
seedOpeningBalance :: Money 'USD
seedOpeningBalance = money 2_500_000

-- | Build the seed ledger. Recurring costs (payroll, SaaS, rent, infra) repeat
-- each month; revenue grows modestly; a couple of one-offs add realistic
-- noise the forecaster must learn to ignore.
seedTransactions :: [Transaction]
seedTransactions = concat (zipWith monthOf [0 ..] months)
  where
    months =
      [ fromGregorian 2026 m 1 | m <- [1 .. 6] ]

    monthOf :: Int -> Day -> [Transaction]
    monthOf i d =
      [ recurring d Payroll        (money 148_000) "monthly payroll (11 heads)"
      , recurring d Software       (money 9_400)   "saas subscriptions"
      , recurring d Infrastructure (money 12_600)  "cloud + data pipeline"
      , recurring d Rent           (money 7_800)   "office lease"
      , recurring d Marketing      (money 15_000)  "growth + ads"
      , revenue   d (money (18_000 + fromIntegral i * 4_500)) "mrr collected"
      ] ++ oneOffsFor i d

    -- A legal bill and a hardware purchase land in specific months only.
    oneOffsFor 1 d = [oneOff d ProfessionalServices (money 22_000) "incorporation + legal"]
    oneOffsFor 3 d = [oneOff d Infrastructure (money 31_000) "gpu workstation cluster"]
    oneOffsFor _ _ = []

    recurring d cat amt memo =
      mkTxn d Outflow Monthly cat amt memo
    oneOff d cat amt memo =
      mkTxn d Outflow OneOff cat amt memo
    revenue d amt memo =
      mkTxn d Inflow Monthly Revenue amt memo

    -- 'TxnId' 0 is a placeholder; the store assigns real ids on insert.
    mkTxn d dir cad cat amt memo =
      Transaction (TxnId 0) d dir cad cat USD amt memo

-- | Load the seed data into a fresh database.
loadSeed :: Connection -> IO ()
loadSeed conn = do
  setOpeningBalance conn seedOpeningBalance
  mapM_ (insertTransaction conn) seedTransactions
