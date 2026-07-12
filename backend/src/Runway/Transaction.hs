{-# LANGUAGE DataKinds #-}

-- | The transaction model.
--
-- A transaction is a dated movement of money in or out of the business,
-- annotated with enough metadata for the forecasting engine to reason about
-- it: whether it recurs, and which spend/revenue category it belongs to.
module Runway.Transaction
  ( TxnId (..)
  , Direction (..)
  , Cadence (..)
  , Category (..)
  , Transaction (..)
  , signedAmount
  , isInflow
  , isOutflow
  ) where

import Data.Text (Text)
import Data.Time (Day)
import Runway.Currency (Currency)
import Runway.Money (Money, negate')

-- | Opaque identifier for a transaction. A newtype (rather than a bare 'Int')
-- keeps us from accidentally mixing it up with other integer ids.
newtype TxnId = TxnId Int
  deriving (Eq, Ord, Show)

-- | Which way the money moved, from the business's perspective.
data Direction
  = Inflow   -- ^ money coming in (revenue, a raise, a refund)
  | Outflow  -- ^ money going out (payroll, SaaS bills, rent)
  deriving (Eq, Show, Enum, Bounded)

-- | How often a transaction repeats. The forecaster treats recurring
-- transactions as ongoing commitments and one-off transactions as noise that
-- should not drag the projection up or down.
data Cadence
  = OneOff
  | Monthly
  | Quarterly
  | Annual
  deriving (Eq, Show, Enum, Bounded)

-- | A coarse spend/revenue category, mirroring the auto-categorisation that
-- modern business banks apply to transactions.
data Category
  = Payroll
  | Software
  | Rent
  | Marketing
  | Infrastructure
  | ProfessionalServices
  | Revenue
  | Fundraising
  | Other
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | A single ledger entry.
--
-- 'txnCurrency' is stored as a value because transactions are heterogeneous at
-- rest (a business may hold multiple currencies); the type-level guarantees
-- from "Runway.Money" apply once amounts are grouped by currency for analysis.
data Transaction = Transaction
  { txnId       :: TxnId
  , txnDate     :: Day
  , txnDirection :: Direction
  , txnCadence  :: Cadence
  , txnCategory :: Category
  , txnCurrency :: Currency
  , txnAmount   :: Money 'USD
    -- ^ Analysis in this project is single-currency (USD). 'txnCurrency' is
    -- retained for display and future multi-currency support.
  , txnMemo     :: Text
  } deriving (Eq, Show)

-- | The amount signed by direction: inflows positive, outflows negative. This
-- is the value that actually moves the cash balance.
signedAmount :: Transaction -> Money 'USD
signedAmount t = case txnDirection t of
  Inflow  -> txnAmount t
  Outflow -> negate' (txnAmount t)

isInflow :: Transaction -> Bool
isInflow t = txnDirection t == Inflow

isOutflow :: Transaction -> Bool
isOutflow t = txnDirection t == Outflow
