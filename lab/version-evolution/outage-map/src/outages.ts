// @gloss represents grid:Outage
export interface OutageEvent {
  id: string;
  feederId: string;
  startedAt: string;
  restoredAt?: string;
  customersAffected: number;
}

export function isOpen(outage: OutageEvent): boolean {
  return outage.restoredAt === undefined;
}
