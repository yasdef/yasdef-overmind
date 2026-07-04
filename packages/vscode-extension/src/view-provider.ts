import type { DashboardModel } from "./read-model.js";
import { readDashboard } from "./read-model.js";

export interface DashboardRow {
  label: string;
  description?: string;
}

export function renderDashboard(model: DashboardModel): DashboardRow[] {
  const rows = model.features.flatMap((feature) => {
    const summary = feature.summary;
    const featureRows: DashboardRow[] = [
      {
        label: feature.title,
        description: `${summary.readiness} · ${summary.completedSteps}/${summary.totalSteps} steps`
      }
    ];
    if (summary.missingArtifacts.length > 0) {
      featureRows.push({
        label: "Missing artifacts",
        description: summary.missingArtifacts.join(", ")
      });
    }
    return featureRows;
  });
  const diagnosticRows = model.diagnostics.map((diagnostic) => ({
    label: `${diagnostic.severity}: ${diagnostic.reason}`,
    description: diagnostic.source
  }));
  if (rows.length === 0 && diagnosticRows.length === 0) {
    return [{ label: "No Overmind features found", description: model.workspacePath }];
  }
  return [...rows, ...diagnosticRows];
}

export class DashboardViewProvider {
  public constructor(
    private readonly reader: (startPath: string) => DashboardModel = readDashboard
  ) {}

  public getRows(startPath: string): DashboardRow[] {
    return renderDashboard(this.reader(startPath));
  }
}
