{-# LANGUAGE DataKinds #-}

-- | The burn-rate engine.
--
-- Burn rate is how fast the business consumes cash. We compute it over a
-- trailing window and split it into its recurring and one-off components,
-- because only the recurring part is a reliable basis for forecasting the
-- future. A single large one-off expense (a legal bill, a piece of hardware)
-- should not make the projection think the company burns that much every
-- month.
module Runway.Burn
  ( BurnProfile (..)
  , burnProfile
  , categoryBreakdown
  , monthsBetween
  ) where

import Data.List (foldl')
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Time (Day, diffDays)
import Runway.Ledger
import Runway.Money
import Runway.Transaction

-- | A summary of how the business moves cash over a period.
--
-- All figures are monthly averages over the analysis window so they can be
-- compared and projected forward directly.
data BurnProfile = BurnProfile
  { bpMonthlyRevenue   :: Money 'USD  -- ^ average monthly inflow
  , bpMonthlyExpense   :: Money 'USD  -- ^ average monthly outflow
  , bpRecurringExpense :: Money 'USD  -- ^ recurring portion of the outflow
  , bpNetBurn          :: Money 'USD  -- ^ expense - revenue; positive = losing cash
  } deriving (Eq, Show)

-- | Approximate number of months between two days (365.25 / 12 day months).
-- We clamp to at least one month so a short window never divides by ~zero and
-- explodes the averages.
monthsBetween :: Day -> Day -> Rational
monthsBetween from to =
  let days = fromIntegral (max 1 (diffDays to from))
   in max 1 (days / 30.4375)

-- | Compute the burn profile from a ledger over the window spanned by its
-- transactions. Averages are per-month so they feed straight into the
-- forecaster.
burnProfile :: Ledger -> BurnProfile
burnProfile ledger =
  BurnProfile
    { bpMonthlyRevenue   = perMonth totalRevenue
    , bpMonthlyExpense   = perMonth totalExpense
    , bpRecurringExpense = perMonth recurringExpense
    , bpNetBurn          = subtract' (perMonth totalExpense) (perMonth totalRevenue)
    }
  where
    txns = transactions ledger

    -- Window length in months, from the first to the last transaction.
    months = case txns of
      [] -> 1
      _  -> monthsBetween (txnDate (head txns)) (txnDate (last txns))

    perMonth :: Money 'USD -> Money 'USD
    perMonth m = scale (1 / months) m

    totalRevenue     = sumMoney (map txnAmount (inflows ledger))
    totalExpense     = sumMoney (map txnAmount (outflows ledger))
    recurringExpense =
      sumMoney [txnAmount t | t <- outflows ledger, txnCadence t /= OneOff]

-- | Total outflow grouped by category, useful for the "where the money goes"
-- breakdown in the UI. Sorted descending by amount would be a view concern; we
-- return the raw map.
categoryBreakdown :: Ledger -> Map Category (Money 'USD)
categoryBreakdown ledger =
  foldl' insert Map.empty (outflows ledger)
  where
    insert acc t =
      Map.insertWith add (txnCategory t) (txnAmount t) acc
