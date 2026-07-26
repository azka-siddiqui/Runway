{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | SQLite persistence for the ledger.
--
-- Amounts are stored as integer minor units (cents), never as floats. This is
-- the database-level counterpart to the "money is never a Double" rule in
-- "Runway.Money": storing cents as INTEGER means the database can neither
-- round nor lose precision on our behalf.
module Runway.Store
  ( initDb
  , insertTransaction
  , loadTransactions
  , loadOpeningBalance
  , setOpeningBalance
  ) where

import Data.Scientific (Scientific)
import qualified Data.Text as T
import Data.Time (Day)
import Database.SQLite.Simple
import Database.SQLite.Simple.FromRow (FromRow (..))
import Runway.Currency (Currency, currencyCode, parseCurrency)
import Runway.Money (Money, amount, fromMinorUnits)
import Runway.Transaction

-- | Create the schema if it does not already exist. Written to read like the
-- Postgres schema it would become in production (integer cents, enum-as-text).
initDb :: Connection -> IO ()
initDb conn = do
  execute_ conn
    "CREATE TABLE IF NOT EXISTS meta (\
    \  key TEXT PRIMARY KEY,\
    \  value TEXT NOT NULL)"
  execute_ conn
    "CREATE TABLE IF NOT EXISTS transactions (\
    \  id         INTEGER PRIMARY KEY,\
    \  date       TEXT NOT NULL,\
    \  direction  TEXT NOT NULL,\
    \  cadence    TEXT NOT NULL,\
    \  category   TEXT NOT NULL,\
    \  currency   TEXT NOT NULL,\
    \  amount_cents INTEGER NOT NULL,\
    \  memo       TEXT NOT NULL)"

-- | Row representation used only for I/O; we convert to/from the rich domain
-- 'Transaction' at the boundary so the domain never depends on SQLite.
data TxnRow = TxnRow Int Day T.Text T.Text T.Text T.Text Integer T.Text

instance FromRow TxnRow where
  fromRow =
    TxnRow <$> field <*> field <*> field <*> field
           <*> field <*> field <*> field <*> field

toDomain :: TxnRow -> Transaction
toDomain (TxnRow i d dir cad cat cur cents memo) =
  Transaction
    { txnId        = TxnId i
    , txnDate      = d
    , txnDirection = parseDirection dir
    , txnCadence   = parseCadence cad
    , txnCategory  = parseCategory cat
    , txnCurrency  = maybe (error "bad currency in db") id (parseCurrency cur)
    , txnAmount    = fromMinorUnits cents :: Money 'USD
    , txnMemo      = memo
    }

-- | Persist a transaction, storing the amount as integer cents.
insertTransaction :: Connection -> Transaction -> IO ()
insertTransaction conn t =
  execute conn
    "INSERT INTO transactions \
    \(date, direction, cadence, category, currency, amount_cents, memo) \
    \VALUES (?,?,?,?,?,?,?)"
    ( txnDate t
    , T.pack (show (txnDirection t))
    , T.pack (show (txnCadence t))
    , T.pack (show (txnCategory t))
    , currencyCode (txnCurrency t)
    , toCents (txnAmount t)
    , txnMemo t
    )

-- | Load every transaction, in date order.
loadTransactions :: Connection -> IO [Transaction]
loadTransactions conn = do
  rows <- query_ conn
    "SELECT id, date, direction, cadence, category, currency, amount_cents, memo \
    \FROM transactions ORDER BY date ASC"
  pure (map toDomain rows)

-- | Read the opening balance from the meta table (defaults to zero cents).
loadOpeningBalance :: Connection -> IO (Money 'USD)
loadOpeningBalance conn = do
  rows <- query conn "SELECT value FROM meta WHERE key = ?" (Only ("opening_cents" :: T.Text))
  case rows of
    (Only v : _) -> pure (fromMinorUnits (read (T.unpack v)) :: Money 'USD)
    _            -> pure (fromMinorUnits 0)

-- | Persist the opening balance.
setOpeningBalance :: Connection -> Money 'USD -> IO ()
setOpeningBalance conn m =
  execute conn
    "INSERT INTO meta (key, value) VALUES (?, ?) \
    \ON CONFLICT(key) DO UPDATE SET value = excluded.value"
    ("opening_cents" :: T.Text, T.pack (show (toCents m)))

-- Helpers ---------------------------------------------------------------------

-- | Convert an amount to integer cents for storage.
toCents :: Money 'USD -> Integer
toCents m = round (amount m * 100 :: Scientific)

parseDirection :: T.Text -> Direction
parseDirection "Inflow" = Inflow
parseDirection _        = Outflow

parseCadence :: T.Text -> Cadence
parseCadence "Monthly"   = Monthly
parseCadence "Quarterly" = Quarterly
parseCadence "Annual"    = Annual
parseCadence _           = OneOff

parseCategory :: T.Text -> Category
parseCategory t = case t of
  "Payroll"              -> Payroll
  "Software"             -> Software
  "Rent"                 -> Rent
  "Marketing"            -> Marketing
  "Infrastructure"       -> Infrastructure
  "ProfessionalServices" -> ProfessionalServices
  "Revenue"              -> Revenue
  "Fundraising"          -> Fundraising
  _                      -> Other
