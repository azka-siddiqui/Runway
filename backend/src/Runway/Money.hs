{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

-- | The money type.
--
-- Two rules drive this module:
--
--   1. Money is never a 'Double'. Binary floating point cannot represent most
--      decimal amounts exactly, so we back 'Money' with 'Scientific', which
--      stores an exact decimal. This is the single most important decision in
--      a financial codebase.
--
--   2. Money carries its currency in its type (@Money 'USD@). Because the
--      currency is a phantom type parameter, @add@ can only ever combine two
--      amounts of the /same/ currency; @Money 'USD -> Money 'EUR@ simply does
--      not type-check. Illegal states are unrepresentable.
module Runway.Money
  ( Money
  , CurrencyMismatch (..)
  -- * Construction
  , money
  , fromMinorUnits
  , zero
  -- * Total arithmetic (same-currency, checked by the type system)
  , add
  , subtract'
  , scale
  , negate'
  , sumMoney
  -- * Cross-currency arithmetic (checked at runtime)
  , SomeMoney (..)
  , toSome
  , addSome
  -- * Inspection
  , amount
  , currencyOf
  , isNegative
  , isPositive
  ) where

import Data.List (foldl')
import Data.Scientific (Scientific)
import Runway.Currency

-- | An exact monetary amount tagged with its currency at the type level.
--
-- The constructor is intentionally /not/ exported: callers must go through
-- 'money' (or the other smart constructors) so we control how amounts are
-- rounded and validated.
newtype Money (c :: Currency) = Money Scientific
  deriving (Eq, Ord)

instance KnownCurrency c => Show (Money c) where
  show (Money s) = show s <> " " <> show (currencyVal @c)

-- | Build an amount from a decimal value. Amounts are normalised to the
-- currency's minor-unit precision (2 decimal places for the currencies we
-- support) using banker's rounding to avoid systematic bias.
money :: forall c. KnownCurrency c => Scientific -> Money c
money = Money . roundTo 2

-- | Build an amount from integer minor units (e.g. cents). This is the safest
-- way to construct money from a database or API where amounts are stored as
-- integers to sidestep decimal issues entirely.
fromMinorUnits :: forall c. KnownCurrency c => Integer -> Money c
fromMinorUnits minor = Money (fromInteger minor / 100)

-- | The additive identity for a currency.
zero :: KnownCurrency c => Money c
zero = money 0

-- | Add two amounts of the same currency. The shared @c@ makes cross-currency
-- addition a compile error rather than a runtime bug.
add :: Money c -> Money c -> Money c
add (Money a) (Money b) = Money (a + b)

-- | Subtract the second amount from the first (same currency).
subtract' :: Money c -> Money c -> Money c
subtract' (Money a) (Money b) = Money (a - b)

-- | Multiply an amount by a scalar (e.g. a headcount or a growth factor),
-- re-rounding to minor-unit precision afterwards.
scale :: forall c. KnownCurrency c => Scientific -> Money c -> Money c
scale k (Money a) = money (k * a)

-- | Negate an amount.
negate' :: Money c -> Money c
negate' (Money a) = Money (negate a)

-- | Sum a list of same-currency amounts.
sumMoney :: KnownCurrency c => [Money c] -> Money c
sumMoney = foldl' add zero

-- | The raw decimal amount, discarding the currency tag.
amount :: Money c -> Scientific
amount (Money a) = a

-- | Reflect the phantom currency down to a value.
currencyOf :: forall c. KnownCurrency c => Money c -> Currency
currencyOf _ = currencyVal @c

isNegative :: Money c -> Bool
isNegative (Money a) = a < 0

isPositive :: Money c -> Bool
isPositive (Money a) = a > 0

-- Cross-currency handling -----------------------------------------------------

-- | Raised when two amounts of different currencies are combined at runtime.
-- Compile-time checks cover the common path; this covers the case where the
-- currency is only known dynamically (e.g. decoded from JSON).
data CurrencyMismatch = CurrencyMismatch Currency Currency
  deriving (Eq, Show)

-- | An amount whose currency is only known at runtime.
--
-- When money crosses a serialisation boundary we lose the type-level currency,
-- so we pack the reflected 'Currency' alongside the raw amount and re-check
-- compatibility explicitly.
data SomeMoney = SomeMoney Currency Scientific
  deriving (Eq, Show)

-- | Forget the type-level currency, keeping it as a value.
toSome :: forall c. KnownCurrency c => Money c -> SomeMoney
toSome (Money a) = SomeMoney (currencyVal @c) a

-- | Add two runtime-tagged amounts, failing loudly on a currency mismatch.
addSome :: SomeMoney -> SomeMoney -> Either CurrencyMismatch SomeMoney
addSome (SomeMoney c1 a1) (SomeMoney c2 a2)
  | c1 == c2  = Right (SomeMoney c1 (a1 + a2))
  | otherwise = Left (CurrencyMismatch c1 c2)

-- Internal --------------------------------------------------------------------

-- | Round a 'Scientific' to @n@ decimal places using round-half-to-even
-- (banker's rounding). Implemented on 'Rational' to stay exact.
roundTo :: Int -> Scientific -> Scientific
roundTo n s = fromRational (roundRat (toRational s))
  where
    factor = 10 ^ n :: Integer
    roundRat r =
      let scaled = r * fromInteger factor
          rounded = roundHalfEven scaled
       in fromInteger rounded / fromInteger factor

-- | Round a 'Rational' to the nearest integer, ties going to the even integer.
roundHalfEven :: Rational -> Integer
roundHalfEven r =
  let down = floor r
      frac = r - fromInteger down
   in case compare frac 0.5 of
        LT -> down
        GT -> down + 1
        EQ -> if even down then down else down + 1
