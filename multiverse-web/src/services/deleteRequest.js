// Submits a "Delete Account" request from the website's /delete-account page.
// Uses the same public Firestore REST pattern as ./cms.js. The Firebase web
// API key below is a public client key (not a secret) — write access is gated
// server-side by the Firestore security rules (isValidDeleteRequest), which
// only accept a strict document shape into the delete_requests collection.

const PROJECT_ID = "multiverses-8d207"
const API_KEY = "AIzaSyCCwrgcpuhh5v7IC8dIfSQdNhym3Z9QL00"
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`

export async function submitDeleteRequest({ phone, email, reason }) {
  const fields = {
    status: { stringValue: "pending" },
    source: { stringValue: "website" },
    createdAt: { stringValue: new Date().toISOString() },
  }
  if (phone && phone.trim()) fields.phone = { stringValue: phone.trim() }
  if (email && email.trim()) fields.email = { stringValue: email.trim() }
  if (reason && reason.trim()) fields.reason = { stringValue: reason.trim() }

  const res = await fetch(`${BASE}/delete_requests?key=${API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ fields }),
  })

  if (!res.ok) {
    const body = await res.text().catch(() => "")
    throw new Error(`Failed to submit request (${res.status})${body ? `: ${body.slice(0, 200)}` : ""}`)
  }

  return res.json()
}
