{-# LANGUAGE OverloadedStrings #-}

-- | Entry point.
--
-- Opens (and seeds, if empty) the SQLite database, loads the ledger into
-- memory, and serves the Runway API on port 8080. The forecast origin is fixed
-- to a date inside the seed window so the demo is deterministic regardless of
-- the wall clock.
module Main (main) where

import Control.Monad (when)
import Data.Time (fromGregorian)
import Database.SQLite.Simple (open, close)
import Network.Wai.Handler.Warp (run)
import System.Directory (doesFileExist)

import Runway.Api (app)
import Runway.Ledger (mkLedger)
import Runway.Seed (loadSeed)
import Runway.Store (initDb, loadOpeningBalance, loadTransactions)

dbPath :: FilePath
dbPath = "runway.db"

port :: Int
port = 8080

main :: IO ()
main = do
  fresh <- not <$> doesFileExist dbPath
  conn <- open dbPath
  initDb conn
  -- Seed only a brand-new database so restarts do not duplicate rows.
  when fresh (loadSeed conn)

  opening <- loadOpeningBalance conn
  txns <- loadTransactions conn
  let ledger = mkLedger opening txns
      -- Forecast origin pinned to the end of the seed window for a
      -- deterministic demo, independent of the wall clock.
      today  = fromGregorian 2026 7 1

  putStrLn ("Runway API listening on http://localhost:" <> show port)
  run port (app today ledger)
  close conn
