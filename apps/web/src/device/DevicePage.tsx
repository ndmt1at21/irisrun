import { Link } from "@tanstack/react-router";
import { Button } from "../components/ui/button";
import { EmptyState } from "../components/ui/empty-state";
import { useMock } from "../lib/mock";
import { scenarios } from "../mocks/scenarios";

/** Route `/`: the Device UI in the mock scenario named by `?mock=`, Android running by default. */
export function DevicePage() {
  const id = useMock() ?? "android-running";
  const scenario = scenarios.find((candidate) => candidate.id === id);
  if (!scenario) {
    return (
      <EmptyState
        className="min-h-screen"
        title={`No scenario called “${id}”`}
        description="The gallery lists every scenario."
        actions={
          <Button asChild variant="outline" size="xs">
            <Link to="/screens">All screens</Link>
          </Button>
        }
      />
    );
  }
  return <scenario.render key={scenario.id} />;
}
