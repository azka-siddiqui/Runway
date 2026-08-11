// The hero of the app: cash balance projected forward over time, with a
// confidence band and a marker for the projected depletion date.
//
// The chart answers the one question that kills startups — "when do we run out
// of money?" — and shows the uncertainty around it rather than a single
// falsely-precise line.

import {
  Area,
  ComposedChart,
  Line,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { ForecastPoint } from "../types";
import { formatCompact, formatMoney, formatMonth } from "../format";

interface RunwayChartProps {
  projection: ForecastPoint[];
  depletionDate: string | null;
}

// Recharts renders a stacked area for the band, so we pre-compute the band
// floor (low) and its thickness (high - low) for each point.
interface Datum {
  date: string;
  balance: number;
  low: number;
  bandThickness: number;
}

function toData(projection: ForecastPoint[]): Datum[] {
  return projection.map((p) => ({
    date: p.date,
    balance: p.balance,
    low: p.low,
    bandThickness: Math.max(0, p.high - p.low),
  }));
}

export function RunwayChart({ projection, depletionDate }: RunwayChartProps) {
  const data = toData(projection);

  return (
    <div className="card p-6">
      <div className="flex items-baseline justify-between">
        <div>
          <div className="eyebrow">Cash projection</div>
          <h2 className="mt-1 text-lg font-semibold">Runway to zero</h2>
        </div>
        <div className="text-sm text-subtle">
          Shaded area is the confidence band (±20% burn)
        </div>
      </div>

      <div className="mt-4 h-80">
        <ResponsiveContainer width="100%" height="100%">
          <ComposedChart data={data} margin={{ top: 8, right: 12, bottom: 0, left: 8 }}>
            <defs>
              <linearGradient id="balanceFill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#5b5bd6" stopOpacity={0.18} />
                <stop offset="100%" stopColor="#5b5bd6" stopOpacity={0} />
              </linearGradient>
            </defs>

            <XAxis
              dataKey="date"
              tickFormatter={formatMonth}
              tick={{ fontSize: 12, fill: "#6b7280" }}
              tickLine={false}
              axisLine={{ stroke: "#e6e8ee" }}
              minTickGap={32}
            />
            <YAxis
              tickFormatter={formatCompact}
              tick={{ fontSize: 12, fill: "#6b7280" }}
              tickLine={false}
              axisLine={false}
              width={56}
            />

            {/* Confidence band: an invisible floor at `low` plus a visible
                stacked area of `bandThickness` on top of it. */}
            <Area
              type="monotone"
              dataKey="low"
              stackId="band"
              stroke="none"
              fill="none"
              isAnimationActive={false}
            />
            <Area
              type="monotone"
              dataKey="bandThickness"
              stackId="band"
              stroke="none"
              fill="#5b5bd6"
              fillOpacity={0.08}
              isAnimationActive={false}
            />

            {/* Zero line: the moment cash runs out. */}
            <ReferenceLine y={0} stroke="#dc2626" strokeDasharray="4 4" />

            {/* Projected depletion date marker. */}
            {depletionDate ? (
              <ReferenceLine
                x={depletionDate}
                stroke="#dc2626"
                strokeDasharray="4 4"
                label={{
                  value: "out of cash",
                  position: "insideTopRight",
                  fill: "#dc2626",
                  fontSize: 11,
                }}
              />
            ) : null}

            {/* Central estimate. */}
            <Line
              type="monotone"
              dataKey="balance"
              stroke="#5b5bd6"
              strokeWidth={2.5}
              dot={false}
              fill="url(#balanceFill)"
            />

            <Tooltip
              formatter={(value: number) => formatMoney(value)}
              labelFormatter={(label: string) => formatMonth(label)}
              contentStyle={{
                borderRadius: 12,
                border: "1px solid #e6e8ee",
                boxShadow: "0 4px 16px rgba(11,15,25,0.08)",
                fontSize: 13,
              }}
            />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
