{-# LANGUAGE DataKinds #-}

-- | Properties of the forecaster. These encode the monotonicity facts a
-- founder would intuitively expect — more cash never shortens the runway, more
-- burn never lengthens it — which are exactly the kinds of sign errors a
-- floating-point or off-by-one bug would violate.
module ForecastSpec (spec) where

import Data.Time (Day, fromGregorian)
import Test.Hspec
import Test.QuickCheck

import Runway.Burn (BurnProfile (..))
import Runway.Forecast
import Runway.Money

start :: Day
start = fromGregorian 2026 7 1

-- | A cash-negative burn profile parameterised by monthly expense, with fixed
-- modest revenue. Positive expense above revenue guarantees a finite runway.
profileWithExpense :: Integer -> BurnProfile
profileWithExpense expense =
  BurnProfile
    { bpMonthlyRevenue   = money 10_000
    , bpMonthlyExpense   = money (fromIntegral expense)
    , bpRecurringExpense = money (fromIntegral expense)
    , bpNetBurn          = subtract' (money (fromIntegral expense)) (money 10_000)
    }

spec :: Spec
spec = describe "Runway.Forecast" $ do

  it "a cash-flow-positive company never depletes" $ do
    let profile = BurnProfile (money 50_000) (money 30_000) (money 30_000) (money (-20_000))
    rwMonths (runway start (money 100_000) profile) `shouldBe` Nothing

  it "more cash never shortens the runway" $
    property $ \(Positive extra) ->
      let profile = profileWithExpense 60_000
          base    = money 200_000 :: Money 'USD
          more    = add base (money (fromIntegral (extra :: Int)))
          r1      = runwayMonthsOr0 base profile
          r2      = runwayMonthsOr0 more profile
       in r2 >= r1

  it "higher burn never lengthens the runway" $
    property $ \(Positive bump) ->
      let base    = profileWithExpense 60_000
          higher  = profileWithExpense (60_000 + fromIntegral (bump :: Int))
          cash    = money 300_000 :: Money 'USD
          r1      = runwayMonthsOr0 cash base
          r2      = runwayMonthsOr0 cash higher
       in r2 <= r1

  it "projection starts at the opening balance" $ do
    let profile = profileWithExpense 40_000
        (p : _) = rwProjection (runway start (money 500_000) profile)
    fpBalance p `shouldBe` (money 500_000 :: Money 'USD)

-- | Treat "never depletes" as a very large runway for comparison purposes, so
-- the monotonicity properties have a total ordering to work with.
runwayMonthsOr0 :: Money 'USD -> BurnProfile -> Int
runwayMonthsOr0 cash profile =
  maybe maxBound id (rwMonths (runway start cash profile))
