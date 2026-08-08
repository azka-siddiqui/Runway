// Top-level application shell.
//
// Loads the dashboard once on mount, then lays out the runway chart, the
// headline stats, the spend breakdown, the scenario studio, and the
// transaction list. Loading and error states are handled explicitly so the UI
// never renders against undefined data.

import { useEffect, useState, type ReactNode } from "react";
import type { Dashboard } from "./types";
import { fetchDashboard } from "./api";
import { formatMoney, formatRunway } from "./format";
import { StatCard, type Tone } from "./components/StatCard";
import { RunwayChart } from "./components/RunwayChart";
import { BurnBreakdown } from "./components/BurnBreakdown";
import { ScenarioStudio } from "./components/ScenarioStudio";
import { TransactionList } from "./components/TransactionList";

// Choose how alarming the runway stat looks based on how much time is left.
// Under six months is a real emergency for a startup, so it goes red.
function runwayTone(months: number | null): Tone {
  if (months === null) return "positive";
  if (months <= 6) return "danger";
  if (months <= 12) return "warning";
  return "neutral";
}

export function App() {
  const [data, setData] = useState<Dashboard | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchDashboard()
      .then(setData)
      .catch((e: unknown) =>
        setError(e instanceof Error ? e.message : "failed to load dashboard"),
      );
  }, []);

  if (error) {
    return (
      <Centered>
        <div className="card max-w-md p-8 text-center">
          <h1 className="text-lg font-semibold text-danger">Could not load Runway</h1>
          <p className="mt-2 text-sm text-subtle">{error}</p>
          <p className="mt-4 text-sm text-subtle">
            Is the backend running on <code>:8080</code>?
          </p>
        </div>
      </Centered>
    );
  }

  if (!data) {
    return (
      <Centered>
        <div className="text-subtle">Loading your numbers…</div>
      </Centered>
    );
  }

  return (
    <div className="min-h-screen">
      <header className="border-b border-border bg-surface">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <div className="flex items-center gap-2">
            <div className="h-6 w-6 rounded-lg bg-accent" />
            <span className="text-lg font-semibold tracking-tight">Runway</span>
          </div>
          <span className="text-sm text-subtle">Photon Labs · demo workspace</span>
        </div>
      </header>

      <main className="mx-auto max-w-6xl space-y-6 px-6 py-8">
        {/* Headline stats. */}
        <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard label="Cash on hand" value={formatMoney(data.balance)} />
          <StatCard
            label="Net monthly burn"
            value={formatMoney(data.netBurn)}
            hint={`${formatMoney(data.monthlyRevenue)} in · ${formatMoney(
              data.monthlyExpense,
            )} out`}
          />
          <StatCard
            label="Runway"
            value={formatRunway(data.runwayMonths)}
            tone={runwayTone(data.runwayMonths)}
            hint={data.depletionDate ? `runs out ~${data.depletionDate}` : "healthy"}
          />
          <StatCard
            label="Monthly revenue"
            value={formatMoney(data.monthlyRevenue)}
            tone="positive"
          />
        </section>

        {/* Hero chart. */}
        <RunwayChart projection={data.projection} depletionDate={data.depletionDate} />

        {/* Breakdown + scenario side by side on wide screens. */}
        <section className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <BurnBreakdown breakdown={data.breakdown} />
          <ScenarioStudio baselineRunwayMonths={data.runwayMonths} />
        </section>

        <TransactionList transactions={data.transactions} />
      </main>

      <footer className="mx-auto max-w-6xl px-6 py-8 text-center text-sm text-subtle">
        Runway · a type-safe cash-flow forecasting demo
      </footer>
    </div>
  );
}

// Small helper for full-screen centred states (loading / error).
function Centered({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen items-center justify-center px-6">{children}</div>
  );
}
