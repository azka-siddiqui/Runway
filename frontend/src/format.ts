// Presentation helpers for money and dates.
//
// Formatting is centralised so currency and date rendering stay consistent
// across the whole UI and are easy to change in one place.

const usd = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 0,
});

const usdPrecise = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 2,
});

// Whole-dollar currency, e.g. "$2,500,000". Used for large headline figures.
export function formatMoney(value: number): string {
  return usd.format(value);
}

// Cent-precise currency, e.g. "$9,400.00". Used in transaction rows.
export function formatMoneyPrecise(value: number): string {
  return usdPrecise.format(value);
}

// Compact currency for axis labels, e.g. "$2.5M", "$120K".
export function formatCompact(value: number): string {
  const abs = Math.abs(value);
  if (abs >= 1_000_000) return `$${(value / 1_000_000).toFixed(1)}M`;
  if (abs >= 1_000) return `$${Math.round(value / 1_000)}K`;
  return `$${Math.round(value)}`;
}

// "Jul 2026" style month label from an ISO date string.
export function formatMonth(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("en-US", { month: "short", year: "numeric" });
}

// "Jul 1, 2026" style full date.
export function formatDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

// Render a runway month count as human copy. `null` means the company is
// cash-flow positive and never runs out.
export function formatRunway(months: number | null): string {
  if (months === null) return "Cash-flow positive";
  if (months <= 0) return "Out of cash";
  const years = Math.floor(months / 12);
  const rem = months % 12;
  if (years === 0) return `${months} mo`;
  if (rem === 0) return `${years} yr`;
  return `${years} yr ${rem} mo`;
}
