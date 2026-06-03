# CareHub Secure MVP

This is the CareHub senior-care coordination MVP upgraded from a static prototype into a deployable Supabase/PostgreSQL starter app.

## What is included

- Supabase authentication
- PostgreSQL schema with Row Level Security
- Family workspaces
- Parent profiles
- Medication tracker
- Appointment calendar
- Shared family notes
- Encrypted document uploads before files reach Supabase Storage
- Family invitations
- Role-based permissions: owner, admin, caregiver, viewer
- Email/SMS reminder Edge Function scaffold
- Stripe subscription checkout and webhook scaffold

## Setup

1. Create a Supabase project.
2. In Supabase SQL Editor, run `supabase/schema.sql`.
3. Create a private Supabase Storage bucket named `care-documents`.
4. Open `config.js` and replace:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `STRIPE_PRICE_ID`
5. Deploy the app to Netlify, Vercel, Cloudflare Pages, or any static host.
6. Deploy Supabase Edge Functions:
   ```bash
   supabase functions deploy create-checkout-session
   supabase functions deploy stripe-webhook
   supabase functions deploy send-reminder
   ```
7. Add Supabase secrets:
   ```bash
   supabase secrets set STRIPE_SECRET_KEY=sk_live_or_test_key
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   ```
8. Create a Stripe subscription product/price and copy the price id into `config.js`.
9. Add a Stripe webhook endpoint pointing to the deployed `stripe-webhook` function.
10. Schedule the `send-reminder` function using Supabase cron or an external scheduler.

## Important security notes

This is a strong MVP foundation, not a finished HIPAA-compliant healthcare system. Before storing real regulated medical data, get legal/security review, add audit logging, hardened key management, formal backup/recovery policies, and business associate agreements with vendors where needed.

The document vault encrypts files in the browser using AES-GCM before upload. For production, replace the browser-local family key with audited key sharing, recovery, and rotation.
