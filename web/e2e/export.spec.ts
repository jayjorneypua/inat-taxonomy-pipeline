import { Download, Page, expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { logIn, viewerPassword, viewerUsername } from './helpers';

// amphibia: small enough to export fast, and the same subtree the e2e viewer is scoped to
const AMPHIBIA_TAXON_ID: number = 20978;
const EXPORT_TIMEOUT_MILLISECONDS: number = 90_000;

test('an administrator exports a taxon and gets the csv file', async ({ page }: { page: Page }): Promise<void> => {
  test.setTimeout(120_000);
  await logIn(page);

  await page.goto(`/explore/${AMPHIBIA_TAXON_ID}`);
  await expect(page.locator('.taxon-header h1')).toBeVisible();

  // the button saves a blob through a link click, which playwright sees as a download
  const downloadPromise: Promise<Download> = page.waitForEvent('download', { timeout: EXPORT_TIMEOUT_MILLISECONDS });
  await page.getByRole('button', { name: 'Export CSV' }).click();
  const download: Download = await downloadPromise;

  expect(download.suggestedFilename()).toMatch(/\.csv$/);

  const filePath: string = await download.path();
  const content: string = readFileSync(filePath, 'utf8');
  const lines: string[] = content.split(/\r?\n/).filter((line: string): boolean => line.length > 0);
  expect(lines.length).toBeGreaterThan(1);

  await expect(page.locator('.export-actions')).toContainText('Downloaded');
  await expect(page.getByRole('button', { name: 'Export CSV' })).toBeEnabled();
});

test('a viewer does not see the export button', async ({ page }: { page: Page }): Promise<void> => {
  await logIn(page, viewerUsername(), viewerPassword());

  await page.goto(`/explore/${AMPHIBIA_TAXON_ID}`);
  await expect(page.locator('.taxon-header h1')).toBeVisible();

  await expect(page.getByRole('button', { name: 'Export CSV' })).toHaveCount(0);
  await expect(page.locator('.export-actions')).toHaveCount(0);
});
