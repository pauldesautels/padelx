export const ATTENDANCE_POLICY_VERSION = 'attendance-v2-beta-1';
export const EXPECTED_MATCH_DURATION_MINUTES = 120;
export const ATTENDANCE_SUBMISSION_WINDOW_HOURS = 72;
export const MAX_MATCH_PARTICIPANTS = 4;

export const ATTENDANCE_CLAIMS = Object.freeze({
  attended: 'attended',
  absent: 'absent',
});

export const ATTENDANCE_STATES = Object.freeze({
  attended: 'attended',
  noShow: 'no_show',
  disputed: 'disputed',
  insufficient: 'insufficient_evidence',
  matchNotPlayed: 'match_not_played',
});

export function attendanceWindow(scheduledAt) {
  const opensAt = new Date(scheduledAt.getTime() + EXPECTED_MATCH_DURATION_MINUTES * 60_000);
  return { opensAt,
    closesAt: new Date(opensAt.getTime() + ATTENDANCE_SUBMISSION_WINDOW_HOURS * 3_600_000) };
}

// Conservative beta policy. Peer claims are independent of the subject's own
// attestation. Conflicts prefer uncertainty over an unjustified outcome.
export function adjudicateAttendance({ roster, submissions, final = false }) {
  const happened = submissions.filter((item) => item.matchHappened === true).length;
  const notPlayed = submissions.filter((item) => item.matchHappened === false).length;
  if (!final && submissions.length < roster.length) return null;
  if (notPlayed >= 2 && happened === 0) {
    return { matchState: ATTENDANCE_STATES.matchNotPlayed,
      subjects: Object.fromEntries(roster.map((uid) => [uid, ATTENDANCE_STATES.matchNotPlayed])) };
  }
  if (happened < 2 || notPlayed > 0) {
    const state = happened > 0 && notPlayed > 0
      ? ATTENDANCE_STATES.disputed : ATTENDANCE_STATES.insufficient;
    return { matchState: state, subjects: Object.fromEntries(roster.map((uid) => [uid, state])) };
  }
  const subjects = {};
  for (const subjectUid of roster) {
    const relevant = submissions.filter((item) => item.matchHappened === true);
    const peers = relevant.filter((item) => item.observerUid !== subjectUid);
    const positive = peers.filter((item) => item.attendedUids.includes(subjectUid)).length;
    const negative = peers.length - positive;
    const self = relevant.find((item) => item.observerUid === subjectUid);
    const selfPositive = self?.attendedUids.includes(subjectUid) === true;
    if (positive >= 2 || (positive >= 1 && selfPositive && negative === 0)) {
      subjects[subjectUid] = negative > 0 ? ATTENDANCE_STATES.disputed : ATTENDANCE_STATES.attended;
    } else if (negative >= 2) {
      subjects[subjectUid] = positive > 0
        ? ATTENDANCE_STATES.disputed : ATTENDANCE_STATES.noShow;
    } else {
      subjects[subjectUid] = ATTENDANCE_STATES.insufficient;
    }
  }
  return { matchState: 'played', subjects };
}
