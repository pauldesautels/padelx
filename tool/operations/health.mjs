import { Timestamp } from 'firebase-admin/firestore';
import { boundedCount, OPERATIONAL_QUERY_LIMIT, safeFailure } from './policy.mjs';

async function count(query) {
  return boundedCount(await query.limit(OPERATIONAL_QUERY_LIMIT).get());
}

async function inspect(query, predicate) {
  const snapshot = await query.limit(OPERATIONAL_QUERY_LIMIT).get();
  return { count: snapshot.docs.filter((document) => predicate(document.data())).length,
    inspected: snapshot.size, truncated: snapshot.size >= OPERATIONAL_QUERY_LIMIT };
}

async function section(name, operation) {
  try {
    const result = await operation();
    const status = name === 'deletion' && result.blockedJobs.count > 0 ? 'attention' : 'ok';
    return [name, { status, ...result }];
  }
  catch (error) { return [name, safeFailure(error)]; }
}

export async function collectOperationalHealth(db, now = new Date(), only = 'summary') {
  const before = (minutes) => Timestamp.fromDate(new Date(now.getTime() - minutes * 60_000));
  const definitions = {
    matchmaking: async () => ({
      activeRequests: await count(db.collection('matchmakingRequests').where('status', '==', 'active')),
      overdueRequests: await inspect(db.collection('matchmakingRequests').where('status', '==', 'active'),
        (data) => data.expiresAt?.toDate?.() <= now),
      confirmingProposals: await count(db.collection('matchProposals').where('status', '==', 'confirming')),
      overdueConfirmingProposals: await inspect(db.collection('matchProposals')
        .where('status', '==', 'confirming'), (data) => data.expiresAt?.toDate?.() <= now),
      venueNeededProposals: await count(db.collection('matchProposals').where('status', '==', 'venue_needed')),
      promotedWithoutMatchId: await inspect(db.collection('matchProposals').where('status', '==', 'promoted'),
        (data) => typeof data.matchId !== 'string' || data.matchId.length === 0),
      activeOwnerLocks: await count(db.collection('matchmakingActiveOwners')),
      activeAutoFill: await inspect(db.collection('matchmakingRequests').where('status', '==', 'active'),
        (data) => data.mode === 'autofill'),
    }),
    attendance: async () => ({
      overdueJobs: await count(db.collection('attendanceResolutionJobs').where('status', '==', 'pending')
        .where('closesAt', '<=', Timestamp.fromDate(now))),
      pendingJobs: await count(db.collection('attendanceResolutionJobs').where('status', '==', 'pending')),
    }),
    reliability: async () => {
      const snapshot = await db.collection('reliabilityProfiles').limit(OPERATIONAL_QUERY_LIMIT).get();
      let invalid = 0; let stalePolicy = 0; let newPlayers = 0; let established = 0;
      for (const document of snapshot.docs) {
        const data = document.data();
        const validEstablished = data.status === 'established'
          && Number.isFinite(data.percent) && data.percent >= 0 && data.percent <= 100
          && Number.isInteger(data.sampleSize) && data.sampleSize >= 5;
        const validNew = data.status === 'new_player' && data.percent == null
          && Number.isInteger(data.sampleSize) && data.sampleSize >= 0 && data.sampleSize < 5;
        if (!validEstablished && !validNew) invalid += 1;
        if (data.policyVersion !== 'objective-reliability-v2-attendance') stalePolicy += 1;
        if (data.status === 'new_player') newPlayers += 1;
        if (data.status === 'established') established += 1;
      }
      return { inspected: snapshot.size, truncated: snapshot.size >= OPERATIONAL_QUERY_LIMIT,
        invalid, stalePolicy, newPlayers, established };
    },
    deletion: async () => ({
      retryingJobs: await count(db.collection('accountDeletionJobs').where('status', '==', 'retry_wait')),
      blockedJobs: await count(db.collection('accountDeletionJobs').where('status', '==', 'blocked')),
      pendingJobs: await count(db.collection('accountDeletionJobs').where('status', '==', 'pending')),
      completedJobs: await count(db.collection('accountDeletionJobs').where('status', '==', 'complete')),
    }),
    push: async () => ({
      processingOlderThan15Minutes: await inspect(db.collection('pushDeliveryReceipts')
        .where('status', '==', 'processing'), (data) => data.updatedAt?.toDate?.() <= before(15).toDate()),
      completedReceipts: await count(db.collection('pushDeliveryReceipts').where('status', '==', 'complete')),
      completedWithFailures: await inspect(db.collection('pushDeliveryReceipts')
        .where('status', '==', 'complete'), (data) => Number(data.failedCount ?? 0) > 0),
      completedWithoutSend: await inspect(db.collection('pushDeliveryReceipts')
        .where('status', '==', 'complete'), (data) => Number(data.sentCount ?? 0) === 0),
    }),
    reports: async () => ({
      open: await count(db.collection('reports').where('status', '==', 'open')),
      reviewing: await count(db.collection('reports').where('status', '==', 'reviewing')),
    }),
  };
  const names = only === 'summary' ? Object.keys(definitions) : [only];
  return Object.fromEntries(await Promise.all(names.map((name) => section(name, definitions[name]))));
}
