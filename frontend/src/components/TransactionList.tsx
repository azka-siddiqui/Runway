// Recent activity: the raw ledger, most recent first. A compact table that
// mirrors the "search transactions" surface of a business bank, with a simple
// category filter.

import { useMemo, useState } from "react";
import type { Transaction } from "../types";
import { formatDate, formatMoneyPrecise } from "../format";

interface TransactionListProps {
  transactions: Transaction[];
}

export function TransactionList({ transactions }: TransactionListProps) {
  const [query, setQuery] = useState("");

  // Filter on memo or category, case-insensitively. Memoised so we only
  // recompute when the inputs actually change.
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    const rows = q
      ? transactions.filter(
          (t) =>
            t.memo.toLowerCase().includes(q) ||
            t.category.toLowerCase().includes(q),
        )
      : transactions;
    // Most recent first.
    return [...rows].sort((a, b) => b.date.localeCompare(a.date));
  }, [transactions, query]);

  return (
    <div className="card p-6">
      <div className="flex items-baseline justify-between">
        <div>
          <div className="eyebrow">Activity</div>
          <h2 className="mt-1 text-lg font-semibold">Recent transactions</h2>
        </div>
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search memo or category…"
          className="w-56 rounded-xl border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-accent"
        />
      </div>

      <div className="mt-4 overflow-hidden rounded-xl border border-border">
        <table className="w-full text-sm">
          <thead className="bg-muted text-left text-subtle">
            <tr>
              <th className="px-4 py-2 font-medium">Date</th>
              <th className="px-4 py-2 font-medium">Memo</th>
              <th className="px-4 py-2 font-medium">Category</th>
              <th className="px-4 py-2 text-right font-medium">Amount</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((t) => (
              <tr key={t.id} className="border-t border-border">
                <td className="whitespace-nowrap px-4 py-2 text-subtle">
                  {formatDate(t.date)}
                </td>
                <td className="px-4 py-2">{t.memo}</td>
                <td className="px-4 py-2 text-subtle">{t.category}</td>
                <td
                  className={`px-4 py-2 text-right tabular-nums ${
                    t.direction === "Inflow" ? "text-positive" : "text-ink"
                  }`}
                >
                  {t.direction === "Inflow" ? "+" : "−"}
                  {formatMoneyPrecise(t.amount)}
                </td>
              </tr>
            ))}
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={4} className="px-4 py-6 text-center text-subtle">
                  No transactions match “{query}”.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </div>
  );
}
