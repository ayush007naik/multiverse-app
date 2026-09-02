import React, { useState } from 'react';

const RazorpayCheckout = ({ amount, orderData, onSuccess, onError }) => {
  const [loading, setLoading] = useState(false);

  const loadScript = (src) => {
    return new Promise((resolve) => {
      const script = document.createElement('script');
      script.src = src;
      script.onload = () => resolve(true);
      script.onerror = () => resolve(false);
      document.body.appendChild(script);
    });
  };

  const handlePayment = async () => {
    setLoading(true);

    // Normally you'd call your Firebase Function here to create an order
    // But for this demo/integration, we'll assume the environment is set up
    // to call the 'createRazorpayOrder' cloud function.

    try {
      // 1. In a real app with Firebase initialized:
      // const createOrder = httpsCallable(functions, 'createRazorpayOrder');
      // const response = await createOrder({ amount: amount * 100, receipt: orderData.id });
      // const { order_id } = response.data;

      // FOR NOW, we'll simulate the logic or expect the user to have Firebase SDK ready
      // Since I don't have the full Firebase config, I'll provide the pattern.

      console.log("Initiating payment for amount:", amount);

      // We'll use a placeholder logic to demonstrate the Razorpay UI flow
      // The user will need to integrate this with their specific Firebase/Backend call.

      const options = {
        key: import.meta.env.VITE_RAZORPAY_KEY_ID,
        amount: amount * 100, // Amount in paise
        currency: "INR",
        name: "Multiverse City",
        description: "Order Payment",
        image: "/favicon.png",
        order_id: "", // This should come from your backend/cloud function
        handler: function (response) {
          // Send these to verifyRazorpayPayment cloud function
          onSuccess({
            razorpay_payment_id: response.razorpay_payment_id,
            razorpay_order_id: response.razorpay_order_id,
            razorpay_signature: response.razorpay_signature
          });
        },
        prefill: {
          name: orderData?.customerName || "",
          email: orderData?.customerEmail || "",
          contact: orderData?.customerPhone || ""
        },
        notes: {
          address: "Multiverse City Corporate Office"
        },
        theme: {
          color: "#FF3B30"
        }
      };

      const rzp1 = new window.Razorpay(options);
      rzp1.on('payment.failed', function (response) {
        onError(response.error);
      });
      rzp1.open();

    } catch (error) {
      console.error("Checkout Error:", error);
      onError(error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <button
      onClick={handlePayment}
      disabled={loading}
      className="btn-primary w-full py-4 rounded-2xl font-bold text-lg flex items-center justify-center gap-2"
    >
      {loading ? (
        <span className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></span>
      ) : (
        <>Pay ₹{amount}</>
      )}
    </button>
  );
};

export default RazorpayCheckout;
