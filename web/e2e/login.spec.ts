import { Page, expect, test } from '@playwright/test';
import { logIn, testUsername } from './helpers';

test('a wrong password shows an error and stays on the login page', async ({ page }: { page: Page }): Promise<void> => {
  await page.goto('/login');
  await page.getByLabel('Username').fill(testUsername());
  await page.getByLabel('Password').fill('definitely-not-the-password');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByText('Invalid username or password.')).toBeVisible();
  await expect(page).toHaveURL(/\/login/);
});

test('the right password opens the explorer at the root of the tree', async ({ page }: { page: Page }): Promise<void> => {
  await logIn(page);

  await expect(page.locator('.ladder')).toContainText('biota');
  await expect(page.locator('.ranks a').first()).toBeVisible();
});

test('logging out sends you to login, and the explorer stays closed', async ({ page }: { page: Page }): Promise<void> => {
  await logIn(page);

  await page.getByRole('button', { name: 'Log out' }).click();
  await expect(page).toHaveURL(/\/login/);

  await page.goto('/explore');
  await expect(page).toHaveURL(/\/login/);
});