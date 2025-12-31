# Stripe Payment Integration Setup

## Overview
PolyFace now uses Stripe for payment processing instead of Apple's StoreKit. This allows for more flexible payment options and better integration with the backend.

## Setup Steps

### 1. Install Stripe iOS SDK

Add the Stripe iOS SDK to your Xcode project:

1. Open Xcode project
2. Go to **File → Add Package Dependencies**
3. Enter: `https://github.com/stripe/stripe-ios`
4. Select version: **23.0.0** or later
5. Add to target: **PolyFace**

### 2. Configure Firebase Cloud Functions

The Stripe secret key must be stored securely in Firebase Functions configuration, NOT in the app code.

#### Set Stripe Secret Key:
```bash
cd "PolyCal"
firebase functions:config:set stripe.secret_key="YOUR_STRIPE_SECRET_KEY"
```

Replace `YOUR_STRIPE_SECRET_KEY` with your actual Stripe secret key (starts with `sk_live_` or `sk_test_`).

#### Set Webhook Secret (for production):
```bash
firebase functions:config:set stripe.webhook_secret="whsec_YOUR_WEBHOOK_SECRET"
```

Get the webhook secret from Stripe Dashboard → Developers → Webhooks → Add endpoint

#### Install Dependencies:
```bash
cd functions
npm install
```

#### Deploy Functions:
```bash
cd ..
firebase deploy --only functions
```

### 3. Initialize Stripe in iOS App

Add the following to `PolyFaceApp.swift` in the `init()` method:

```swift
import StripePaymentSheet

init() {
    StripeAPI.defaultPublishableKey = StripeConfig.publishableKey
}
```

### 4. Test Configuration

To verify everything is set up correctly:

```bash
# View current config
firebase functions:config:get

# Test functions locally
cd functions
npm run serve
```

## Payment Flow

1. **User selects package** → PurchaseLessonsView
2. **App calls `createPaymentIntent`** → Firebase Function creates Stripe PaymentIntent
3. **Stripe Payment Sheet opens** → User enters payment details
4. **Payment succeeds** → App calls `confirmPaymentAndCreatePackage`
5. **Firebase Function verifies payment** → Creates lesson package in Firestore
6. **User sees confirmation** → Package appears in their profile

## Security Notes

- ✅ Publishable key (`pk_live_...`) is safe to include in app code
- ❌ Secret key (`sk_live_...`) must NEVER be in app code
- ✅ Secret key is stored in Firebase Functions config
- ✅ All payment processing happens server-side
- ✅ Payment verification happens before creating packages

## Package Pricing

| Package | Lessons | Price |
|---------|---------|-------|
| Single | 1 | $50 |
| Five Pack | 5 | $225 |
| Ten Pack | 10 | $400 |

## Stripe Dashboard

- Test mode: https://dashboard.stripe.com/test
- Live mode: https://dashboard.stripe.com/live

Monitor payments, create test payments, and manage webhooks from the dashboard.

## Troubleshooting

### Functions deployment fails
- Check Node version: `node --version` (should be 22)
- Rebuild: `cd functions && npm run build`
- Check for TypeScript errors

### Payment fails
- Check Functions logs: `firebase functions:log`
- Verify Stripe keys are configured: `firebase functions:config:get`
- Check Stripe Dashboard for payment status

### Package not created
- Verify payment succeeded in Stripe Dashboard
- Check Firestore security rules allow package creation
- Review Functions logs for errors
