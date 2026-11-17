# Builds privacy.html, terms.html and 404.html from the texts below (run: python3 website/tool/legal.py).
import html, os
OUT = os.path.join(os.path.dirname(__file__), '..', 'public')
UPDATED = '17 November 2026'

HEAD = '''<!doctype html>
<html lang="en" data-theme="light">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · Nukkad Kart</title>
<meta name="description" content="{desc}">
<link rel="canonical" href="https://nukkadkart.in/{slug}">
<link rel="icon" href="/favicon.ico" sizes="48x48">
<meta name="theme-color" content="#F3F5EF" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#06110B" media="(prefers-color-scheme: dark)">
<script>
  (function(){{ var t; try {{ t = localStorage.getItem('nk-theme'); }} catch(e){{}}
    if(!t) t = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', t); }})();
</script>
<style>
@font-face{{font-family:"Instrument Serif";font-weight:400;font-display:swap;src:url(/assets/fonts/instrument-serif-latin-400-normal.woff2) format("woff2")}}
@font-face{{font-family:Geist;font-weight:400;font-display:swap;src:url(/assets/fonts/geist-latin-400-normal.woff2) format("woff2")}}
@font-face{{font-family:Geist;font-weight:600;font-display:swap;src:url(/assets/fonts/geist-latin-600-normal.woff2) format("woff2")}}
:root{{--bg:#F3F5EF;--ink:#0B1F12;--mute:#4E5E53;--line:#D9DED5;--card:#FFFFFF;--acc:#1E7A08;--yel:#FDC630}}
[data-theme=dark]{{--bg:#06110B;--ink:#EEF3EC;--mute:#A3B2A7;--line:#1D2E23;--card:#0C1A12;--acc:#8BD46E}}
*{{box-sizing:border-box}}
body{{margin:0;background:var(--bg);color:var(--ink);font:400 17px/1.65 Geist,system-ui,sans-serif;-webkit-font-smoothing:antialiased}}
a{{color:var(--acc);text-underline-offset:3px}}
a:focus-visible{{outline:2px solid var(--acc);outline-offset:3px;border-radius:4px}}
.wrap{{max-width:720px;margin:0 auto;padding:0 22px}}
header{{padding:22px 0;border-bottom:1px solid var(--line)}}
header .wrap{{display:flex;align-items:center;justify-content:space-between;gap:16px}}
.brand{{display:flex;align-items:center;gap:10px;color:var(--ink);text-decoration:none;font-weight:600}}
.brand img{{border-radius:10px}}
h1{{font:400 clamp(40px,8vw,64px)/1.05 "Instrument Serif",Georgia,serif;margin:48px 0 8px;letter-spacing:-.01em}}
.upd{{color:var(--mute);font-size:14px;margin:0 0 36px}}
h2{{font-size:19px;font-weight:600;margin:36px 0 8px;scroll-margin-top:24px}}
p,li{{color:var(--mute)}} p b,li b{{color:var(--ink);font-weight:600}}
ul{{padding-left:20px}} li{{margin:6px 0}}
.box{{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:18px 20px;margin:12px 0}}
footer{{margin-top:64px;padding:28px 0 40px;border-top:1px solid var(--line);font-size:14px;color:var(--mute)}}
footer nav{{display:flex;flex-wrap:wrap;gap:18px;margin-top:8px}}
</style>
</head>
<body>
<header><div class="wrap"><a class="brand" href="/"><img src="/assets/img/logo.webp" alt="" width="34" height="34">Nukkad Kart</a><a href="/">Home</a></div></header>
<main class="wrap">
'''
FOOT = '''</main>
<footer><div class="wrap">© Nukkad Kart · <a href="mailto:support@nukkadkart.in">support@nukkadkart.in</a>
<nav aria-label="Legal"><a href="/privacy">Privacy Policy</a><a href="/terms">Terms</a><a href="/privacy#grievance">Grievance Officer</a><a href="/privacy#delete">Delete your data</a></nav></div></footer>
</body></html>
'''

