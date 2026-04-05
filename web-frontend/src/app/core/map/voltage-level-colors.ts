/**
 * Цвета линий и подстанций по напряжению (кВ) — единая схема с Flutter.
 */
const BY_NOMINAL_KV: Record<number, string> = {
  750: '#008000',
  330: '#00A500',
  220: '#C0C000',
  110: '#17A2B8',
  35: '#96854F',
  10: '#A668A6',
  6: '#F5B88A',
  0.4: '#B0B0B0',
};

const NOMINALS: number[] = [750, 330, 220, 110, 35, 10, 6, 0.4];

/** Магистраль чуть толще отпайки */
export const LINE_WEIGHT_MAIN = 4;
export const LINE_WEIGHT_TAP = 3;

export function colorForVoltageKv(kv: number | null | undefined): string {
  if (kv == null || kv <= 0 || Number.isNaN(kv)) {
    return BY_NOMINAL_KV[0.4];
  }
  let best: number = 0.4;
  let bestDiff = Infinity;
  for (const n of NOMINALS) {
    const d = Math.abs(kv - n);
    if (d < bestDiff) {
      bestDiff = d;
      best = n;
    }
  }
  return BY_NOMINAL_KV[best] ?? BY_NOMINAL_KV[0.4];
}

export function lineWeightForBranch(isTap: boolean): number {
  return isTap ? LINE_WEIGHT_TAP : LINE_WEIGHT_MAIN;
}
