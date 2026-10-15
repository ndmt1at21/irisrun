import {
  createRootRoute,
  createRoute,
  createRouter,
  type ErrorComponentProps,
  Link,
  redirect,
  type RouterHistory,
} from "@tanstack/react-router";
import { Button } from "./components/ui/button";
import { EmptyState } from "./components/ui/empty-state";
import { ConsoleLayout } from "./console/ConsoleLayout";
import { AddHostPage } from "./console/pages/AddHostPage";
import { ApiKeysPage } from "./console/pages/ApiKeysPage";
import { AuditLogPage } from "./console/pages/AuditLogPage";
import { DataRegionPage } from "./console/pages/DataRegionPage";
import { DevicesPage } from "./console/pages/DevicesPage";
import { LoginPage } from "./console/pages/LoginPage";
import { MacHostsPage } from "./console/pages/MacHostsPage";
import { MembersPage } from "./console/pages/MembersPage";
import { OnboardingPage } from "./console/pages/OnboardingPage";
import { ProjectsPage } from "./console/pages/ProjectsPage";
import { SessionReplayPage } from "./console/pages/SessionReplayPage";
import { SessionsPage } from "./console/pages/SessionsPage";
import { UsagePage } from "./console/pages/UsagePage";
import { DevicePage } from "./device/DevicePage";
import { LiveDevicePage } from "./device/LiveDevicePage";
import { BinaryDoctorPage } from "./device/pages/BinaryDoctorPage";
import { PreviewsPage } from "./device/pages/PreviewsPage";
import { FoundationsPage } from "./gallery/FoundationsPage";
import { GalleryPage } from "./gallery/GalleryPage";

// Every screen takes `?mock=<state>` so the gallery can show each design state.
const rootRoute = createRootRoute({
  validateSearch: (search: Record<string, unknown>): { mock?: string } =>
    search.mock == null ? {} : { mock: String(search.mock) },
});

const deviceRoute = createRoute({ getParentRoute: () => rootRoute, path: "/", component: DevicePage });
const liveRoute = createRoute({ getParentRoute: () => rootRoute, path: "live", component: LiveDevicePage });
const binariesRoute = createRoute({ getParentRoute: () => rootRoute, path: "binaries", component: BinaryDoctorPage });
const previewsRoute = createRoute({ getParentRoute: () => rootRoute, path: "previews", component: PreviewsPage });

const screensRoute = createRoute({ getParentRoute: () => rootRoute, path: "screens" });
const galleryRoute = createRoute({ getParentRoute: () => screensRoute, path: "/", component: GalleryPage });
const foundationsRoute = createRoute({
  getParentRoute: () => screensRoute,
  path: "foundations",
  component: FoundationsPage,
});

const consoleRoute = createRoute({ getParentRoute: () => rootRoute, path: "console" });
const loginRoute = createRoute({ getParentRoute: () => consoleRoute, path: "login", component: LoginPage });
const onboardingRoute = createRoute({ getParentRoute: () => consoleRoute, path: "onboarding", component: OnboardingPage });
const replayRoute = createRoute({
  getParentRoute: () => consoleRoute,
  path: "sessions/$sessionId",
  component: SessionReplayPage,
});

// Pages with the sidebar.
const sidebarRoute = createRoute({ getParentRoute: () => consoleRoute, id: "sidebar", component: ConsoleLayout });
const consoleIndexRoute = createRoute({
  getParentRoute: () => sidebarRoute,
  path: "/",
  beforeLoad: () => {
    throw redirect({ to: "/console/projects" });
  },
});
const projectsRoute = createRoute({ getParentRoute: () => sidebarRoute, path: "projects", component: ProjectsPage });
const sessionsRoute = createRoute({ getParentRoute: () => sidebarRoute, path: "sessions", component: SessionsPage });
const devicesRoute = createRoute({ getParentRoute: () => sidebarRoute, path: "devices", component: DevicesPage });
const hostsRoute = createRoute({ getParentRoute: () => sidebarRoute, path: "hosts", component: MacHostsPage });
const addHostRoute = createRoute({ getParentRoute: () => sidebarRoute, path: "hosts/new", component: AddHostPage });
const membersRoute = createRoute({ getParentRoute: () => sidebarRoute, path: "members", component: MembersPage });
const apiKeysRoute = createRoute({ getParentRoute: () => sidebarRoute, path: "api-keys", component: ApiKeysPage });
const usageRoute = createRoute({ getParentRoute: () => sidebarRoute, path: "usage", component: UsagePage });
const regionRoute = createRoute({ getParentRoute: () => sidebarRoute, path: "region", component: DataRegionPage });
const auditLogRoute = createRoute({ getParentRoute: () => sidebarRoute, path: "audit-log", component: AuditLogPage });

const routeTree = rootRoute.addChildren([
  deviceRoute,
  liveRoute,
  binariesRoute,
  previewsRoute,
  screensRoute.addChildren([galleryRoute, foundationsRoute]),
  consoleRoute.addChildren([
    loginRoute,
    onboardingRoute,
    replayRoute,
    sidebarRoute.addChildren([
      consoleIndexRoute,
      projectsRoute,
      sessionsRoute,
      devicesRoute,
      hostsRoute,
      addHostRoute,
      membersRoute,
      apiKeysRoute,
      usageRoute,
      regionRoute,
      auditLogRoute,
    ]),
  ]),
]);

/** main.tsx passes hash history, since the CLI serves only index.html; tests pass memory history. */
export function createAppRouter(history: RouterHistory) {
  return createRouter({
    routeTree,
    history,
    defaultErrorComponent: RouteError,
    defaultNotFoundComponent: NotFound,
  });
}

declare module "@tanstack/react-router" {
  interface Register {
    router: ReturnType<typeof createAppRouter>;
  }
}

function NotFound() {
  return (
    <EmptyState
      className="min-h-screen"
      title="Page not found"
      description="There is no screen at this address."
      actions={
        <Button asChild variant="outline" size="xs">
          <Link to="/screens">All screens</Link>
        </Button>
      }
    />
  );
}

function RouteError({ error }: ErrorComponentProps) {
  return (
    <EmptyState
      role="alert"
      className="min-h-screen"
      title="Something went wrong"
      description={error instanceof Error ? error.message : String(error)}
    />
  );
}
