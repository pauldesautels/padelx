import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import {
  classifyExistingUser,
  validateEnrollmentEmail,
  validateEnrollmentTarget,
} from './beta_enrollment_safety.mjs';

function argument(name) {
  const prefix = `--${name}=`;
  return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
}

const apply = process.argv.includes('--apply');
const projectId = argument('project');
const confirmedProjectId = argument('confirm-project');
const email = validateEnrollmentEmail(argument('email'));
validateEnrollmentTarget(projectId, confirmedProjectId);

const app = initializeApp({ credential: applicationDefault(), projectId });
const auth = getAuth(app);
let existingUser;
try {
  existingUser = await auth.getUserByEmail(email);
} catch (error) {
  if (error?.code !== 'auth/user-not-found') throw error;
}

const status = classifyExistingUser(existingUser, email);
console.log(`${apply ? 'APPLY' : 'DRY RUN'} project=${projectId}`);
console.log(`email=${email} status=${status}`);

if (status === 'conflict') {
  throw new Error('Existing Auth record does not match the requested email.');
}
if (status === 'already-enrolled') {
  console.log('No changes needed. The tester is already enrolled.');
} else if (!apply) {
  console.log('No changes performed. Re-run with --apply after reviewing the target.');
} else {
  const user = await auth.createUser({
    email,
    emailVerified: false,
    disabled: false,
  });
  console.log(`Created passwordless beta Auth user uid=${user.uid}.`);
  console.log('Tell the tester to use Forgot password? in PadelX to set a password.');
}
