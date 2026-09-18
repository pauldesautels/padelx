import { copyFile, mkdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const legalPageRoutes = Object.freeze([
  Object.freeze({ route: 'privacy', lang: 'en', marker: 'privacy-beta-v2' }),
  Object.freeze({ route: 'terms', lang: 'en', marker: 'terms-beta-v2' }),
  Object.freeze({
    route: 'community-guidelines',
    lang: 'en',
    marker: 'community-beta-v2',
  }),
  Object.freeze({
    route: 'account-deletion',
    lang: 'en',
    marker: 'Delete your PadelX account',
  }),
  Object.freeze({
    route: 'es-MX/privacy',
    lang: 'es-MX',
    marker: 'privacy-beta-v2',
  }),
  Object.freeze({
    route: 'es-MX/terms',
    lang: 'es-MX',
    marker: 'terms-beta-v2',
  }),
  Object.freeze({
    route: 'es-MX/community-guidelines',
    lang: 'es-MX',
    marker: 'community-beta-v2',
  }),
  Object.freeze({
    route: 'es-MX/account-deletion',
    lang: 'es-MX',
    marker: 'Elimina tu cuenta de PadelX',
  }),
]);

export async function prepareHosting({
  sourceRoot = 'web',
  destinationRoot = 'build/web',
} = {}) {
  const flutterIndex = await readFile(path.join(destinationRoot, 'index.html'), 'utf8');
  if (!flutterIndex.includes('flutter_bootstrap.js')) {
    throw new Error(
      `Expected a Flutter web build at ${destinationRoot}. Run flutter build web first.`,
    );
  }

  await copyFile(
    path.join(sourceRoot, 'legal.css'),
    path.join(destinationRoot, 'legal.css'),
  );

  for (const page of legalPageRoutes) {
    const source = path.join(sourceRoot, page.route, 'index.html');
    const destination = path.join(destinationRoot, page.route, 'index.html');
    const html = await readFile(source, 'utf8');
    if (!html.includes(`<html lang="${page.lang}">`)) {
      throw new Error(`${source} has an unexpected language declaration.`);
    }
    if (!html.includes(page.marker)) {
      throw new Error(`${source} is missing its expected legal marker.`);
    }
    if (html.includes('flutter_bootstrap.js') || html.includes('main.dart.js')) {
      throw new Error(`${source} unexpectedly contains Flutter bootstrap code.`);
    }
    await mkdir(path.dirname(destination), { recursive: true });
    await copyFile(source, destination);
  }
}

const invokedPath = process.argv[1]
  ? pathToFileURL(path.resolve(process.argv[1])).href
  : '';
if (import.meta.url === invokedPath) {
  await prepareHosting();
  console.log('Prepared eight static legal routes in build/web.');
}
