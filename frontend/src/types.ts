// Shared domain types.
//
// These deliberately mirror the shapes produced by the Haskell backend
// (see backend/src/Runway/Api.hs). Keeping them in one place means the rest
// of the app talks in domain terms — a ForecastPoint, a Dashboard — rather
// than untyped JSON, so the compiler catches shape mismatches for us.

export type Category =
  | "Payroll"
  | "Software"
  | "Rent"
  | "Marketing"
  | "Infrastructure"
  | "ProfessionalServices"
  | "Revenue"
  | "Fundraising"
  | "Other";

export type Direction = "Inflow" | "Outflow";

export type Cadence = "OneOff" | "Monthly" | "Quarterly" | "Annual";

export interface Transaction {
  id: number;
  date: string; // ISO date (YYYY-MM-DD)
  direction: Direction;
  cadence: Cadence;
  category: Category;
  amount: number; // exact decimal from the backend
  memo: string;
}

export interface ForecastPoint {
  date: string;
  balance: number;
  low: number;
  high: number;
}

export interface BreakdownEntry {
  category: string;
  amount: number;
}

export interface Dashboard {
  balance: number;
  monthlyRevenue: number;
  monthlyExpense: number;
  netBurn: number;
  runwayMonths: number | null; // null means cash-flow positive (never depletes)
  depletionDate: string | null;
  projection: ForecastPoint[];
  breakdown: BreakdownEntry[];
  transactions: Transaction[];
}

// Runway result returned by the scenario endpoint.
export interface RunwayResult {
  runwayMonths: number | null;
  depletionDate: string | null;
  projection: ForecastPoint[];
}

// --- Scenario modelling -----------------------------------------------------
//
// Adjustments are a discriminated union keyed on `kind`. Using a union (rather
// than a bag of optional fields) means each variant only carries the fields it
// actually needs, and exhaustive `switch` statements stay honest.

export type Adjustment =
  | { kind: "hire"; count: number; costEach: number }
  | { kind: "raise"; amount: number }
  | { kind: "adjustExpense"; factor: number }
  | { kind: "adjustRevenue"; factor: number };

export interface Scenario {
  name: string;
  adjustments: Adjustment[];
}
