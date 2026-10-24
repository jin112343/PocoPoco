# Feedback notification deployment

The dependency update uses Firebase Admin 14.5, Functions 7.4 and Nodemailer 10.2.1. The v1 Firestore trigger path is unchanged. Untrusted feedback is HTML-escaped, and transport errors omit credentials and message contents from logs.

Before deploying, configure `GMAIL_APP_PASSWORD` in Secret Manager for the existing Firebase project. The password is read only during invocation; the retired `functions.config()` API is no longer used. Do not commit the secret or put it in frontend configuration. A missing secret fails before creating a mail transport. Failed mail delivery is reported as a failed invocation; feedback remains stored in Firestore.

The production project currently has the Cloud Functions API disabled. This source update does not enable billing, create a new mail service, or send mail. `npm test` uses a mocked mail transport.
