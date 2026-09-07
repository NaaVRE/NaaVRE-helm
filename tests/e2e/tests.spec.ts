import { test, expect } from '@playwright/test';
test.use({ ignoreHTTPSErrors: true });

test('has title', async ({ page }) => {
  await page.goto('https://naavre-dev.minikube.test/vreapp');

  // Expect a title "to contain" a substring.
  await expect(page).toHaveTitle(/NaaVRE PaaS/);
});

test('can login', async ({ page }) => {
  await page.goto('https://naavre-dev.minikube.test/vreapp');
  await page.getByRole('link', { name: 'Login' }).click();
  await page.getByRole('textbox', { name: 'Username or email' }).click();
  await page.getByRole('textbox', { name: 'Username or email' }).fill('user');
  await page.getByRole('textbox', { name: 'Username or email' }).press('Tab');
  await page.getByRole('textbox', { name: 'Password' }).fill('user');
  await page.getByRole('button', { name: 'Sign In' }).click();

  // Assert we've left the login page the Login link is gone and there is a text 'Logged in as user user'
  await expect(page.getByRole('link', { name: 'Login' })).toHaveCount(0);
  // print the page content for debugging
  await expect(page.getByText('Logged in as user user')).toHaveCount(1);

  // Save screenshot after login
  await page.screenshot({ path: 'login.png' });

});


test('start lab instance', async ({ page }) => {
  await page.goto('https://naavre-dev.minikube.test/vreapp');
  await page.getByRole('link', { name: 'Login' }).click();
  await page.getByRole('textbox', { name: 'Username or email' }).click();
  await page.getByRole('textbox', { name: 'Username or email' }).fill('user');
  await page.getByRole('textbox', { name: 'Username or email' }).press('Tab');
  await page.getByRole('textbox', { name: 'Password' }).fill('user');
  await page.getByRole('button', { name: 'Sign In' }).click();

});