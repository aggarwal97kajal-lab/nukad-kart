# Baaki kaam (backlog)

When the founder asks "aur kya kya karna hai app mein", read this file and remind him of every open item.

## 1. Customer location follows the phone (asked 13 Nov 2026) — DONE 14 Nov 2026

**Today:** the customer app shows shops and thelas within 500 m of the address the customer picked (saved address = `current`). If they travel, the list stays on the old address until they change it by hand.

**Wanted:**
- When the app opens, use the phone's **current location** automatically, and show only the kiranas and thelas within 500 m of *that* place.
- When ordering from a kirana in the new area, ask the customer to **add a new address for the new location** (or pick a saved one nearby) before placing the order.

**Points to settle when building:**
- Use location **only while the app is open** (no background tracking). That keeps it simple for privacy (DPDP) and battery.
- Show a small banner: "Aap abhi <area> mein ho · Ghar wala address use karein?" so they can switch back.
- **Thela alerts** ("thela near you", call to my street) stay tied to the saved home spot, unless the customer chooses otherwise.
- If location permission is off, fall back to the saved address, as today.

## 2. From the founder pack (13 Nov 2026), see `founder/launch.md`

- Play Store build + closed test (12 testers × 14 days)
- ~~Sunday report for sellers~~ (done 14 Nov; guarantee dropped by founder)
- New pass prices: remove Daily, fix Yearly (it currently costs more than 12 × Monthly), test ₹49/week
- ~~Pass-expiry reminder (1 day before)~~ (done 14 Nov: evening before + last morning)
- ~~Empty-map message~~ (done 14 Nov, with alert button)
- ~~No-show fix: customer confirms "bahar aa raha hoon"~~ (done 14 Nov; chat to the thela also counts)
- Merchant UPI QR on the pass screen (no gateway for now; add one at ~50 sellers)
- Grievance officer name in the app (legal requirement)

## 3. Decided 14 Nov 2026
- Kirana trial stays **7 days**, documents before going live (1-month trial with documents later: dropped).
- "Fewer than 20 calls → next month free" guarantee: dropped.
