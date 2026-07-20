{-# LANGUAGE DataKinds #-}

-- | The runway projector.
--
-- Given a current cash balance and a burn profile, we project the cash balance
-- forward month by month and find the month it crosses zero — the runway. We
-- also compute a simple confidence band by flexing the net burn up and down,
-- because a single-point runway number gives founders false precision (the
-- research is blunt: most startups misforecast liquidity, and the ones that
-- die usually die of running out of cash).
module Runway.Forecast
  ( ForecastPoint (..)
  , Runway (..)
  , projectBalance
  , runway
  , runwayMonths
  ) where

import Data.Scientific (Scientific)
import Data.Time (Day, addGregorianMonthsClip)
import Runway.Burn (BurnProfile (..))
import Runway.Money

-- | A single projected month: the date and the expected balance at its end,
-- plus the low/high bounds of the confidence band.
data ForecastPoint = ForecastPoint
  { fpDate    :: Day
  , fpBalance :: Money 'USD
  , fpLow     :: Money 'USD
  , fpHigh    :: Money 'USD
  } deriving (Eq, Show)

-- | The runway result.
data Runway = Runway
  { rwMonths      :: Maybe Int     -- ^ months until cash hits zero; 'Nothing' if cash-flow positive
  , rwDepletion   :: Maybe Day     -- ^ projected depletion date; 'Nothing' if never
  , rwProjection  :: [ForecastPoint]
  } deriving (Eq, Show)

-- | How wide the confidence band is, as a fraction of net burn. A 20% band
-- means the optimistic line burns 20% slower and the pessimistic line 20%
-- faster. Kept as a named constant so the assumption is visible and tunable.
bandWidth :: Scientific
bandWidth = 0.2

-- | Project the cash balance forward for @n@ months from a start date.
--
-- Each month applies the net monthly change (revenue - expense). We track
-- three parallel lines: the central estimate and the two band edges, which
-- differ only in how fast the /expense/ side moves.
projectBalance :: Day -> Int -> Money 'USD -> BurnProfile -> [ForecastPoint]
projectBalance start n opening profile = go 0 opening opening opening
  where
    -- Central monthly delta: revenue minus expense.
    net = subtract' (bpMonthlyRevenue profile) (bpMonthlyExpense profile)

    -- Band edges flex the expense component only. Spending less than expected
    -- burns cash slower (the optimistic, higher-balance line); spending more
    -- burns faster (the pessimistic, lower-balance line).
    expenseSlow = scale (1 - bandWidth) (bpMonthlyExpense profile)
    expenseFast = scale (1 + bandWidth) (bpMonthlyExpense profile)
    netOptimistic  = subtract' (bpMonthlyRevenue profile) expenseSlow
    netPessimistic = subtract' (bpMonthlyRevenue profile) expenseFast

    -- The loop carries three running balances: the central estimate and the
    -- two band edges. `high` is the optimistic (larger) balance, `low` the
    -- pessimistic (smaller) one, matching the ForecastPoint field meanings.
    go i bal low high
      | i > n = []
      | otherwise =
          let date  = addGregorianMonthsClip (fromIntegral i) start
              point = ForecastPoint date bal low high
              bal'  = add bal net
              low'  = add low netPessimistic
              high' = add high netOptimistic
           in point : go (i + 1) bal' low' high'

-- | Compute the runway from a starting position and burn profile, projecting a
-- generous horizon so the depletion point is captured even for long runways.
runway :: Day -> Money 'USD -> BurnProfile -> Runway
runway start opening profile =
  Runway
    { rwMonths     = depletionMonth
    , rwDepletion  = fpDate <$> depletionPoint
    , rwProjection = projection
    }
  where
    horizon = 60  -- five years is plenty; healthy companies never deplete
    projection = projectBalance start horizon opening profile

    -- First month whose central balance is non-positive.
    indexed = zip [0 ..] projection
    depletionPair =
      case [ (i, p) | (i, p) <- indexed, not (isPositive (fpBalance p)) ] of
        (x : _) -> Just x
        []      -> Nothing

    depletionMonth = fst <$> depletionPair
    depletionPoint = snd <$> depletionPair

-- | Convenience: just the month count, if any.
runwayMonths :: Day -> Money 'USD -> BurnProfile -> Maybe Int
runwayMonths start opening = rwMonths . runway start opening
