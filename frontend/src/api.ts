// Thin API client for the Runway backend.
//
// All network access lives here so components never touch `fetch` directly.
// Requests go through the Vite dev proxy (see vite.config.ts), which forwards
// /api/* to the Haskell server on :8080.

import type { Dashboard, RunwayResult, Scenario } from "./types";

const BASE = "/api";

// Wrap fetch with JSON handling and a useful error message on non-2xx.
async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...init,
  });
  if (!res.ok) {
    throw new Error(`Request to ${path} failed: ${res.status} ${res.statusText}`);
  }
  return (await res.json()) as T;
}

export function fetchDashboard(): Promise<Dashboard> {
  return request<Dashboard>("/dashboard");
}

export function runScenario(scenario: Scenario): Promise<RunwayResult> {
  return request<RunwayResult>("/scenario", {
    method: "POST",
    body: JSON.stringify(scenario),
  });
}
