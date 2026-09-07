import { after, before, beforeEach, describe, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import { deleteObject, getBytes, ref, uploadBytes } from 'firebase/storage';

const projectId = 'demo-padelx-phase8';
const bucket = `${projectId}.appspot.com`;
let environment;

const jpeg = (size = 32) => new Uint8Array(size).fill(0xff);
const storage = (uid) => environment.authenticatedContext(uid, {
  email: `${uid}@example.com`, email_verified: true,
}).storage(bucket);

async function seedActive(uid) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `publicProfiles/${uid}`), { uid });
  });
}

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: { host: '127.0.0.1', port: 8080 },
    storage: {
      rules: await readFile('storage.rules', 'utf8'),
      host: '127.0.0.1', port: 9199,
    },
  });
});
beforeEach(async () => {
  await environment.clearFirestore();
  await environment.clearStorage();
  await seedActive('alice');
  await seedActive('bob');
});
after(async () => environment.cleanup());

describe('profile avatar storage', () => {
  test('owner upload, replace, read, and remove are allowed', async () => {
    const path = 'profileAvatars/alice/avatar.jpg';
    const metadata = { contentType: 'image/jpeg' };
    await assertSucceeds(uploadBytes(ref(storage('alice'), path), jpeg(), metadata));
    await assertSucceeds(uploadBytes(ref(storage('alice'), path), jpeg(64), metadata));
    await assertSucceeds(getBytes(ref(storage('bob'), path)));
    await assertSucceeds(deleteObject(ref(storage('alice'), path)));
  });

  test('unauthenticated, cross-user, invalid path and nested writes are denied', async () => {
    const metadata = { contentType: 'image/jpeg' };
    const path = 'profileAvatars/alice/avatar.jpg';
    await assertFails(uploadBytes(ref(environment.unauthenticatedContext().storage(bucket), path), jpeg(), metadata));
    await assertFails(uploadBytes(ref(storage('bob'), path), jpeg(), metadata));
    await assertFails(uploadBytes(ref(storage('alice'), 'other/alice.jpg'), jpeg(), metadata));
    await assertFails(uploadBytes(ref(storage('alice'), 'profileAvatars/alice/nested/avatar.jpg'), jpeg(), metadata));
  });

  test('oversized and non-image uploads are denied', async () => {
    const path = 'profileAvatars/alice/avatar.jpg';
    await assertFails(uploadBytes(ref(storage('alice'), path), jpeg(5 * 1024 * 1024 + 1), { contentType: 'image/jpeg' }));
    await assertFails(uploadBytes(ref(storage('alice'), path), jpeg(), { contentType: 'text/html' }));
  });

  test('cross-user delete and deleting-account access are denied', async () => {
    const path = 'profileAvatars/alice/avatar.jpg';
    await assertSucceeds(uploadBytes(ref(storage('alice'), path), jpeg(), { contentType: 'image/jpeg' }));
    await assertFails(deleteObject(ref(storage('bob'), path)));
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'accountDeletionBarriers/alice'), { state: 'deleting' });
    });
    await assertFails(getBytes(ref(storage('bob'), path)));
    await assertFails(uploadBytes(ref(storage('alice'), 'profileAvatars/alice/avatar.jpg'), jpeg(), { contentType: 'image/jpeg' }));
  });
});
