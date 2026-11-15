import { defineConfig, devices } from '@playwright/test';

// ui tests: playwright starts the api (pointed at inat_test_copy, never inat) and the angular app,
// then drives a real chromium browser. stop your own running api and web app first, the ports must be free
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
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: [
    {
      command: 'dotnet run --project ../api/Inat.Api',
      url: 'http://localhost:5092/openapi/v1.json',
      env: { Database__Name: 'inat_test_copy' },
      reuseExistingServer: false,
      timeout: 120_000,
    },
    {
      command: 'npm start',
      url: 'http://localhost:4200',
      reuseExistingServer: false,
      timeout: 120_000,
    },
  ],
});