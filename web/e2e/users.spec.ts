import { Locator, Page, expect, test } from '@playwright/test';
import { logIn } from './helpers';

const GROUP_COLUMN: number = 3;

// opens the users page and waits until the first page of users is on screen,
// so nothing is typed before the page is ready, just like a person would
async function openUsersPage(page: Page): Promise<void> {
  await logIn(page);
  await page.getByRole('link', { name: 'Users' }).click();
  await expect(page).toHaveURL(/\/admin\/users/);
  await expect(page.locator('table tbody tr .badge').first()).toBeVisible();
}

test('typing in the search filters the grid without pressing anything', async ({ page }: { page: Page }): Promise<void> => {
  await openUsersPage(page);

  const searchBox: Locator = page.getByPlaceholder('Search name, email, group or role');
  await searchBox.fill('Botany');
  await expect(searchBox).toHaveValue('Botany');

  const rows: Locator = page.locator('table tbody tr');
  await expect(rows.first().locator('td').nth(GROUP_COLUMN)).toHaveText('Botany Lab');

  const rowCount: number = await rows.count();
  expect(rowCount).toBeGreaterThan(0);

  for (let rowIndex: number = 0; rowIndex < rowCount; rowIndex++) {
    await expect(rows.nth(rowIndex).locator('td').nth(GROUP_COLUMN)).toHaveText('Botany Lab');
  }
});

test('status chips filter by status, and several can be combined', async ({ page }: { page: Page }): Promise<void> => {
  await openUsersPage(page);

  const badges: Locator = page.locator('table tbody .badge');

  // only inactive users
  await page.getByRole('button', { name: 'Inactive', exact: true }).click();
  await expect(badges.first()).toHaveText('Inactive');

  const inactiveCount: number = await badges.count();
  for (let badgeIndex: number = 0; badgeIndex < inactiveCount; badgeIndex++) {
    await expect(badges.nth(badgeIndex)).toHaveText('Inactive');
  }

  // inactive and locked together
  await page.getByRole('button', { name: 'Locked', exact: true }).click();
  await expect(page.locator('table tbody .badge', { hasText: 'Locked' }).first()).toBeVisible();

  const combinedCount: number = await badges.count();
  for (let badgeIndex: number = 0; badgeIndex < combinedCount; badgeIndex++) {
    await expect(badges.nth(badgeIndex)).toHaveText(/^(Inactive|Locked)$/);
  }
});