process.env.GCLOUD_PROJECT = 'demo-security-audit';
const { test, mock, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const nodemailer = require('nodemailer');
const { sendFeedbackNotification } = require('./index');
afterEach(() => { mock.restoreAll(); delete process.env.GMAIL_APP_PASSWORD; });
const event = (extra = {}) => ({ data: () => ({ type: 'bug', platform: 'iOS', message: 'Hello', ...extra }) });

test('registered trigger retains the feedback document path', () => {
  assert.equal(sendFeedbackNotification.__endpoint.eventTrigger.eventFilters.resource, 'projects/demo-security-audit/databases/(default)/documents/feedback/{feedbackId}');
});
test('user content is escaped and mail is constructed only at invocation', async () => {
  process.env.GMAIL_APP_PASSWORD = 'test-only-placeholder';
  let delivered;
  mock.method(nodemailer, 'createTransport', () => ({ sendMail: async (mail) => { delivered = mail; } }));
  await sendFeedbackNotification.run(event({ type: '<img src=x>', platform: '<script>x</script>', message: '<a href="bad">x & y</a>' }), { params: { feedbackId: '<injected>' } });
  assert.ok(delivered.html.includes('&lt;script&gt;x&lt;/script&gt;'));
  assert.ok(delivered.html.includes('&lt;a href=&quot;bad&quot;&gt;x &amp; y&lt;/a&gt;'));
  assert.ok(delivered.html.includes('&lt;injected&gt;'));
  assert.ok(!delivered.html.includes('<img src=x>'));
});
test('missing secret fails before opening a mail transport', async () => {
  let attempts = 0;
  mock.method(nodemailer, 'createTransport', () => { attempts++; throw new Error('unexpected'); });
  await assert.rejects(sendFeedbackNotification.run(event(), { params: { feedbackId: 'test' } }), /not configured/);
  assert.equal(attempts, 0);
});
test('transport errors remain visible without exposing transport credentials', async () => {
  process.env.GMAIL_APP_PASSWORD = 'test-only-placeholder';
  mock.method(nodemailer, 'createTransport', () => ({ sendMail: async () => { throw new Error('sensitive transport details'); } }));
  await assert.rejects(sendFeedbackNotification.run(event(), { params: { feedbackId: 'test' } }), /^Error: Feedback email delivery failed$/);
});
