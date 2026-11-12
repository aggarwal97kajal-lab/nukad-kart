// Simple translations: English (en), Hindi (hi), Hinglish (hg).
// Product and category names stay in English in this build.

String gLang = 'en';

String t(String en) {
  if (gLang == 'en') return en;
  final m = _tr[en];
  if (m == null) return en;
  return m[gLang] ?? en;
}

const Map<String, Map<String, String>> _tr = {
  // login & home extras
  'Skip': {'hi': 'छोड़ें', 'hg': 'Skip'},
  'Phone': {'hi': 'फ़ोन जैसा', 'hg': 'Phone jaisa'},
  'Explore without login': {'hi': 'बिना लॉगिन देखें', 'hg': 'Bina login dekhein'},
  'Shops and sellers within 500\u00A0m of you': {
    'hi': 'आपके 500\u00A0मीटर के अंदर की दुकानें और ठेले',
    'hg': 'Aapke 500\u00A0m ke andar ki dukaanein aur thele'
  },
  'Browse freely. Log in only when you place your first order.': {
    'hi': 'आराम से देखिए। लॉगिन सिर्फ़ पहला ऑर्डर देते समय।',
    'hg': 'Aaram se dekhiye. Login sirf pehla order dete waqt.'
  },
  'Shops near you': {'hi': 'आपके पास की दुकानें', 'hg': 'Paas ki dukaanein'},
  'Change location': {'hi': 'जगह बदलें', 'hg': 'Location badlein'},
  // navigation
  'Home': {'hi': 'होम', 'hg': 'Home'},
  'Categories': {'hi': 'कैटेगरी', 'hg': 'Categories'},
  'Orders': {'hi': 'ऑर्डर', 'hg': 'Orders'},
  'Account': {'hi': 'अकाउंट', 'hg': 'Account'},
  // home
  'DELIVER TO HOME': {'hi': 'घर पर डिलीवरी', 'hg': 'GHAR PAR DELIVERY'},
  'Search atta, doodh, tamatar…': {'hi': 'आटा, दूध, टमाटर खोजें…', 'hg': 'Atta, doodh, tamatar dhoondhiye…'},
  'Shops': {'hi': 'दुकानें', 'hg': 'Dukaanein'},
  'Moving sellers': {'hi': 'ठेले वाले', 'hg': 'Thele wale'},
  'Shops within 500 m': {'hi': '500 मीटर के अंदर दुकानें', 'hg': '500 m ke andar dukaanein'},
  'You pay the store at delivery, cash or UPI. Nukad Kart adds no fee to your bill.': {
    'hi': 'डिलीवरी पर दुकान को नकद या UPI से पैसे दें। नुक्कड़ कार्ट आपके बिल में कोई फीस नहीं जोड़ता।',
    'hg': 'Delivery par dukaan ko cash ya UPI se pay kariye. Nukad Kart bill mein koi fee nahi jodta.'
  },
  'Moving sellers near you': {'hi': 'आपके पास ठेले वाले', 'hg': 'Aapke paas thele wale'},
  'Call or WhatsApp them, then pay in person. Only sellers within 500 m are shown.': {
    'hi': 'उन्हें कॉल या WhatsApp करें और सामने पैसे दें। सिर्फ 500 मीटर के अंदर वाले दिखते हैं।',
    'hg': 'Unhe call ya WhatsApp kariye, paise saamne dijiye. Sirf 500 m ke andar wale dikhte hain.'
  },
  'Door delivery': {'hi': 'घर पर डिलीवरी', 'hg': 'Ghar par delivery'},
  'Pickup': {'hi': 'खुद ले जाएँ', 'hg': 'Pickup'},
  'Comes to door': {'hi': 'घर आते हैं', 'hg': 'Ghar aate hain'},
  'Comes to your door': {'hi': 'घर आते हैं', 'hg': 'Ghar aate hain'},
  'Pickup at thela': {'hi': 'ठेले से लें', 'hg': 'Thele se lein'},
  'Pay at delivery': {'hi': 'डिलीवरी पर भुगतान', 'hg': 'Delivery par payment'},
  'Notifications': {'hi': 'सूचनाएँ', 'hg': 'Notifications'},
  // categories / orders
  'All categories': {'hi': 'सभी कैटेगरी', 'hg': 'Saari categories'},
  'My orders': {'hi': 'मेरे ऑर्डर', 'hg': 'Mere orders'},
  'Your orders': {'hi': 'आपके ऑर्डर', 'hg': 'Aapke orders'},
  'No orders yet': {'hi': 'अभी कोई ऑर्डर नहीं', 'hg': 'Abhi koi order nahi'},
  'Waiting for store': {'hi': 'दुकान के जवाब का इंतज़ार', 'hg': 'Dukaan ka intezaar'},
  'Accepted by store': {'hi': 'दुकान ने स्वीकार किया', 'hg': 'Dukaan ne accept kiya'},
  'Packed': {'hi': 'पैक हो गया', 'hg': 'Pack ho gaya'},
  'Out for delivery': {'hi': 'डिलीवरी के लिए निकला', 'hg': 'Delivery ke liye nikla'},
  'Delivered': {'hi': 'पहुँच गया', 'hg': 'Deliver ho gaya'},
  'Rejected by store': {'hi': 'दुकान ने मना किया', 'hg': 'Dukaan ne mana kiya'},
  'Auto-cancelled': {'hi': 'अपने आप रद्द', 'hg': 'Apne aap cancel'},
  'Cancelled': {'hi': 'रद्द', 'hg': 'Cancel'},
  'Order placed': {'hi': 'ऑर्डर दिया', 'hg': 'Order diya'},
  'Cancel order': {'hi': 'ऑर्डर रद्द करें', 'hg': 'Order cancel karein'},
  'Report a problem': {'hi': 'समस्या बताएँ', 'hg': 'Problem bataiye'},
  // cart
  'Your cart': {'hi': 'आपकी कार्ट', 'hg': 'Aapki cart'},
  'How do you want it?': {'hi': 'सामान कैसे चाहिए?', 'hg': 'Saamaan kaise chahiye?'},
  'Deliver to home': {'hi': 'घर पर पहुँचाएँ', 'hg': 'Ghar par pahunchaiye'},
  'I’ll pick up': {'hi': 'मैं खुद ले जाऊँगा', 'hg': 'Main khud le jaunga'},
  'Bill details': {'hi': 'बिल', 'hg': 'Bill details'},
  'Items total (incl. GST)': {'hi': 'सामान का कुल (GST सहित)', 'hg': 'Saamaan total (GST ke saath)'},
  'Delivery': {'hi': 'डिलीवरी', 'hg': 'Delivery'},
  'Free': {'hi': 'मुफ़्त', 'hg': 'Free'},
  'The store has 5 minutes to accept': {
    'hi': 'दुकान के पास स्वीकार करने के लिए 5 मिनट हैं',
    'hg': 'Dukaan ke paas accept karne ke liye 5 minute hain'
  },
  'View cart': {'hi': 'कार्ट देखें', 'hg': 'Cart dekhiye'},
  'ADD': {'hi': 'जोड़ें', 'hg': 'ADD'},
  // store / product
  'Sold near you': {'hi': 'आपके पास यहाँ मिलता है', 'hg': 'Aapke paas yahan milta hai'},
  'Your rating': {'hi': 'आपकी रेटिंग', 'hg': 'Aapki rating'},
  'Edit': {'hi': 'बदलें', 'hg': 'Edit'},
  'Out of stock': {'hi': 'स्टॉक में नहीं', 'hg': 'Stock khatam'},
  'OUT OF STOCK': {'hi': 'स्टॉक में नहीं', 'hg': 'STOCK KHATAM'},
  'Notify': {'hi': 'बताएँ', 'hg': 'Notify'},
  'Notify on': {'hi': 'सूचना चालू', 'hg': 'Notify on'},
  // thela
  'Today’s prices': {'hi': 'आज के भाव', 'hg': 'Aaj ke daam'},
  'Request for tomorrow': {'hi': 'कल के लिए बुलाएँ', 'hg': 'Kal ke liye request'},
  'Call': {'hi': 'कॉल', 'hg': 'Call'},
  // login
  'Continue with Google': {'hi': 'Google से जारी रखें', 'hg': 'Google se continue karein'},
  'Your phone number': {'hi': 'आपका फ़ोन नंबर', 'hg': 'Aapka phone number'},
  'Save & continue': {'hi': 'सेव करें और आगे बढ़ें', 'hg': 'Save karke aage badhein'},
  // account
  'Search area, street or landmark': {'hi': 'इलाका, गली या पास की जगह खोजें', 'hg': 'Area, gali ya landmark search karein'},
  'Today': {'hi': 'आज', 'hg': 'Aaj'},
  'Yesterday': {'hi': 'कल', 'hg': 'Kal'},
  'Reorder': {'hi': 'फिर से मंगाएं', 'hg': 'Phir se mangayein'},
  'Rate order': {'hi': 'रेटिंग दें', 'hg': 'Rating dein'},
  'Logged-in devices': {'hi': 'लॉग-इन डिवाइस', 'hg': 'Logged-in devices'},
  'Privacy policy': {'hi': 'प्राइवेसी पॉलिसी', 'hg': 'Privacy policy'},
  'Edit profile': {'hi': 'प्रोफ़ाइल बदलें', 'hg': 'Profile edit karein'},
  'Appearance': {'hi': 'दिखावट', 'hg': 'Appearance'},
  'Language': {'hi': 'भाषा', 'hg': 'Bhasha'},
  'LIGHT': {'hi': 'लाइट', 'hg': 'LIGHT'},
  'DARK': {'hi': 'डार्क', 'hg': 'DARK'},
  'PHONE': {'hi': 'फ़ोन जैसा', 'hg': 'PHONE JAISA'},
  'Light': {'hi': 'लाइट', 'hg': 'Light'},
  'Dark': {'hi': 'डार्क', 'hg': 'Dark'},
  'Same as phone': {'hi': 'फ़ोन जैसा', 'hg': 'Phone jaisa'},
  'Follows your phone’s setting': {'hi': 'फ़ोन की सेटिंग के हिसाब से', 'hg': 'Phone ki setting ke hisaab se'},
  'Choose how Nukad Kart looks': {'hi': 'नुक्कड़ कार्ट कैसा दिखे, चुनें', 'hg': 'Nukad Kart kaisa dikhe, chuniye'},
  'App text changes right away': {'hi': 'ऐप की भाषा तुरंत बदल जाएगी', 'hg': 'App ki bhasha turant badal jaayegi'},
  'Your information': {'hi': 'आपकी जानकारी', 'hg': 'Aapki jaankari'},
  'Address book': {'hi': 'पते', 'hg': 'Address book'},
  'Bookmarked stores': {'hi': 'सेव की गई दुकानें', 'hg': 'Save ki hui dukaanein'},
  'Your wishlist': {'hi': 'आपकी विशलिस्ट', 'hg': 'Aapki wishlist'},
  'Other information': {'hi': 'अन्य जानकारी', 'hg': 'Aur jaankari'},
  'Share this app': {'hi': 'ऐप शेयर करें', 'hg': 'App share karein'},
  'About us': {'hi': 'हमारे बारे में', 'hg': 'Hamare baare mein'},
  'Account privacy': {'hi': 'अकाउंट प्राइवेसी', 'hg': 'Account privacy'},
  'Notification preferences': {'hi': 'सूचना सेटिंग', 'hg': 'Notification settings'},
  'FAQ': {'hi': 'सवाल-जवाब', 'hg': 'FAQ'},
  'Log out': {'hi': 'लॉग आउट', 'hg': 'Log out'},
  'Log out?': {'hi': 'लॉग आउट करें?', 'hg': 'Log out karein?'},
  'Choose where you want to log out': {'hi': 'कहाँ से लॉग आउट करना है, चुनें', 'hg': 'Kahan se log out karna hai, chuniye'},
  'This device only': {'hi': 'सिर्फ इस फ़ोन से', 'hg': 'Sirf is phone se'},
  'You stay logged in on other phones': {'hi': 'दूसरे फ़ोन पर लॉग इन रहेंगे', 'hg': 'Doosre phone par login rahenge'},
  'All devices': {'hi': 'सभी फ़ोन से', 'hg': 'Saare phones se'},
  'Logs out everywhere, including this phone': {
    'hi': 'हर जगह से लॉग आउट, इस फ़ोन से भी',
    'hg': 'Har jagah se log out, is phone se bhi'
  },
  'Cancel': {'hi': 'रद्द करें', 'hg': 'Cancel'},
};
