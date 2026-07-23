{-# LANGUAGE DataKinds #-}

-- | The scenario engine.
--
-- Founders do not just want to know their current runway — they want to know
-- what changes it. A scenario is a set of hypothetical adjustments (hire some
-- engineers, close a funding round, cut marketing) applied to the burn profile
-- and current balance, after which we recompute the runway. This is the piece
-- that turns a static number into a planning tool.
module Runway.Scenario
  ( Scenario (..)
  , Adjustment (..)
  , applyScenario
  , runScenario
  ) where

import Data.Scientific (Scientific)
import Data.Time (Day)
import Runway.Burn (BurnProfile (..))
import Runway.Forecast (Runway, runway)
import Runway.Money

-- | A single hypothetical change to the business's finances.
data Adjustment
  = Hire Int (Money 'USD)
    -- ^ add @n@ people at a given fully-loaded monthly cost each (raises
    -- monthly expense).
  | RaiseCapital (Money 'USD)
    -- ^ inject a one-off amount of cash now (raises the opening balance).
  | AdjustExpense Scientific
    -- ^ multiply recurring expense by a factor (e.g. 0.8 to cut spend 20%).
  | AdjustRevenue Scientific
    -- ^ multiply monthly revenue by a factor (e.g. 1.5 for projected growth).
  deriving (Eq, Show)

-- | A named bundle of adjustments the user is modelling together.
data Scenario = Scenario
  { scenarioName        :: String
  , scenarioAdjustments :: [Adjustment]
  } deriving (Eq, Show)

-- | Apply a scenario to a starting position, returning the adjusted opening
-- balance and burn profile. Kept pure and separate from 'runScenario' so it is
-- easy to unit-test the adjustment arithmetic on its own.
applyScenario
  :: Scenario
  -> Money 'USD          -- ^ current balance
  -> BurnProfile         -- ^ current burn profile
  -> (Money 'USD, BurnProfile)
applyScenario scenario = go (scenarioAdjustments scenario)
  where
    go [] bal profile = (bal, profile)
    go (adj : rest) bal profile =
      let (bal', profile') = step adj bal profile
       in go rest bal' profile'

    step adj bal profile = case adj of
      Hire n costEach ->
        let extra = scale (fromIntegral n) costEach
         in ( bal
            , profile { bpMonthlyExpense = add (bpMonthlyExpense profile) extra
                      , bpRecurringExpense = add (bpRecurringExpense profile) extra
                      , bpNetBurn = add (bpNetBurn profile) extra
                      }
            )
      RaiseCapital amt ->
        (add bal amt, profile)
      AdjustExpense factor ->
        let newExpense = scale factor (bpMonthlyExpense profile)
         in ( bal
            , profile { bpMonthlyExpense = newExpense
                      , bpNetBurn = subtract' newExpense (bpMonthlyRevenue profile)
                      }
            )
      AdjustRevenue factor ->
        let newRevenue = scale factor (bpMonthlyRevenue profile)
         in ( bal
            , profile { bpMonthlyRevenue = newRevenue
                      , bpNetBurn = subtract' (bpMonthlyExpense profile) newRevenue
                      }
            )

-- | Apply a scenario and recompute the runway from the adjusted position.
runScenario :: Day -> Scenario -> Money 'USD -> BurnProfile -> Runway
runScenario start scenario bal profile =
  let (bal', profile') = applyScenario scenario bal profile
   in runway start bal' profile'
