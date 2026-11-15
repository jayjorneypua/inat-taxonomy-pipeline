import { defineConfig, devices, type PlaywrightTestConfig } from '@playwright/test';

// ui tests: playwright starts the api (pointed at inat_test_copy, never inat) and the angular app,
// then drives a real chromium browser. stop your own running api and web app first, the ports must be free.
//
// two modes:
//   normal          one api on 5092, angular proxies straight to it
//   load balanced   E2E_LOAD_BALANCED=1 (set by run_ui_tests.ps1 -LoadBalanced): two api instances on 5092 and 5093,
//                   angular proxies to nginx on 8080, which takes turns between them. redis and nginx must be running.

type WebServerConfig = Extract<NonNullable<PlaywrightTestConfig['webServer']>, unknown[]>[number];

const isLoadBalanced: boolean = process.env['E2E_LOAD_BALANCED'] === '1';
const webServers: WebServerConfig[] = [];

if (isLoadBalanced) {
  // run_ui_tests.ps1 builds the api first, so both instances start with --no-build and do not fight over the build output
  webServers.push({
    command: 'dotnet run --project ../api/Inat.Api --no-build -- --urls http://localhost:5092 --Instance:Name api-1',
    url: 'http://localhost:5092/openapi/v1.json',
    env: { Database__Name: 'inat_test_copy' },
    reuseExistingServer: false,
    timeout: 120_000,
  });
  webServers.push({
    command: 'dotnet run --project ../api/Inat.Api --no-build -- --urls http://localhost:5093 --Instance:Name api-2',
    url: 'http://localhost:5093/openapi/v1.json',
    env: { Database__Name: 'inat_test_copy' },
    reuseExistingServer: false,
    timeout: 120_000,
  });
  webServers.push({
    command: 'npm run start:lb',
    url: 'http://localhost:4200',
    reuseExistingServer: false,
    timeout: 120_000,
  });
} else {
  webServers.push({
    command: 'dotnet run --project ../api/Inat.Api',
    url: 'http://localhost:5092/openapi/v1.json',
    env: { Database__Name: 'inat_test_copy' },
    reuseExistingServer: false,
    timeout: 120_000,
  });
  webServers.push({
    command: 'npm start',
    url: 'http://localhost:4200',
    reuseExistingServer: false,
    timeout: 120_000,
  });
}

export default defineConfig({
  testDir: './e2e',
  timeout: 60_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: 'http://localhost:4200',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    launchOptions: {
      // with -Headed, every click and keystroke is slowed down so a person can follow along
      slowMo: Number(process.env['E2E_SLOW_MOTION_MILLISECONDS'] ?? '0'),
    },
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: webServers,
});