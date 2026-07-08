{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}

-- | Currency is modelled at the type level so that a value can carry its
-- currency in its type. This lets the compiler reject nonsensical operations
-- such as adding USD to EUR before the program ever runs.
--
-- We deliberately keep the set of supported currencies small and closed. A
-- real system would generate this from an authoritative ISO 4217 list, but a
-- closed set keeps the type-level machinery easy to reason about here.
module Runway.Currency
  ( Currency (..)
  , KnownCurrency (..)
  , currencyCode
  , parseCurrency
  ) where

import Data.Text (Text)
import qualified Data.Text as T

-- | The (closed) set of currencies Runway understands.
--
-- Used both as an ordinary value ('Currency') and, via @DataKinds@, as a type
-- (e.g. @Money 'USD@). Promoting it to the type level is what powers the
-- compile-time currency checks in "Runway.Money".
data Currency = USD | EUR | GBP | CAD
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | Reflect a type-level 'Currency' back down to a value.
--
-- The typeclass has one instance per constructor, so given @Money 'USD@ we can
-- recover the 'USD' value (and its ISO code) at runtime for serialisation.
class KnownCurrency (c :: Currency) where
  currencyVal :: Currency

instance KnownCurrency 'USD where currencyVal = USD
instance KnownCurrency 'EUR where currencyVal = EUR
instance KnownCurrency 'GBP where currencyVal = GBP
instance KnownCurrency 'CAD where currencyVal = CAD

-- | The ISO 4217 alphabetic code for a currency (e.g. @"USD"@).
currencyCode :: Currency -> Text
currencyCode = T.pack . show

-- | Parse an ISO code back into a 'Currency'. Case-insensitive.
parseCurrency :: Text -> Maybe Currency
parseCurrency t =
  lookup (T.toUpper t) [(currencyCode c, c) | c <- [minBound .. maxBound]]
