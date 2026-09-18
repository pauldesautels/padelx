import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '..');
const read = (relative) => readFile(path.join(root, relative), 'utf8');

const policies = {
  termsEn: 'web/terms/index.html',
  termsEs: 'web/es-MX/terms/index.html',
  privacyEn: 'web/privacy/index.html',
  privacyEs: 'web/es-MX/privacy/index.html',
  guidelinesEn: 'web/community-guidelines/index.html',
  guidelinesEs: 'web/es-MX/community-guidelines/index.html',
};

test('all authoritative policies use exact v2 identities and shared support metadata', async () => {
  const pages = Object.fromEntries(await Promise.all(
    Object.entries(policies).map(async ([key, file]) => [key, await read(file)]),
  ));
  for (const [key, html] of Object.entries(pages)) {
    assert.match(html, /support\.padelx@gmail\.com/, key);
    assert.match(html, /Paul Desautels/, key);
    assert.doesNotMatch(html, /beta-v1/, key);
  }
  for (const key of ['termsEn', 'termsEs']) assert.match(pages[key], /terms-beta-v2/);
  for (const key of ['privacyEn', 'privacyEs']) assert.match(pages[key], /privacy-beta-v2/);
  for (const key of ['guidelinesEn', 'guidelinesEs']) {
    assert.match(pages[key], /community-beta-v2/);
  }
});

test('English and es-MX policies retain the same material product concepts', async () => {
  const terms = [await read(policies.termsEn), await read(policies.termsEs)];
  const privacy = [await read(policies.privacyEn), await read(policies.privacyEs)];
  const guidelines = [await read(policies.guidelinesEn), await read(policies.guidelinesEs)];
  const shared = [
    [/Reliability/i, /Confiabilidad/i],
    [/Attendance/i, /Asistencia/i],
    [/private/i, /privad/i],
    [/support\.padelx@gmail\.com/i, /support\.padelx@gmail\.com/i],
  ];
  for (const pair of [terms, privacy, guidelines]) {
    for (const [enPattern, esPattern] of shared) {
      assert.match(pair[0], enPattern);
      assert.match(pair[1], esPattern);
    }
  }
  for (const pair of [terms, privacy]) {
    assert.match(pair[0], /Quick Match/i);
    assert.match(pair[1], /Quick Match/i);
  }
});

test('v2 policies remove stale claims and avoid nonexistent product promises', async () => {
  const combined = (await Promise.all(Object.values(policies).map(read))).join('\n');
  assert.doesNotMatch(combined, /does not currently provide payments or automatic matchmaking/i);
  assert.doesNotMatch(combined, /no Reliability feature currently exists/i);
  assert.doesNotMatch(combined, /actualmente no existe una función de Confiabilidad/i);
  assert.doesNotMatch(combined, /personas mayores de 18 años/i);
  assert.doesNotMatch(combined, /\b(?:5|10|20|35|50)\s*(?:points?|puntos?)\b/i);
  assert.doesNotMatch(combined, /Match Quality|GPS attendance|registro GPS|background tracking|rastreo en segundo plano continuo/i);
  assert.match(combined, /does not currently process payments/);
  assert.match(combined, /no procesa pagos actualmente/);
});

test('policy drafts state Attendance fairness and concern boundaries', async () => {
  const en = `${await read(policies.termsEn)}\n${await read(policies.guidelinesEn)}`;
  const es = `${await read(policies.termsEs)}\n${await read(policies.guidelinesEs)}`;
  assert.match(en, /single negative claim is not automatically conclusive/i);
  assert.match(en, /good-faith disagreement/i);
  assert.match(en, /does not guarantee a correction or response time/i);
  assert.match(es, /sola afirmación negativa no es concluyente automáticamente/i);
  assert.match(es, /desacuerdo de buena fe/i);
  assert.match(es, /no garantiza una corrección ni un plazo de respuesta/i);
});

test('privacy drafts distinguish exact private location and staged deletion', async () => {
  const en = await read(policies.privacyEn);
  const es = await read(policies.privacyEs);
  assert.match(en, /Exact custom private venue information[^.]+restricted to authorized participants/i);
  assert.match(es, /información exacta de una sede privada personalizada[^.]+restringida a participantes autorizados/i);
  assert.match(en, /Deletion begins[^.]+staged/i);
  assert.match(es, /eliminación comienza[^.]+por etapas/i);
  assert.match(en, /does not claim to track location continuously or in the background/i);
  assert.match(es, /no afirma rastrear la ubicación de manera continua ni en segundo plano/i);
});
