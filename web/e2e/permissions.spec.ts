import { Page, expect, test } from '@playwright/test';
import { logIn, viewerPassword, viewerUsername } from './helpers';

test('an administrator sees the Users link', async ({ page }: { page: Page }): Promise<void> => {
  await logIn(page);

  await expect(page.getByRole('link', { name: 'Users' })).toBeVisible();
});

test('a viewer does not see the Users link and cannot open the page directly', async ({ page }: { page: Page }): Promise<void> => {
  await logIn(page, viewerUsername(), viewerPassword());

  await expect(page.locator('.ranks a').first()).toBeVisible();
  await expect(page.getByRole('link', { name: 'Users' })).toHaveCount(0);

  await page.goto('/admin/users');
  await expect(page).toHaveURL(/\/explore/);
});

test('a viewer only sees their own part of the tree', async ({ page }: { page: Page }): Promise<void> => {
  await logIn(page, viewerUsername(), viewerPassword());

  await expect(page.locator('.ranks a')).toHaveCount(1);
  await expect(page.locator('.ranks a').first()).toContainText('Animals');
});