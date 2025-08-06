import express from 'express';
import Razorpay from 'razorpay';
import bodyParser from 'body-parser';
import dotenv from 'dotenv';

dotenv.config();
const app = express();
app.use(bodyParser.json());

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

// API 1: Generate Payment URL
app.post('/create-payment', async (req, res) => {
  try {
    const { amount, userId, orderId } = req.body;

    const paymentLink = await razorpay.paymentLink.create({
      amount: amount * 100, // INR to paise
      currency: "INR",
      description: `Payment for Order ${orderId}`,
      customer: {
        name: `User ${userId}`,
        email: `user${userId}@gmail.com`,
        contact: "7827963159",
      },
      notify: { sms: true, email: true },
      reminder_enable: true,
      callback_url: "https://example.com/payment-callback",
      callback_method: "get"
    });

    res.json({ payment_url: paymentLink.short_url, payment_id: paymentLink.id });
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: "Failed to create payment link" });
  }
});

// API 2: Check Payment Status
app.get('/payment-status/:id', async (req, res) => {
  try {
    const paymentId = req.params.id;
    const payment = await razorpay.paymentLink.fetch(paymentId);
    res.json({ status: payment.status }); // "paid", "created", "cancelled"
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: "Failed to fetch payment status" });
  }
});

app.listen(3000, () => console.log("Server running at http://localhost:3000"));
