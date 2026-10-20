import type { OutageEvent } from "./outages";

export interface ReadingMessage {
  meter_id: string;
  taken_at: string;
}

const SILENT_AFTER_MS = 30 * 60 * 1000;

// @gloss implements omap:OutageLayer
export class OutageLayer {
  private lastSeen = new Map<string, number>();
  private reported = new Map<string, OutageEvent>();

  onReading(msg: ReadingMessage): void {
    this.lastSeen.set(msg.meter_id, Date.parse(msg.taken_at));
  }

  onOutage(event: OutageEvent): void {
    this.reported.set(event.id, event);
  }

  darkMeters(now: number): string[] {
    return [...this.lastSeen.entries()]
      .filter(([, seen]) => now - seen > SILENT_AFTER_MS)
      .map(([meterId]) => meterId);
  }
}
