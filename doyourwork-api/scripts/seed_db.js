const db = require('../config/database');
const bcrypt = require('bcryptjs');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY || '');

async function seed() {
  try {
    const passwordHash = await bcrypt.hash('password', 10);

    // Create stripe customers if stripe key present
    let stripeId1 = `cus_mock_${Date.now()}`;
    let stripeId2 = `cus_mock_${Date.now() + 1}`;
    if (process.env.STRIPE_SECRET_KEY) {
      const c1 = await stripe.customers.create({ email: 'friend1@example.com' });
      const c2 = await stripe.customers.create({ email: 'friend2@example.com' });
      stripeId1 = c1.id;
      stripeId2 = c2.id;
      console.log('Created Stripe customers', stripeId1, stripeId2);
    }

    // Insert two users
    const [res1] = await db.execute(
      'INSERT INTO Users (username, email, password_hash, stripe_customer_id) VALUES (?, ?, ?, ?)',
      ['friend1', 'friend1@example.com', passwordHash, stripeId1]
    );

    const [res2] = await db.execute(
      'INSERT INTO Users (username, email, password_hash, stripe_customer_id) VALUES (?, ?, ?, ?)',
      ['friend2', 'friend2@example.com', passwordHash, stripeId2]
    );

  // Do not automatically accept friends in seed; keep them separate so dev testers
  // must explicitly add and accept friends during testing.

    console.log('Seed complete: friend1 and friend2 created');
  } catch (err) {
    console.error('Seed DB error:', err.message);
  } finally {
    process.exit(0);
  }
}

seed();
