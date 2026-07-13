{-# LANGUAGE DataKinds #-}

-- | The ledger: an ordered collection of transactions plus the derived cash
-- position over time.
--
-- The ledger is the source of truth the forecaster reads from. It exposes the
-- current balance and a running balance series, both computed purely from the
-- transactions so they can never drift out of sync with the underlying data.
module Runway.Ledger
  ( Ledger
  , mkLedger
  , transactions
  , currentBalance
  , balanceOn
  , runningBalance
  , inflows
  , outflows
  ) where

import Data.List (sortOn)
import Data.Time (Day)
import Runway.Money (Money, add, zero)
import Runway.Transaction

-- | A ledger is a starting cash balance plus the transactions applied to it,
-- kept sorted by date. The invariant "sorted by date ascending" is established
-- once in 'mkLedger' and relied upon everywhere else.
data Ledger = Ledger
  { ledgerOpening :: Money 'USD
  , ledgerTxns    :: [Transaction]  -- ^ always sorted ascending by 'txnDate'
  } deriving (Eq, Show)

-- | Build a ledger from an opening balance and an unordered list of
-- transactions. Sorting here is what lets every other function assume order.
mkLedger :: Money 'USD -> [Transaction] -> Ledger
mkLedger opening txns = Ledger opening (sortOn txnDate txns)

-- | The transactions, in date order.
transactions :: Ledger -> [Transaction]
transactions = ledgerTxns

-- | Cash on hand after applying every transaction (opening + net of all flows).
currentBalance :: Ledger -> Money 'USD
currentBalance (Ledger opening txns) =
  foldr (add . signedAmount) opening txns

-- | Cash on hand as of the end of a given day (inclusive).
balanceOn :: Day -> Ledger -> Money 'USD
balanceOn day (Ledger opening txns) =
  foldr add opening
    [signedAmount t | t <- txns, txnDate t <= day]

-- | The running balance after each transaction, paired with the date it
-- settled. Useful for drawing the historical portion of a cash chart.
runningBalance :: Ledger -> [(Day, Money 'USD)]
runningBalance (Ledger opening txns) = go opening txns
  where
    go _ [] = []
    go bal (t : ts) =
      let bal' = add bal (signedAmount t)
       in (txnDate t, bal') : go bal' ts

inflows :: Ledger -> [Transaction]
inflows = filter isInflow . ledgerTxns

outflows :: Ledger -> [Transaction]
outflows = filter isOutflow . ledgerTxns
