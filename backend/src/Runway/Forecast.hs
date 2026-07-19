{-# LANGUAGE DataKinds #-}

-- | The runway projector.
--
-- Given a current cash balance and a burn profile, we project the cash balance
-- forward month by month and find the month it crosses zero — the runway.
module Runway.Forecast
  ( ForecastPoint (..)
  , Runway (..)
  , projectBalance
  , runway
  , runwayMonths
  ) where

import Data.Time (Day, addGregorianMonthsClip)
import Runway.Burn (BurnProfile (..))
import Runway.Money

-- | A single projected month: the date and the expected balance at its end.
data ForecastPoint = ForecastPoint
  { fpDate    :: Day
  , fpBalance :: Money 'USD
  } deriving (Eq, Show)

-- | The runway result.
data Runway = Runway
  { rwMonths      :: Maybe Int     -- ^ months until cash hits zero; 'Nothing' if cash-flow positive
  , rwDepletion   :: Maybe Day     -- ^ projected depletion date; 'Nothing' if never
  , rwProjection  :: [ForecastPoint]
  } deriving (Eq, Show)

-- | Project the cash balance forward for @n@ months from a start date. Each
-- month applies the net monthly change (revenue - expense).
projectBalance :: Day -> Int -> Money 'USD -> BurnProfile -> [ForecastPoint]
projectBalance start n opening profile = go 0 opening
  where
    net = subtract' (bpMonthlyRevenue profile) (bpMonthlyExpense profile)

    go i bal
      | i > n = []
      | otherwise =
          let date  = addGregorianMonthsClip (fromIntegral i) start
              point = ForecastPoint date bal
              bal'  = add bal net
           in point : go (i + 1) bal'

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
