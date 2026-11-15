import { Page, expect } from '@playwright/test';

// the login the ui tests use, from environment variables set by tools/run_ui_tests.ps1
export function testUsername(): string {
  return process.env['E2E_USERNAME'] ?? 'jay';
}

export function testPassword(): string {
  const password: string | undefined = process.env['E2E_PASSWORD'];

  if (password === undefined || password === '') {
    throw new Error('E2E_PASSWORD is not set. Run the ui tests with tools/run_ui_tests.ps1.');
  }

  return password;
}

export async function logIn(page: Page): Promise<void> {
  await page.goto('/login');
  await page.getByLabel('Username').fill(testUsername());
  await page.getByLabel('Password').fill(testPassword());
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL(/\/explore/);
}