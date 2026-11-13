// Simple translations: English (en), Hindi (hi), Hinglish (hg).
// Product and category names stay in English in this build.

String gLang = 'en';

String t(String en) {
  if (gLang == 'en') return en;
  final m = _tr[en] ?? _tr2[en];
  if (m == null) return en;
  return m[gLang] ?? en;
}

/// Translation with values: tr('{0} m away', [120]).
String tr(String en, List<Object?> args) {
  var s = t(en);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
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

/// Newer screens: thela page, call to my street, chat, delivery, notification settings.
const Map<String, Map<String, String>> _tr2 = {
  'Log in to call a thela to your street.': {'hi': 'ठेले को अपनी गली में बुलाने के लिए लॉगिन करें।', 'hg': 'Thele ko apni gali mein bulane ke liye login karein.'},
  'Call {0} to your street?': {'hi': '{0} को अपनी गली में बुलाएँ?', 'hg': '{0} ko apni gali mein bulayein?'},
  'The thela sees this address, not your name or number. It has 3 minutes to answer. Pay the seller in person.': {'hi': 'ठेले वाले को यह पता दिखेगा, आपका नाम या नंबर नहीं। उसके पास जवाब देने के लिए 3 मिनट हैं। पैसे सीधे ठेले वाले को दें।', 'hg': 'Thele wale ko ye address dikhega, aapka naam ya number nahi. Uske paas jawab ke liye 3 minute hain. Paise seedhe thele wale ko dein.'},
  'Call to my street': {'hi': 'मेरी गली में बुलाएँ', 'hg': 'Meri gali mein bulayein'},
  'Waiting for {0}…': {'hi': '{0} के जवाब का इंतज़ार…', 'hg': '{0} ke jawab ka intezaar…'},
  'Sent to {0}.': {'hi': '{0} पर भेजा गया।', 'hg': '{0} pe bheja gaya.'},
  '{0} left to answer.': {'hi': 'जवाब के लिए {0} बाकी।', 'hg': 'Jawab ke liye {0} baaki.'},
  'Checking…': {'hi': 'देख रहे हैं…', 'hg': 'Dekh rahe hain…'},
  'Cancel': {'hi': 'रद्द करें', 'hg': 'Cancel karein'},
  '{0} is coming': {'hi': '{0} आ रहे हैं', 'hg': '{0} aa rahe hain'},
  'About {0} min · watch the pin on the map. Pay the seller directly.': {'hi': 'लगभग {0} मिनट · नक्शे पर पिन देखें। पैसे सीधे ठेले वाले को दें।', 'hg': 'Lagbhag {0} min · map pe pin dekhein. Paise seedhe thele wale ko dein.'},
  'I don’t need it now': {'hi': 'अब ज़रूरत नहीं', 'hg': 'Ab zaroorat nahi'},
  '{0} came but couldn’t find you. This happened {1} times, so calling thelas is paused for 7 days.': {'hi': '{0} आए पर आप नहीं मिले। ऐसा {1} बार हुआ, इसलिए ठेला बुलाना 7 दिन के लिए बंद है।', 'hg': '{0} aaye par aap nahi mile. Aisa {1} baar hua, isliye thela bulana 7 din ke liye band hai.'},
  '{0} came but couldn’t find you. This is {1} of {2} — at {2}, calling thelas is paused for 7 days.': {'hi': '{0} आए पर आप नहीं मिले। यह {2} में से {1} है — {2} होने पर ठेला बुलाना 7 दिन के लिए बंद हो जाएगा।', 'hg': '{0} aaye par aap nahi mile. Ye {2} mein se {1} hai — {2} hone pe thela bulana 7 din band ho jayega.'},
  '{0} can’t come right now. Try again later, or call another thela nearby.': {'hi': '{0} अभी नहीं आ सकते। बाद में कोशिश करें, या पास का कोई और ठेला बुलाएँ।', 'hg': '{0} abhi nahi aa sakte. Baad mein try karein, ya paas ka koi aur thela bulayein.'},
  'Calling thelas is paused until {0} because thelas came and found nobody {1} times.': {'hi': 'ठेला बुलाना {0} तक बंद है, क्योंकि ठेले वाले {1} बार आए और कोई नहीं मिला।', 'hg': 'Thela bulana {0} tak band hai, kyunki thele wale {1} baar aaye aur koi nahi mila.'},
  'Calling…': {'hi': 'बुला रहे हैं…', 'hg': 'Bula rahe hain…'},
  'You can call this thela when it is LIVE near you.': {'hi': 'जब यह ठेला आपके पास LIVE हो, तब आप इसे बुला सकते हैं।', 'hg': 'Jab ye thela aapke paas LIVE ho, tab aap ise bula sakte hain.'},
  'Standing here now. The pin moves when the thela moves.': {'hi': 'अभी यहीं खड़ा है। ठेला चलेगा तो पिन भी चलेगा।', 'hg': 'Abhi yahin khada hai. Thela chalega to pin bhi chalega.'},
  'On the move. The pin updates every few seconds.': {'hi': 'चल रहा है। पिन हर कुछ सेकंड में बदलता है।', 'hg': 'Chal raha hai. Pin har kuch second mein update hota hai.'},
  'Location hasn’t updated for a few minutes. The thela may have moved on.': {'hi': 'कुछ मिनट से लोकेशन नहीं आई। ठेला आगे बढ़ गया हो सकता है।', 'hg': 'Kuch minute se location nahi aayi. Thela aage badh gaya ho sakta hai.'},
  'Not within 500 m right now. You’ll get a notification when it’s back near you.': {'hi': 'अभी 500 मीटर के अंदर नहीं है। पास आने पर आपको सूचना मिलेगी।', 'hg': 'Abhi 500 m ke andar nahi hai. Paas aane pe aapko notification milegi.'},
  'Chat with {0}': {'hi': '{0} से चैट करें', 'hg': '{0} se chat karein'},
  'This thela hasn’t added today’s prices yet.': {'hi': 'इस ठेले ने आज के भाव अभी नहीं डाले।', 'hg': 'Is thele ne aaj ke bhav abhi nahi daale.'},
  'No cart for thelas. Call it to your street, then buy and pay the seller directly — not through Nukad Kart. Phone numbers are never shared.': {'hi': 'ठेले के लिए कार्ट नहीं है। उसे अपनी गली में बुलाएँ, फिर सामान लें और पैसे सीधे ठेले वाले को दें — नुक्कड़ कार्ट के ज़रिए नहीं। फ़ोन नंबर कभी नहीं दिखाए जाते।', 'hg': 'Thele ke liye cart nahi hai. Use apni gali mein bulayein, phir saman lein aur paise seedhe thele wale ko dein — Nukad Kart ke zariye nahi. Phone number kabhi share nahi hote.'},
  'Reported. Thanks — the chat is closed.': {'hi': 'रिपोर्ट हो गई। धन्यवाद — चैट बंद कर दी गई।', 'hg': 'Report ho gayi. Shukriya — chat band kar di gayi.'},
  'Unblocked.': {'hi': 'अनब्लॉक कर दिया।', 'hg': 'Unblock kar diya.'},
  'Blocked. They can’t message you.': {'hi': 'ब्लॉक कर दिया। वे आपको संदेश नहीं भेज सकते।', 'hg': 'Block kar diya. Wo aapko message nahi bhej sakte.'},
  'Unblock': {'hi': 'अनब्लॉक', 'hg': 'Unblock'},
  'Block': {'hi': 'ब्लॉक', 'hg': 'Block'},
  'Report': {'hi': 'रिपोर्ट', 'hg': 'Report'},
  'Log in to chat with this thela.': {'hi': 'इस ठेले से चैट करने के लिए लॉगिन करें।', 'hg': 'Is thele se chat karne ke liye login karein.'},
  '{0} is answering {1} people. Replies may take a few minutes — or tap “Call to my street”.': {'hi': '{0} अभी {1} लोगों को जवाब दे रहे हैं। जवाब में कुछ मिनट लग सकते हैं — या “मेरी गली में बुलाएँ” दबाएँ।', 'hg': '{0} abhi {1} logon ko jawab de rahe hain. Jawab mein kuch minute lag sakte hain — ya “Meri gali mein bulayein” dabayein.'},
  'Chat clears after 24 hours · Phone numbers are hidden': {'hi': 'चैट 24 घंटे बाद मिट जाती है · फ़ोन नंबर छिपे रहते हैं', 'hg': 'Chat 24 ghante baad mit jaati hai · Phone number chhupe rehte hain'},
  'You blocked this chat.': {'hi': 'आपने यह चैट ब्लॉक की है।', 'hg': 'Aapne ye chat block ki hai.'},
  'This chat is closed.': {'hi': 'यह चैट बंद है।', 'hg': 'Ye chat band hai.'},
  'Today’s prices · check before you ask': {'hi': 'आज के भाव · पूछने से पहले देख लें', 'hg': 'Aaj ke bhav · poochne se pehle dekh lein'},
  'Ask about items or price': {'hi': 'सामान या भाव के बारे में पूछें', 'hg': 'Saman ya bhav ke baare mein poochein'},
  'LIVE · Standing here': {'hi': 'LIVE · यहीं खड़ा है', 'hg': 'LIVE · Yahin khada hai'},
  'LIVE · Moving': {'hi': 'LIVE · चल रहा है', 'hg': 'LIVE · Chal raha hai'},
  'Was here {0} min ago': {'hi': '{0} मिनट पहले यहाँ था', 'hg': '{0} min pehle yahan tha'},
  'Not nearby now': {'hi': 'अभी पास में नहीं', 'hg': 'Abhi paas mein nahi'},
  '{0} m away · on the map': {'hi': '{0} मीटर दूर · नक्शे पर', 'hg': '{0} m door · map pe'},
  '{0} m away · moving': {'hi': '{0} मीटर दूर · चल रहा है', 'hg': '{0} m door · chal raha hai'},
  '{0} m away when last seen': {'hi': 'आख़िरी बार {0} मीटर दूर दिखा', 'hg': 'Aakhri baar {0} m door dikha'},
  'Last seen {0}': {'hi': 'आख़िरी बार {0} पर दिखा', 'hg': 'Aakhri baar {0} pe dikha'},
  'Location hidden': {'hi': 'लोकेशन छिपी है', 'hg': 'Location chhupi hai'},
  'This thela is not within 500 m right now, or its location stopped for 10 minutes.': {'hi': 'यह ठेला अभी 500 मीटर के अंदर नहीं है, या 10 मिनट से इसकी लोकेशन नहीं आई।', 'hg': 'Ye thela abhi 500 m ke andar nahi hai, ya 10 minute se iski location nahi aayi.'},
  'On the way from {0}': {'hi': '{0} से निकल चुका है', 'hg': '{0} se nikal chuka hai'},
  'On the way · {0} m away · about {1} min': {'hi': 'रास्ते में · {0} मीटर दूर · लगभग {1} मिनट', 'hg': 'Raste mein · {0} m door · lagbhag {1} min'},
  'Sending a test…': {'hi': 'टेस्ट भेज रहे हैं…', 'hg': 'Test bhej rahe hain…'},
  'Sent to {0} of {1} phones. It should appear in a few seconds.': {'hi': '{1} में से {0} फ़ोन पर भेजा। कुछ सेकंड में दिखना चाहिए।', 'hg': '{1} mein se {0} phone pe bheja. Kuch second mein dikhna chahiye.'},
  'Not sent.': {'hi': 'नहीं भेजा गया।', 'hg': 'Nahi bheja gaya.'},
  'Test notification': {'hi': 'टेस्ट सूचना', 'hg': 'Test notification'},
  '{0} didn’t have {1}. Removed from your order — new total {2}.': {'hi': '{0} के पास {1} नहीं था। ऑर्डर से हटा दिया — नया कुल {2}।', 'hg': '{0} ke paas {1} nahi tha. Order se hata diya — naya total {2}.'},
  'Order updates': {'hi': 'ऑर्डर की जानकारी', 'hg': 'Order updates'},
  'Always on (needed for the delivery code)': {'hi': 'हमेशा चालू (डिलीवरी कोड के लिए ज़रूरी)', 'hg': 'Hamesha on (delivery code ke liye zaroori)'},
  'Thela LIVE near me': {'hi': 'मेरे पास ठेला LIVE', 'hg': 'Mere paas thela LIVE'},
  'At most 3 a day · never 9 pm – 7 am': {'hi': 'दिन में ज़्यादा से ज़्यादा 3 · रात 9 से सुबह 7 नहीं', 'hg': 'Din mein max 3 · raat 9 se subah 7 nahi'},
  'Chat messages': {'hi': 'चैट संदेश', 'hg': 'Chat messages'},
  'Replies from thelas': {'hi': 'ठेले वालों के जवाब', 'hg': 'Thele walon ke jawab'},
  'Live thelas within 500 m. Pay the seller in person.': {'hi': '500 मीटर के अंदर LIVE ठेले। पैसे सीधे ठेले वाले को दें।', 'hg': '500 m ke andar LIVE thele. Paise seedhe thele wale ko dein.'},
  'Packed': {'hi': 'पैक हो गया', 'hg': 'Pack ho gaya'},
};