def page(slug, title, desc, body):
    return HEAD.format(title=html.escape(title), desc=html.escape(desc), slug=slug) + body + FOOT

def sections(items):
    out = []
    for sid, h, paras in items:
        out.append(f'<h2 id="{sid}">{h}</h2>' if sid else f'<h2>{h}</h2>')
        for p in paras:
            if isinstance(p, list):
                out.append('<ul>' + ''.join(f'<li>{x}</li>' for x in p) + '</ul>')
            else:
                out.append(f'<p>{p}</p>')
    return '\n'.join(out)

MAIL = '<a href="mailto:support@nukkadkart.in">support@nukkadkart.in</a>'

PRIVACY = [
  ('', 'Who we are', ['Nukkad Kart connects you with kirana stores and moving sellers (thelas) within 500 m of your home. This policy covers this website and the Nukkad Kart apps. It explains what personal data we collect, why, who we share it with and the choices you have, under India’s Digital Personal Data Protection Act, 2023 and the Information Technology Act, 2000.']),
  ('early-access', 'Early access list on this website', [
    'When you join the early access list we collect your <b>name, email address, mobile number, pincode, city and state</b>, and the time you gave consent.',
    'We use them only to tell you when Nukkad Kart opens in your area, and to plan which areas to open first. We send one confirmation email when you join, then nothing until launch in your area.',
    'They are stored on Cloudflare (our servers) and Brevo (the service that sends our emails). They are never shared with shops, sellers or advertisers, and never sold.',
    'We keep them until we have told you about the launch in your area, or until you ask us to delete them, whichever comes first.']),
  ('', 'What the apps collect', [[
    'From your Google account: your name and email address.',
    'Your mobile number, which we confirm with a one-time SMS code.',
    'Your delivery addresses and the map pin you set for each one, to show shops within 500 m and to tell you when a thela is live near you.',
    'Messages you exchange with a thela in chat. They are deleted after 24 hours. Phone numbers cannot be sent in chat.',
    '“Call to my street” requests: the address you called the thela to, and whether the seller reported that nobody was there.',
    'A notification token for your phone, to send order, thela and chat alerts.',
    'Your phone’s location, only while the app is open and only if you allow it, to show shops and thelas near where you are. It is not saved on our server and never read in the background.',
    'Your orders, cart, wishlist, saved stores, ratings and complaints.',
  ], 'Voice search is turned into text by your phone’s speech service; we do not record or keep the audio.']),
  ('', 'Why we use it', ['To create your account, show stores and thelas near your address, send your order to the store and get it delivered, prevent misuse, handle complaints, and meet legal duties. We do not sell your data and do not use it for advertising.']),
  ('', 'Who we share it with', [[
    'The store you order from, and the delivery person it sends, get your name, mobile number, delivery address and order items, only to fulfil that order.',
    'A thela you call to your street or chat with sees only the address text you sent and your messages, never your name or number. A shop’s or seller’s phone number is never shown to customers either.',
    'Service providers who run parts of Nukkad Kart for us: Cloudflare (servers and database), Brevo (emails), Google (sign-in and notifications), MSG91 (SMS codes) and Ola Maps (maps and address search). They may use the data only to provide their service to us.',
    'Government authorities when the law requires it.']]),
  ('', 'Sellers’ and delivery location', ['A thela seller’s live location is shared with nearby customers only while the seller has turned on “Live” in the Partner app. A delivery person’s location is shown to you only while your order is out for delivery.']),
  ('', 'Where and how long we keep it', ['Data is stored on Cloudflare’s and Brevo’s servers, which may be outside India, and sent over encrypted connections. App profiles and addresses are kept until you delete your account. Chat messages are kept for 24 hours. Order and complaint records are kept as long as the law requires, even after you delete your account.']),
  ('delete', 'Your rights, and deleting your data', [[
    '<b>Early access list:</b> reply to any email from us, or write to ' + MAIL + ' from the same email address, and we will delete your details within 7 days.',
    '<b>App account:</b> Account → Account privacy → Request to delete account. Your name, number and addresses are removed from our servers.',
    'You can see and correct your details, withdraw consent at any time, and nominate someone to use these rights for you if you die or cannot act.',
    'You can complain to our Grievance Officer, and if you are not satisfied, to the Data Protection Board of India.']]),
  ('', 'Cookies', ['This website sets no cookies and uses no analytics or advertising trackers. It remembers your light or dark theme choice in your own browser only.']),
  ('', 'Age', ['Nukkad Kart is meant for people aged 18 and above.']),
  ('grievance', 'Grievance Officer', ['Email ' + MAIL + ' with “Grievance” in the subject. We acknowledge within 48 hours and resolve within one month.']),
  ('', 'Changes', ['If we change this policy, we will post the new version here with a new date.']),
]

