{-# LANGUAGE DataKinds #-}

-- | Properties of the money type. These pin down the arithmetic laws we rely
-- on everywhere else: addition is associative and commutative, zero is the
-- identity, and rounding never invents or loses more than half a cent.
module MoneySpec (spec) where

import Data.Scientific (Scientific)
import Test.Hspec
import Test.QuickCheck

import Runway.Currency (Currency (EUR))
import Runway.Money

-- | Generate a "nice" money value from a bounded decimal so tests stay in a
-- realistic range and avoid pathological huge scientific exponents.
genMoney :: Gen (Money 'USD)
genMoney = do
  dollars <- choose (-1_000_000, 1_000_000) :: Gen Integer
  cents   <- choose (0, 99) :: Gen Integer
  pure (money (fromIntegral dollars + fromIntegral cents / 100))

spec :: Spec
spec = describe "Runway.Money" $ do

  it "zero is the additive identity" $
    property $ forAll genMoney $ \m ->
      add m zero === m .&&. add zero m === m

  it "addition is commutative" $
    property $ forAll genMoney $ \a -> forAll genMoney $ \b ->
      add a b === add b a

  it "addition is associative" $
    property $ forAll genMoney $ \a -> forAll genMoney $ \b -> forAll genMoney $ \c ->
      add (add a b) c === add a (add b c)

  it "subtracting a value from itself gives zero" $
    property $ forAll genMoney $ \m ->
      subtract' m m === zero

  it "sumMoney agrees with folding add" $
    property $ forAll (listOf genMoney) $ \ms ->
      sumMoney ms === foldr add zero ms

  it "constructor rounds to two decimal places" $ do
    -- 1.005 rounds to even (1.00), 1.015 rounds to even (1.02).
    amount (money 1.005 :: Money 'USD) `shouldBe` (1.00 :: Scientific)
    amount (money 1.015 :: Money 'USD) `shouldBe` (1.02 :: Scientific)

  it "rejects cross-currency addition at runtime" $ do
    let usd = toSome (money 10 :: Money 'USD)
        eur = SomeMoney EUR 5
    -- addSome of two different currencies must be Left.
    case addSome usd eur of
      Left _  -> pure ()
      Right _ -> expectationFailure "expected a currency mismatch"
