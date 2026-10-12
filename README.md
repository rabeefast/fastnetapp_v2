# Fast Net — تطبيق إدارة بطاقات الإنترنت (المرحلة الأولى)

نظام لإدارة بطاقات User Manager (المخزون على disk1 داخل الراوتر RB1100Dx4)
وحركتها بين المدير والوكلاء ونقاط البيع بالأجل، مع مزامنة سحابية وتليجرام.

## ما تتضمنه هذه المرحلة

- [x] الدخول بالبريد/كلمة المرور عبر Firebase Auth (أول حساب يدخل = المدير)
- [x] فصل الأدوار: مدير / وكيل / نقطة بيع
- [x] تبويب «الفئات» في إعدادات المدير: عدد الفئات + الأسماء + أسمائها في User Manager
- [x] تسعيرة المسارين (مدير←وكيل / وكيل←نقطة بيع) قابلة للتعديل بالكامل من الإعدادات
- [x] حجم الصفحة وعدد المجاني بعدها مرنان (الحساب المالي هو المرجع)
- [x] حد تنبيه انخفاض المخزون + ربط تليجرام (توكن على جهاز المدير فقط) + رسالة اختبار
- [x] محرك الحساب المالي + اختباراته (flutter test)
- [x] بناء APK تلقائي عبر GitHub Actions

## المرحلة الثانية (تالية): استيراد PDF + تدفق التسليم + المديونيات والسداد + قراءة الراوتر

---

## خطوات التشغيل (بالترتيب)

### 1) إنشاء Firebase (بحساب Gmail)

1. ادخل `console.firebase.google.com` وسجّل بحساب Gmail
2. Create project → اسم مثل `fastnet-cards`
3. Authentication → Get started → فعّل **Email/Password**
4. Project settings → Your apps → أيقونة Android:

- Package name: `com.fastnet.fastnet_app`
- اترك SHA-1 فارغًا واضغط Register

5. انسخ القيم الخمس من **SDK setup and configuration** والصقها في
`lib/firebase_options.dart` مكان PASTE_...
6. Firestore Database → Create database → **Production mode** → أقرب region

### 2) قواعد أمان Firestore (Firestore Database → Rules → انشر)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() { return request.auth != null; }
    match /users/{uid} {
      allow read: if signedIn() && (request.auth.uid == uid);
      allow create: if signedIn() && request.auth.uid == uid;
      allow update, delete: if false;
    }
    match /settings/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    match /{doc=**} {
      allow read, write: if signedIn();
    }
  }
}
```

> هذه قواعد مرحلة أولى عملية (الحسابات كلها يوزعها المدير). تشديدها أكثر يأتي لاحقًا.

### 3) إنشاء حسابات الوكلاء ونقاط البيع

من Firebase Console → Authentication → Users → Add user
ثم من Firestore → collection `users` → أضف مستندًا بمعرف الـ UID الخاص بالمستخدم:

```javascript
{ name: "اسم الوكيل", role: "agent", phone: "777...", parentUid: "UID_المدير" }
```

ولنقطة البيع: `role: "pos"` و `parentUid: "UID_الوكيل"`

### 4) بناء APK عبر GitHub (بدون تثبيت أي شيء على جهازك)

1. أنشئ حساب GitHub مجاني، ثم New repository باسم `fastnet_app` (خاص Private)
2. ارفع محتويات هذا المجلد (من تبويب Add file → Upload files، أو بأوامر git)
3. من تبويب **Actions** ستبدأ عملية البناء تلقائيًا خلال دقائق
4. عند الانتهاء: قسم **Artifacts** → حمّل `FastNet-APK` → الملف `app-release.apk`
5. انقله لجوالك وثبّته (اسمح بالتثبيت من مصادر غير معروفة)

### 5) حساب الـ API للراوتر (للمرحلة الثانية — أنشئه الآن)

في Terminal للراوتر:

```javascript
/user add name=fastnetapi group=fastnet-read password=كلمة_قوية_جدا comment="FastNet App read-only"
```

- المجموعة `fastnet-read` موجودة أصلًا في إعداداتك بصلاحيات `read,api` فقط
- الاتصال بالراوتر من التطبيق سيقتصر على حساب المدير فقط

---

## بنية البيانات (Firestore)

| المجموعة | الوثيقة | الحقول |
| --- | --- | --- |
| users | uid | name, role(manager/agent/pos), phone, parentUid |
| settings | uid المدير | categories[], lowStockThreshold |
| batches | تلقائي | managerUid, name(من تاريخ الاستيراد + قابل للتعديل), createdAt |
| cards | username | batchId, categoryKey, serial, status(inStock/delivered/sold), holderUid |
| deliveries | تلقائي | fromUid, toUid, batchId, side(mg/ag), items[], totalAmount |
| payments | تلقائي | fromUid, toUid, amount, note |

## مبدأ العمل دون اتصال

مكتبة Firestore تحتفظ بذاكرة محلية على الجوال: يكتب المستخدم بياناته بلا إنترنت،
وتُدفع التغييرات تلقائيًا فور عودة الاتصال — دون أي زر "مزامنة".

## اختبار سريع

1. سجّل دخولك بأول حساب ← يصبح مديرًا تلقائيًا
2. الإعدادات ← عدد الفئات 6 ← تحقق من الأسماء والأسعار ← احفظ
3. أدخل توكن البوت و Chat ID ← أرسل رسالة اختبار
4. أنشئ حساب وكيل من Console وجرّب دخوله من جوال آخر