import { Page, expect } from '@playwright/test';

// the logins the ui tests use, from environment variables set by tools/run_ui_tests.ps1
export function testUsername(): string {
  return process.env['E2E_USERNAME'] ?? 'jay';
}

export function testPassword(): string {
  return requiredVariable('E2E_PASSWORD');
}

// a Viewer scoped to Amphibia that only exists in inat_test_copy
export function viewerUsername(): string {
  return process.env['E2E_VIEWER_USERNAME'] ?? 'e2e.viewer';
}

export function viewerPassword(): string {
  return requiredVariable('E2E_VIEWER_PASSWORD');
}

export async function logIn(page: Page, username: string = testUsername(), password: string = testPassword()): Promise<void> {
  await page.goto('/login');
  await page.getByLabel('Username').fill(username);
  await page.getByLabel('Password').fill(password);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL(/\/explore/);
}

function requiredVariable(name: string): string {
  const value: string | undefined = process.env[name];

  if (value === undefined || value === '') {
    throw new Error(`${name} is not set. Run the ui tests with tools/run_ui_tests.ps1.`);
  }

  return value;
}