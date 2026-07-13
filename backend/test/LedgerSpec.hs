{-# LANGUAGE DataKinds #-}

-- | Properties of the ledger. The headline invariant: the current balance is
-- always the opening balance plus the net of every signed transaction, no
-- matter what order the transactions arrive in.
module LedgerSpec (spec) where

import Data.Time (fromGregorian)
import Test.Hspec
import Test.QuickCheck

import Runway.Currency (Currency (USD))
import Runway.Ledger
import Runway.Money
import Runway.Transaction

-- | A generator for arbitrary transactions within a fixed month, so we can
-- shuffle them and confirm order-independence of the balance.
genTxn :: Gen Transaction
genTxn = do
  day       <- choose (1, 28)
  dir       <- elements [Inflow, Outflow]
  cadence   <- elements [OneOff, Monthly, Quarterly, Annual]
  cat       <- elements [Payroll, Software, Revenue, Other]
  dollars   <- choose (0, 100_000) :: Gen Integer
  pure Transaction
    { txnId        = TxnId 0
    , txnDate      = fromGregorian 2026 1 day
    , txnDirection = dir
    , txnCadence   = cadence
    , txnCategory  = cat
    , txnCurrency  = USD
    , txnAmount    = money (fromIntegral dollars) :: Money 'USD
    , txnMemo      = "generated"
    }

spec :: Spec
spec = describe "Runway.Ledger" $ do

  it "balance is opening plus the net of all signed amounts" $
    property $ forAll (listOf genTxn) $ \txns ->
      let opening = money 1_000_000 :: Money 'USD
          ledger  = mkLedger opening txns
          net     = sumMoney (map signedAmount txns)
       in currentBalance ledger === add opening net

  it "balance is independent of input ordering" $
    property $ forAll (listOf genTxn) $ \txns ->
      let opening = money 500_000 :: Money 'USD
       in currentBalance (mkLedger opening txns)
            === currentBalance (mkLedger opening (reverse txns))

  it "running balance ends at the current balance" $
    property $ forAll (listOf1 genTxn) $ \txns ->
      let opening = money 250_000 :: Money 'USD
          ledger  = mkLedger opening txns
          rb      = runningBalance ledger
       in not (null rb) ==> snd (last rb) === currentBalance ledger
