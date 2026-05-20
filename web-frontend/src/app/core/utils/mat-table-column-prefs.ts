export interface TableColumnDef {
  id: string;
  label: string;
  defaultVisible?: boolean;
  defaultWidth?: string;
}

export interface TableColumnPrefsState {
  visible: string[];
  widths: Record<string, string>;
}

/** Сохранение видимости и ширины колонок mat-table в localStorage. */
export class MatTableColumnPrefs {
  private state: TableColumnPrefsState;

  constructor(
    private readonly storageKey: string,
    private readonly defs: TableColumnDef[],
  ) {
    this.state = this.load();
  }

  get visibleColumns(): string[] {
    return this.state.visible.filter((id) => this.defs.some((d) => d.id === id));
  }

  get allColumns(): TableColumnDef[] {
    return this.defs;
  }

  isVisible(id: string): boolean {
    return this.state.visible.includes(id);
  }

  toggleColumn(id: string, visible: boolean): void {
    const set = new Set(this.state.visible);
    if (visible) {
      set.add(id);
    } else {
      if (set.size <= 1) {
        return;
      }
      set.delete(id);
    }
    this.state.visible = this.defs.map((d) => d.id).filter((cid) => set.has(cid));
    this.persist();
  }

  columnWidth(id: string): string | undefined {
    return this.state.widths[id] || this.defs.find((d) => d.id === id)?.defaultWidth;
  }

  setColumnWidth(id: string, widthPx: number): void {
    if (!Number.isFinite(widthPx) || widthPx < 48) {
      return;
    }
    this.state.widths[id] = `${Math.round(widthPx)}px`;
    this.persist();
  }

  captureWidthsFromTable(table: HTMLElement | null | undefined): void {
    if (!table) {
      return;
    }
    const headers = table.querySelectorAll<HTMLElement>('thead tr th');
    headers.forEach((th, index) => {
      const colId = this.state.visible[index];
      if (!colId) {
        return;
      }
      const w = th.offsetWidth;
      if (w > 0) {
        this.state.widths[colId] = `${w}px`;
      }
    });
    this.persist();
  }

  reset(): void {
    localStorage.removeItem(this.storageKey);
    this.state = this.defaultState();
  }

  private load(): TableColumnPrefsState {
    try {
      const raw = localStorage.getItem(this.storageKey);
      if (!raw) {
        return this.defaultState();
      }
      const parsed = JSON.parse(raw) as TableColumnPrefsState;
      const validIds = new Set(this.defs.map((d) => d.id));
      const visible = (parsed.visible || []).filter((id) => validIds.has(id));
      if (visible.length === 0) {
        return this.defaultState();
      }
      const widths: Record<string, string> = {};
      for (const [k, v] of Object.entries(parsed.widths || {})) {
        if (validIds.has(k) && typeof v === 'string') {
          widths[k] = v;
        }
      }
      return { visible, widths };
    } catch {
      return this.defaultState();
    }
  }

  private defaultState(): TableColumnPrefsState {
    return {
      visible: this.defs.filter((d) => d.defaultVisible !== false).map((d) => d.id),
      widths: Object.fromEntries(
        this.defs.filter((d) => d.defaultWidth).map((d) => [d.id, d.defaultWidth!]),
      ),
    };
  }

  private persist(): void {
    localStorage.setItem(this.storageKey, JSON.stringify(this.state));
  }
}
