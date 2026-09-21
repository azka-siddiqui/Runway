# Runway

Runway ingests a startup's transaction ledger and projects the
future: burn rate, runway-to-zero, a confidence band around the cash-depletion date, and
interactive what-if scenarios.

Most founder-facing banking tools look *backwards* — here's your balance, here are your
transactions. Runway looks *forwards* and answers the question that actually kills
companies: **"how many months until we run out of money, and what changes that?"** Running
out of cash is consistently the number-one cause of startup failure, and most teams
misforecast their liquidity — so the goal here is an honest projection with visible
uncertainty rather than a single false-precision number.

It's built as two halves that mirror a modern fintech stack:

- **Backend** — a type-safe financial core in **Haskell** (Servant + SQLite). The type
  system is used deliberately to make whole classes of money bugs *fail to compile*.
- **Frontend** — a polished **TypeScript + React** app (Vite + Tailwind) with a runway
  chart, spend breakdown, and an interactive scenario studio.

> This started as a personal project to explore how far Haskell's type system can push
> correctness in financial code, paired with a UI I'd actually want to look at.

---

## Why the types matter

The core design rule is **make illegal states unrepresentable**:

- **Money is never a `Double`.** Amounts are backed by an exact decimal (`Scientific`),
  and stored in SQLite as integer cents. Binary floating point can't represent most
  decimal amounts exactly, which is how money quietly leaks in financial software.
- **Currency lives in the type.** `Money 'USD` and `Money 'EUR` are *different types*.
  Adding them isn't a runtime check — it simply doesn't compile. Cross-currency math is
  only possible through an explicit, checked path (`addSome`).
- **The forecast invariants are property-tested.** QuickCheck proves the facts a founder
  would expect: more cash never shortens the runway, more burn never lengthens it, and a
  ledger's balance is always its opening balance plus the net of every signed
  transaction — regardless of input order.

## Architecture

```
runway/
├── backend/                 Haskell — the financial core + HTTP API
│   ├── src/Runway/
│   │   ├── Currency.hs        type-level currencies
│   │   ├── Money.hs           exact, currency-tagged money
│   │   ├── Transaction.hs     the ledger entry model
│   │   ├── Ledger.hs          balances + running balance
│   │   ├── Burn.hs            burn-rate engine (recurring vs one-off)
│   │   ├── Forecast.hs        runway projection + confidence band
│   │   ├── Scenario.hs        what-if modelling
│   │   ├── Store.hs           SQLite persistence (integer cents)
│   │   ├── Seed.hs            realistic demo dataset
│   │   └── Api.hs             Servant API (types == contract)
│   ├── app/Main.hs           server entry point
│   └── test/                 Hspec + QuickCheck property tests
└── frontend/                TypeScript + React — the UI
    └── src/
        ├── types.ts          domain types mirroring the API
        ├── api.ts            typed API client
        ├── format.ts         money / date presentation
        └── components/       StatCard, RunwayChart, BurnBreakdown,
                              ScenarioStudio, TransactionList
```

The frontend's `types.ts` intentionally mirrors the JSON shapes the backend emits, so the
type-safety story runs end to end: the compiler checks the wire contract on both sides.

## Running it

> **Note on environments.** The two halves are built and run with their native toolchains
> — GHC/Cabal for the backend and Node/npm for the frontend. Both are standard; there's
> nothing exotic to install beyond a Haskell toolchain and Node 18+.

### Backend

```bash
cd backend
cabal run runway          # seeds runway.db on first run, serves on :8080
cabal test                # runs the Hspec + QuickCheck suite
```

The API exposes:

- `GET /dashboard` — balance, burn profile, runway, spend breakdown, transactions
- `POST /scenario` — apply what-if adjustments and get back a recomputed runway

### Frontend

```bash
cd frontend
npm install
npm run dev               # Vite dev server on :5173, proxies /api -> :8080
npm run typecheck         # strict tsc, no emit
```

Open <http://localhost:5173> with the backend running.

## Tech

**Backend:** Haskell (GHC2021), Servant, warp, sqlite-simple, aeson, Hspec, QuickCheck.
**Frontend:** TypeScript (strict), React 18, Vite, Tailwind CSS, Recharts.

## License

MIT — see [LICENSE](./LICENSE).
