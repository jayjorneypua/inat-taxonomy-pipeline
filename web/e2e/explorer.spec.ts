import { Locator, Page, expect, test } from '@playwright/test';
import { logIn } from './helpers';

test('drilling down updates the address, the breadcrumb and the photos', async ({ page }: { page: Page }): Promise<void> => {
  await logIn(page);

  await page.locator('.ranks a', { hasText: 'Animals' }).click();

  await expect(page).toHaveURL(/\/explore\/1$/);
  await expect(page.locator('.ladder')).toContainText('Animals');
  await expect(page.locator('.plate').first()).toBeVisible();
});

test('load more adds the next page of photos', async ({ page }: { page: Page }): Promise<void> => {
  await logIn(page);

  const photoCards: Locator = page.locator('.plate');
  await expect(photoCards).toHaveCount(24);

  await page.getByRole('button', { name: 'Load more' }).click();
  await expect(photoCards).toHaveCount(48);
});