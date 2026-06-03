# Deploy CareHub to a shareable URL

This package is designed for Vercel, Netlify, or Cloudflare Pages. The fastest path is Vercel.

## 1\. Create the backend

1. Create a Supabase project.
2. Open Supabase SQL Editor.
3. Run `supabase/schema.sql`.
4. Create a private Supabase Storage bucket named `care-documents`.
5. In Supabase Project Settings > API, copy:

   * Project URL
   * anon public key

## 2\. Connect the frontend

Open `config.js` and replace:

```js
DEMO\_MODE: false,
SUPABASE\_URL: "https://YOUR-PROJECT.supabase.co",
SUPABASE\_ANON\_KEY: "YOUR\_SUPABASE\_ANON\_KEY",
STRIPE\_PRICE\_ID: "price\_YOUR\_MONTHLY\_PRICE\_ID"
```

Keep secret keys out of this file. Only use the Supabase anon public key here.

## 3\. Deploy to Vercel

Option A: GitHub

1. Upload this folder to a GitHub repository.
2. Go to Vercel > Add New Project.
3. Import the GitHub repository.
4. Framework preset: Other.
5. Build command: leave blank.
6. Output directory: leave blank or `.`.
7. Deploy.

Vercel will generate a public URL like:

```txt
https://your-project-name.vercel.app
```

Option B: Vercel CLI

```bash
npm install -g vercel
cd carehub-deploy-ready
vercel
vercel --prod
```

## 4\. Add the URL to Supabase Auth

In Supabase Dashboard:

1. Authentication > URL Configuration.
2. Set Site URL to your Vercel URL.
3. Add your Vercel URL to Redirect URLs.

Example:

```txt
https://your-project-name.vercel.app
```

## 5\. Stripe subscriptions

1. Create a Stripe product and recurring monthly price.
2. Copy the Stripe price id into `config.js`.
3. Deploy the Supabase Edge Function `create-checkout-session`.
4. Add Stripe secret keys as Supabase secrets.
5. Add a Stripe webhook pointing to your deployed `stripe-webhook` function.

## 6\. Email/SMS reminders

The app includes the reminder data model and Edge Function scaffold. To turn reminders on:

1. Add a transactional email provider key, such as SendGrid, Resend, or Postmark.
2. Add an SMS provider key, such as Twilio.
3. Add those credentials as Supabase secrets.
4. Schedule the `send-reminder` function using Supabase cron or an external scheduler.

## 7\. Production warning

This is a deployable MVP, not a HIPAA-compliant healthcare system. Before storing real medical records or protected health information, get legal/security review, vendor agreements, audit logs, key recovery, backups, monitoring, and incident response in place.

