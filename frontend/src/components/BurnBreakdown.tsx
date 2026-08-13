// "Where the money goes": total outflow by category, rendered as a ranked set
// of proportional bars. Mirrors the auto-categorisation modern business banks
// apply to spend.

import type { BreakdownEntry } from "../types";
import { formatMoney } from "../format";

interface BurnBreakdownProps {
  breakdown: BreakdownEntry[];
}

// Human-friendly labels for the backend's category constructors.
const label: Record<string, string> = {
  Payroll: "Payroll",
  Software: "Software & SaaS",
  Rent: "Rent",
  Marketing: "Marketing",
  Infrastructure: "Infrastructure",
  ProfessionalServices: "Professional services",
  Revenue: "Revenue",
  Fundraising: "Fundraising",
  Other: "Other",
};

export function BurnBreakdown({ breakdown }: BurnBreakdownProps) {
  // Sort descending so the biggest cost centres surface first.
  const rows = [...breakdown].sort((a, b) => b.amount - a.amount);
  const max = rows.reduce((m, r) => Math.max(m, r.amount), 0);

  return (
    <div className="card p-6">
      <div className="eyebrow">Spend breakdown</div>
      <h2 className="mt-1 text-lg font-semibold">Where the money goes</h2>

      <ul className="mt-5 space-y-4">
        {rows.map((row) => {
          const pct = max > 0 ? (row.amount / max) * 100 : 0;
          return (
            <li key={row.category}>
              <div className="flex items-center justify-between text-sm">
                <span className="font-medium">{label[row.category] ?? row.category}</span>
                <span className="tabular-nums text-subtle">{formatMoney(row.amount)}</span>
              </div>
              <div className="mt-2 h-2 rounded-full bg-muted">
                <div
                  className="h-2 rounded-full bg-accent"
                  style={{ width: `${pct}%` }}
                />
              </div>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
