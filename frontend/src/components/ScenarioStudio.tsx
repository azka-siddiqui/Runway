// Interactive what-if modelling.
//
// The user flexes a few levers — new hires, a funding round, spend cuts,
// revenue growth — and we ask the backend to recompute the runway under those
// assumptions. The result is compared against the baseline so the impact of a
// decision is immediately legible.

import { useState } from "react";
import type { Adjustment, RunwayResult, Scenario } from "../types";
import { runScenario } from "../api";
import { formatRunway } from "../format";

interface ScenarioStudioProps {
  baselineRunwayMonths: number | null;
}

// Local control state for the four levers.
interface Levers {
  hires: number;
  costPerHire: number;
  raise: number;
  expenseFactor: number; // 1.0 = no change
  revenueFactor: number; // 1.0 = no change
}

const initialLevers: Levers = {
  hires: 0,
  costPerHire: 15000,
  raise: 0,
  expenseFactor: 1,
  revenueFactor: 1,
};

// Translate the UI levers into the backend's adjustment union, dropping any
// lever left at its neutral value so we only send meaningful changes.
function toAdjustments(l: Levers): Adjustment[] {
  const adjustments: Adjustment[] = [];
  if (l.hires > 0) {
    adjustments.push({ kind: "hire", count: l.hires, costEach: l.costPerHire });
  }
  if (l.raise > 0) {
    adjustments.push({ kind: "raise", amount: l.raise });
  }
  if (l.expenseFactor !== 1) {
    adjustments.push({ kind: "adjustExpense", factor: l.expenseFactor });
  }
  if (l.revenueFactor !== 1) {
    adjustments.push({ kind: "adjustRevenue", factor: l.revenueFactor });
  }
  return adjustments;
}

export function ScenarioStudio({ baselineRunwayMonths }: ScenarioStudioProps) {
  const [levers, setLevers] = useState<Levers>(initialLevers);
  const [result, setResult] = useState<RunwayResult | null>(null);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Narrowly-typed setter so each control updates exactly one lever.
  function update<K extends keyof Levers>(key: K, value: Levers[K]) {
    setLevers((prev) => ({ ...prev, [key]: value }));
    setResult(null); // invalidate a stale result when inputs change
  }

  async function run() {
    setPending(true);
    setError(null);
    try {
      const scenario: Scenario = {
        name: "custom scenario",
        adjustments: toAdjustments(levers),
      };
      setResult(await runScenario(scenario));
    } catch (e) {
      setError(e instanceof Error ? e.message : "scenario failed");
    } finally {
      setPending(false);
    }
  }

  function reset() {
    setLevers(initialLevers);
    setResult(null);
    setError(null);
  }

  const delta =
    result && result.runwayMonths !== null && baselineRunwayMonths !== null
      ? result.runwayMonths - baselineRunwayMonths
      : null;

  return (
    <div className="card p-6">
      <div className="eyebrow">Scenario studio</div>
      <h2 className="mt-1 text-lg font-semibold">Model a decision</h2>
      <p className="mt-1 text-sm text-subtle">
        Adjust the levers, then recompute runway under those assumptions.
      </p>

      <div className="mt-5 space-y-5">
        <SliderRow
          label="New hires"
          value={levers.hires}
          min={0}
          max={20}
          step={1}
          display={`${levers.hires}`}
          onChange={(v) => update("hires", v)}
        />
        <SliderRow
          label="Cost per hire / mo"
          value={levers.costPerHire}
          min={5000}
          max={30000}
          step={1000}
          display={`$${levers.costPerHire.toLocaleString()}`}
          onChange={(v) => update("costPerHire", v)}
        />
        <SliderRow
          label="Raise capital"
          value={levers.raise}
          min={0}
          max={5_000_000}
          step={250_000}
          display={`$${levers.raise.toLocaleString()}`}
          onChange={(v) => update("raise", v)}
        />
        <SliderRow
          label="Expense change"
          value={levers.expenseFactor}
          min={0.5}
          max={1.5}
          step={0.05}
          display={`${Math.round(levers.expenseFactor * 100)}%`}
          onChange={(v) => update("expenseFactor", v)}
        />
        <SliderRow
          label="Revenue change"
          value={levers.revenueFactor}
          min={0.5}
          max={3}
          step={0.05}
          display={`${Math.round(levers.revenueFactor * 100)}%`}
          onChange={(v) => update("revenueFactor", v)}
        />
      </div>

      <div className="mt-6 flex items-center gap-3">
        <button
          onClick={run}
          disabled={pending}
          className="rounded-xl bg-accent px-4 py-2 text-sm font-medium text-white transition hover:opacity-90 disabled:opacity-50"
        >
          {pending ? "Computing…" : "Recompute runway"}
        </button>
        <button
          onClick={reset}
          className="rounded-xl border border-border px-4 py-2 text-sm font-medium text-subtle transition hover:bg-muted"
        >
          Reset
        </button>
      </div>

      {error ? <p className="mt-4 text-sm text-danger">{error}</p> : null}

      {result ? (
        <div className="mt-6 rounded-xl bg-accent-soft p-4">
          <div className="eyebrow">Projected runway</div>
          <div className="mt-1 flex items-baseline gap-3">
            <span className="text-2xl font-semibold">
              {formatRunway(result.runwayMonths)}
            </span>
            {delta !== null ? (
              <span
                className={`text-sm font-medium ${
                  delta >= 0 ? "text-positive" : "text-danger"
                }`}
              >
                {delta >= 0 ? "+" : ""}
                {delta} mo vs. today
              </span>
            ) : null}
          </div>
        </div>
      ) : null}
    </div>
  );
}

// A labelled range input with a live value readout.
interface SliderRowProps {
  label: string;
  value: number;
  min: number;
  max: number;
  step: number;
  display: string;
  onChange: (value: number) => void;
}

function SliderRow({ label, value, min, max, step, display, onChange }: SliderRowProps) {
  return (
    <div>
      <div className="flex items-center justify-between text-sm">
        <label className="font-medium">{label}</label>
        <span className="tabular-nums text-subtle">{display}</span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className="mt-2 w-full accent-accent"
      />
    </div>
  );
}
