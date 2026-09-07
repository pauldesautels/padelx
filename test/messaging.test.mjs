import test from 'node:test';
import assert from 'node:assert/strict';
import {
  directConversationId, matchConversationId, matchMemberUids, matchSendState,
  normalizeMessageText, validRequestId, MATCH_CHAT_GRACE_MS,
} from '../functions/messaging_policy.js';

test('direct conversation identity is deterministic for an unordered pair', () => {
  assert.equal(directConversationId('alice', 'bob'), directConversationId('bob', 'alice'));
  assert.match(directConversationId('alice', 'bob'), /^direct_[a-f0-9]{64}$/);
  assert.throws(() => directConversationId('alice', 'alice'));
});

test('match conversation identity is deterministic and path safe', () => {
  assert.equal(matchConversationId('match-1'), matchConversationId('match-1'));
  assert.notEqual(matchConversationId('match-1'), matchConversationId('match-2'));
  assert.throws(() => matchConversationId('bad/id'));
});

test('message validation trims text and enforces conservative limits', () => {
  assert.equal(normalizeMessageText('  hello  '), 'hello');
  assert.throws(() => normalizeMessageText('   '));
  assert.throws(() => normalizeMessageText('x'.repeat(1001)));
  assert.equal(normalizeMessageText('x'.repeat(1000)).length, 1000);
  assert.equal(validRequestId('request_123456789'), true);
  assert.equal(validRequestId('short'), false);
});

test('canonical match members support 2, 3, and 4 players without pending requests', () => {
  for (const playerCount of [1, 2, 3]) {
    const data = { creatorUid: 'organizer', players: Array.from({ length: playerCount }, (_, i) => ({ uid: `p${i}` })) };
    assert.equal(matchMemberUids(data).length, playerCount + 1);
    assert.equal(matchSendState(data, 'organizer').canSend, true);
    assert.equal(matchSendState(data, 'pending').canRead, false);
  }
});

test('match chat is read-only after cancellation or 24-hour completion grace', () => {
  const now = new Date('2026-01-02T12:00:00Z');
  const base = { creatorUid: 'organizer', players: [{ uid: 'player' }] };
  assert.deepEqual(matchSendState({ ...base, status: 'cancelled' }, 'player', now),
    { canRead: true, canSend: false, reason: 'cancelled' });
  assert.equal(matchSendState({ ...base, scheduledAt: new Date(now.getTime() - MATCH_CHAT_GRACE_MS + 1) }, 'player', now).canSend, true);
  assert.equal(matchSendState({ ...base, scheduledAt: new Date(now.getTime() - MATCH_CHAT_GRACE_MS - 1) }, 'player', now).canSend, false);
  assert.equal(matchSendState(base, 'unrelated', now).canRead, false);
});

test('blocking is intentionally not part of match-chat policy', () => {
  const state = matchSendState({ creatorUid: 'a', players: [{ uid: 'b' }] }, 'b');
  assert.equal(state.canSend, true, 'shared-match logistics remain available despite social blocks');
});