TERMS = [
  ('', 'What Nukkad Kart is', ['Nukkad Kart lists registered kirana stores and moving sellers (thelas) within 500 m of your address. Orders are between you and the store or seller.']),
  ('', 'Payment', ['You pay the store or seller directly at delivery or pickup, by cash or their UPI. Nukkad Kart does not collect payment and gives no refunds; any refund comes from the store. A ₹20 delivery fee below ₹199 is charged by the store.']),
  ('', 'Orders and cancelling', ['A store has 5 minutes to accept, otherwise the order is cancelled. You can cancel while the order is Placed or Accepted. Cancelling after the store accepted, or not taking an order, counts towards the limit: 3 in 90 days blocks ordering on your account and number.']),
  ('', 'Moving sellers (thelas) and location', ['While a seller has turned on “Live” in the Partner app, customers within 500 m see where the thela is right now on a map. When the seller turns Live off, or moves outside a customer’s 500 m, the location is no longer shown to that customer. Customers must not use a seller’s location for anything other than buying from them.']),
  ('', 'Call to my street and chat', ['You can ask a live thela within 500 m to come to your address, one thela at a time. The seller has 3 minutes to answer. You buy and pay the seller in person. If sellers report 3 times in 30 days that they came and nobody was there, calling thelas is paused for 7 days. Chat is text only, phone numbers cannot be sent, and messages are deleted after 24 hours. Either side can block or report.']),
  ('', 'Delivery code and missing items', ['When your order is packed you get a 4-digit delivery code. Give it only after you receive your items. If the store does not have an item, it is removed and your total goes down; you can cancel until the order is packed.']),
  ('', 'Seller obligations', ['Stores must upload a real photo of their own shop taken in the app at the shop’s location. A false photo or details can lead to suspension. Sellers set their own prices, which must not exceed MRP.']),
  ('', 'Complaints', ['Report a problem from the order screen. We pass it to the store or seller, keep a record and may suspend those at fault. Our Grievance Officer (' + MAIL + ') acknowledges within 48 hours and resolves within one month.']),
  ('', 'This website', ['Photos on this website are illustrative and do not show real Nukkad Kart partners. Joining the early access list does not create an account or any obligation.']),
]

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, 'privacy.html'), 'w') as f:
    f.write(page('privacy', 'Privacy Policy', 'What Nukkad Kart collects, why, who sees it and how to delete it.',
        f'<h1>Privacy Policy</h1><p class="upd">Last updated: {UPDATED}</p>\n' + sections(PRIVACY) + '\n'))
with open(os.path.join(OUT, 'terms.html'), 'w') as f:
    f.write(page('terms', 'Terms', 'The terms for using Nukkad Kart.',
        f'<h1>Terms</h1><p class="upd">Last updated: {UPDATED}</p>\n' + sections(TERMS) + '\n'))
with open(os.path.join(OUT, '404.html'), 'w') as f:
    f.write(page('', 'Page not found', 'This page does not exist.',
        '<h1>This lane is empty.</h1><p class="upd">The page you were looking for is not here.</p><p><a href="/">Go to the home page</a></p>\n'))
print('ok')
