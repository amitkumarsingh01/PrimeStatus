from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv
import os
import razorpay
import uvicorn

load_dotenv()

app = FastAPI()

# Initialize Razorpay client
razorpay_client = razorpay.Client(
    auth=(os.getenv("RAZORPAY_KEY_ID"), os.getenv("RAZORPAY_KEY_SECRET"))
)

class PaymentRequest(BaseModel):
    amount: float  # in INR
    name: str
    email: str
    contact: str  # in 10-digit mobile format

@app.post("/create-payment-link/")
def create_payment_link(data: PaymentRequest):
    try:
        # Convert to paise
        amount_paise = int(data.amount * 100)

        payment_link = razorpay_client.payment_link.create({
            "amount": amount_paise,
            "currency": "INR",
            "description": f"Payment for {data.name}",
            "customer": {
                "name": data.name,
                "email": data.email,
                "contact": data.contact,
            },
            "notify": {
                "sms": True,
                "email": True
            },
            "reminder_enable": True,
            "callback_url": "https://your-site.com/payment-callback",
            "callback_method": "get"
        })

        return {
            "payment_link": payment_link["short_url"],
            "status": payment_link["status"]
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8006)