-- | Test entry point. Hspec discovers and runs each module's spec.
module Main (main) where

import Test.Hspec (hspec)

import qualified ForecastSpec
import qualified LedgerSpec
import qualified MoneySpec

main :: IO ()
main = hspec $ do
  MoneySpec.spec
  LedgerSpec.spec
  ForecastSpec.spec
