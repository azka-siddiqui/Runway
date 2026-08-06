// A single headline metric (balance, monthly burn, runway, etc.).
//
// Presentational only: it takes fully-formatted strings and an optional tone
// so the parent decides both the value and how alarming it should look.

export type Tone = "neutral" | "positive" | "warning" | "danger";

interface StatCardProps {
  label: string;
  value: string;
  hint?: string;
  tone?: Tone;
}

const toneClass: Record<Tone, string> = {
  neutral: "text-ink",
  positive: "text-positive",
  warning: "text-warning",
  danger: "text-danger",
};

export function StatCard({ label, value, hint, tone = "neutral" }: StatCardProps) {
  return (
    <div className="card p-5">
      <div className="eyebrow">{label}</div>
      <div className={`mt-2 text-3xl font-semibold tracking-tight ${toneClass[tone]}`}>
        {value}
      </div>
      {hint ? <div className="mt-1 text-sm text-subtle">{hint}</div> : null}
    </div>
  );
}
