import * as functionsV1 from 'firebase-functions/v1';
import { acceptDeletedAuthUser } from './account_deletion_dispatch.js';

// Keep the first-generation dependency isolated. Admin bulk deleteUsers does
// not deliver these events; use individual deletion or preparation inventory.
export function deletedAuthFallback(backendFirestore) {
  return functionsV1.runWith({ failurePolicy: true }).auth.user().onDelete(async user => {
    const { firestore } = backendFirestore();
    await acceptDeletedAuthUser(firestore, user.uid);
  });
}
