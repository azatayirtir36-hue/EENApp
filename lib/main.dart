import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ceviriler.dart';

// ============================================================
// MAIN
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDhaNl7qja91mZfSDWkJah5ZFn54OndIhU",
          appId: "1:777113487548:android:1122bb35dd341f122128b9",
          messagingSenderId: "777113487548",
          projectId: "eenapp-4b41c",
          storageBucket: "eenapp-4b41c.firebasestorage.app",
        ),
      );
    }
  } catch (e) {
    debugPrint("Firebase hatası: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => KimlikYoneticisi()),
        ChangeNotifierProvider(create: (_) => TemaYoneticisi()),
        ChangeNotifierProvider(create: (_) => DilYoneticisi()),
      ],
      child: const EENApp(),
    ),
  );
}

// ============================================================
// TEMA YÖNETİCİSİ
// ============================================================
class TemaYoneticisi extends ChangeNotifier {
  bool _karanlikMi = true;
  String _dil = 'tr';

  bool get karanlikMi => _karanlikMi;
  String get dil => _dil;

  void temaDegistir(bool k) {
    _karanlikMi = k;
    notifyListeners();
  }

  void dilDegistir(String d) {
    _dil = d;
    notifyListeners();
  }
}

// ============================================================
// KİMLİK YÖNETİCİSİ
// ============================================================
class KimlikYoneticisi extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? aktifKullanici;
  String kullaniciRolu = 'musteri';
  String hataMesaji = '';
  bool yukleniyor = false;

  KimlikYoneticisi() {
    _auth.authStateChanges().listen((user) async {
      aktifKullanici = user;
      if (user != null) {
        try {
          final doc =
              await _db.collection('kullaniciDetaylari').doc(user.uid).get();
          if (doc.exists) {
            kullaniciRolu = doc.data()?['rol'] ?? 'musteri';
          }
        } catch (e) {
          debugPrint('Rol hatası: $e');
        }
      }
      notifyListeners();
    });
  }

  bool get adminMi => aktifKullanici?.email == 'azatayirtir36@gmail.com';

  Future<bool> girisYap(String email, String sifre) async {
    try {
      yukleniyor = true;
      hataMesaji = '';
      notifyListeners();
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: sifre);
      return true;
    } on FirebaseAuthException catch (e) {
      hataMesaji = _cevir(e);
      return false;
    } finally {
      yukleniyor = false;
      notifyListeners();
    }
  }

  Future<bool> kayitOl(
      String email, String sifre, String rol, Map<String, dynamic> detay) async {
    try {
      yukleniyor = true;
      hataMesaji = '';
      notifyListeners();

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: sifre);
      String uid = cred.user!.uid;

      await _db.collection('kullaniciDetaylari').doc(uid).set({
        'eposta': email.trim(),
        'rol': rol,
        ...detay,
        'zaman': FieldValue.serverTimestamp(),
      });

     if (rol == 'nakliyeci') {
  String docId = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  DateTime simdi = DateTime.now();
  DateTime bitis = simdi.add(const Duration(days: 5));

  await _db.collection('nakliyeciler').doc(docId).set({
    'eposta': email.trim(),
    'unvan': detay['adSoyad'] ?? 'Nakliye Firması',
    'telefon': detay['telefon'] ?? '',
    'uyelikTipi': 'Deneme',
    'kalanDoping': 0,
    'puan': 5.0,
    'oySayisi': 0,
    'kmFiyat': 45,
    'profilFoto':
        'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
    // YENİ ALANLAR
    'denemeBaslangic': FieldValue.serverTimestamp(),
    'denemeBitis': Timestamp.fromDate(bitis),
    'odemeYapildi': false,
    'aktivasyonKodu': '',
    'paketBitis': null,
  });
}

      return true;
    } on FirebaseAuthException catch (e) {
      hataMesaji = _cevir(e);
      return false;
    } finally {
      yukleniyor = false;
      notifyListeners();
    }
  }

  Future<bool> sifreSifirla(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      hataMesaji = _cevir(e);
      return false;
    }
  }

  Future<void> cikisYap() async {
    await _auth.signOut();
    kullaniciRolu = 'musteri';
    notifyListeners();
  }

  String _cevir(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Bu e-posta kayıtlı değil.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta kullanımda.';
      case 'invalid-email':
        return 'Geçersiz e-posta.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı.';
      default:
        return e.message ?? 'Hata oluştu.';
    }
  }
}

// ============================================================
// ANA UYGULAMA
// ============================================================
class EENApp extends StatelessWidget {
  const EENApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Provider.of<TemaYoneticisi>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EENApp',
      themeMode: tema.karanlikMi ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          surface: Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          centerTitle: true,
        ),
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF3B82F6),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const _Yonlendirici(),
    );
  }
}

// ============================================================
// YÖNLENDİRİCİ (Giriş mi, Ana ekran mı?)
// ============================================================
class _Yonlendirici extends StatelessWidget {
  const _Yonlendirici();

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);

    if (kimlik.aktifKullanici == null) {
      return const GirisEkrani();
    }
    return const AnaSekran();
  }
}

// ============================================================
// GİRİŞ EKRANI
// ============================================================
class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _email = TextEditingController();
  final _sifre = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
  'https://i.hizliresim.com/dgflmu34.png',
  height: 120,
  fit: BoxFit.contain,
  errorBuilder: (_, __, ___) => const Icon(
    Icons.local_shipping,
    size: 100,
    color: Colors.blueAccent,
  ),
),
const SizedBox(height: 20),
                const SizedBox(height: 5),
                const Text(
                  'Nakliye Pazaryeri',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _sifre,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (kimlik.hataMesaji.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(kimlik.hataMesaji,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent),
                    onPressed: kimlik.yukleniyor
                        ? null
                        : () async {
                            if (_email.text.isEmpty || _sifre.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('E-posta ve şifre gir!')));
                              return;
                            }
                            await kimlik.girisYap(_email.text, _sifre.text);
                          },
                    child: kimlik.yukleniyor
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Giriş Yap',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const KayitEkrani()),
                    );
                  },
                  child: const Text('Hesabın yok mu? Kayıt ol'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SifreSifirlaEkrani()),
                    );
                  },
                  child: const Text('Şifremi unuttum'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// KAYIT EKRANI
// ============================================================
class KayitEkrani extends StatefulWidget {
  const KayitEkrani({super.key});

  @override
  State<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends State<KayitEkrani> {
  final _email = TextEditingController();
  final _sifre = TextEditingController();
  final _ad = TextEditingController();
  final _tel = TextEditingController();
  String _rol = 'musteri';

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ROL SEÇİMİ
              const Text('Hesap Türü',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Müşteri'),
                      value: 'musteri',
                      groupValue: _rol,
                      onChanged: (v) => setState(() => _rol = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Nakliyeci'),
                      value: 'nakliyeci',
                      groupValue: _rol,
                      onChanged: (v) => setState(() => _rol = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ad,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad / Firma Ünvanı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tel,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sifre,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Şifre (en az 6 karakter)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (kimlik.hataMesaji.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(kimlik.hataMesaji,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent),
                  onPressed: kimlik.yukleniyor
                      ? null
                      : () async {
                          if (_email.text.isEmpty ||
                              _sifre.text.isEmpty ||
                              _ad.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Tüm alanları doldur!')));
                            return;
                          }
                          bool ok = await kimlik.kayitOl(
                            _email.text,
                            _sifre.text,
                            _rol,
                            {
                              'adSoyad': _ad.text.trim(),
                              'telefon': _tel.text.trim(),
                            },
                          );
                          if (ok && mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: kimlik.yukleniyor
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Kayıt Ol',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ŞİFRE SIFIRLA
// ============================================================
class SifreSifirlaEkrani extends StatefulWidget {
  const SifreSifirlaEkrani({super.key});

  @override
  State<SifreSifirlaEkrani> createState() => _SifreSifirlaEkraniState();
}

class _SifreSifirlaEkraniState extends State<SifreSifirlaEkrani> {
  final _email = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Şifre Sıfırla')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              'E-postanı gir, sıfırlama linki gönderelim.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent),
                onPressed: () async {
                  if (_email.text.isEmpty) return;
                  bool ok = await kimlik.sifreSifirla(_email.text);
                  if (ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mail gönderildi!')));
                    Navigator.pop(context);
                  }
                },
                child: const Text('Mail Gönder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ANA EKRAN (BottomNav + Ayarlar)
// ============================================================
class AnaSekran extends StatefulWidget {
  const AnaSekran({super.key});

  @override
  State<AnaSekran> createState() => _AnaSekranState();
}

class _AnaSekranState extends State<AnaSekran> {
  int _secilenIndex = 0;

final List<Widget> _sayfalar = const[
  FirmalarSekmesi(),
  IlanlarSekmesi(),
  MesajlarSekmesi(),
  BildirimlerSekmesi(),
  ProfilSekmesi(),
];

  final List<String> _basliklar = const [
    'Nakliye Firmaları',
    'İlanlar',
    'Mesajlarım',
    'Profilim',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(
  title: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.network(
        'https://i.hizliresim.com/dgflmu34.png',
        height: 30,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.local_shipping,
          size: 24,
        ),
      ),
      const SizedBox(width: 10),
      Text(_basliklar[_secilenIndex]),
    ],
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.settings),
      tooltip: 'Ayarlar',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AyarlarEkrani()),
        );
      },
    ),
  ],
),
      body: _sayfalar[_secilenIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _secilenIndex,
        onTap: (i) => setState(() => _secilenIndex = i),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.business), label: 'Firmalar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt), label: 'İlanlar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble), label: 'Mesajlar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// ============================================================
// AYARLAR
// ============================================================
class AyarlarEkrani extends StatelessWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Provider.of<TemaYoneticisi>(context);
    final dil = Provider.of<DilYoneticisi>(context);
        final kimlik = Provider.of<KimlikYoneticisi>(context);

    return Scaffold(
      appBar: AppBar(title: Text(dil.cevir('ayarlar'))),
      body: ListView(
        children: [
          // TEMA
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(dil.cevir('gorunum'),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
          ),
          SwitchListTile(
            title: Text(dil.cevir('karanlik_tema')),
            secondary:
                Icon(tema.karanlikMi ? Icons.dark_mode : Icons.light_mode),
            value: tema.karanlikMi,
            onChanged: (v) => tema.temaDegistir(v),
          ),

          const Divider(),

          // DİL
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(dil.cevir('dil'),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
          ),
          RadioListTile<String>(
            title: Text(dil.cevir('turkce')),
            value: 'tr',
            groupValue: dil.dil,
            onChanged: (v) => dil.dilDegistir(v!),
          ),
          RadioListTile<String>(
            title: Text(dil.cevir('ingilizce')),
            value: 'en',
            groupValue: dil.dil,
            onChanged: (v) => dil.dilDegistir(v!),
          ),
          RadioListTile<String>(
            title: Text(dil.cevir('kurtce')),
            value: 'ku',
            groupValue: dil.dil,
            onChanged: (v) => dil.dilDegistir(v!),
          ),

          const Divider(),
                    // ADMİN İSE KAMPANYA GÖNDER
          if (kimlik.adminMi) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.campaign, color: Colors.pink),
              title: const Text('📢 Kampanya Gönder',
                  style: TextStyle(color: Colors.pink)),
              subtitle: const Text('Tüm kullanıcılara bildirim gönder'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KampanyaGonderSayfasi(),
                  ),
                );
              },
            ),
          ],

          // ÇIKIŞ
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text(dil.cevir('cikis_yap'),
                style: const TextStyle(color: Colors.redAccent)),
            onTap: () async {
              final kimlik = Provider.of<KimlikYoneticisi>(context, listen: false);
              await kimlik.cikisYap();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FİRMALAR
// ============================================================
class FirmalarSekmesi extends StatefulWidget {
  const FirmalarSekmesi({super.key});

  @override
  State<FirmalarSekmesi> createState() => _FirmalarSekmesiState();
}

class _FirmalarSekmesiState extends State<FirmalarSekmesi> {
  final _arama = TextEditingController();
  String _aramaMetni = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ============ ARAMA ÇUBUĞU ============
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _arama,
            onChanged: (v) =>
                setState(() => _aramaMetni = v.toLowerCase().trim()),
            decoration: InputDecoration(
              hintText: '🔍  Firma ara...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _aramaMetni.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _arama.clear();
                        setState(() => _aramaMetni = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ============ FİRMA LİSTESİ ============
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('nakliyeciler')
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Center(child: Text('Hata: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var tumListe = snap.data!.docs;

              // Filtreleme
              var liste = tumListe.where((doc) {
                if (_aramaMetni.isEmpty) return true;
                var d = doc.data() as Map<String, dynamic>;
                String unvan =
                    (d['unvan'] ?? '').toString().toLowerCase();
                String tel =
                    (d['telefon'] ?? '').toString().toLowerCase();
                return unvan.contains(_aramaMetni) ||
                    tel.contains(_aramaMetni);
              }).toList();

              if (liste.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off,
                          size: 70, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text(
                        _aramaMetni.isEmpty
                            ? 'Henüz firma yok.'
                            : 'Aramada sonuç bulunamadı.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: liste.length,
                itemBuilder: (ctx, i) {
                  var d = liste[i].data() as Map<String, dynamic>;

                  // UyelikKontrol sınıfı ile rozet
                  var kontrol = UyelikKontrol(d);

                  return Opacity(
                    opacity: kontrol.aktifMi ? 1.0 : 0.5,
                    child: Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          backgroundImage: NetworkImage(
                            d['profilFoto'] ??
                                'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
                          ),
                          onBackgroundImageError: (_, __) {},
                        ),
                        title: Text(d['unvan'] ?? 'Firma'),
                        subtitle: Text('Tel: ${d['telefon'] ?? '-'}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kontrol.rozetRengi,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            kontrol.rozetMetni,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FirmaDetaySayfasi(nakliyeci: d),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class FirmaDetaySayfasi extends StatelessWidget {
  final Map<String, dynamic> nakliyeci;

  const FirmaDetaySayfasi({super.key, required this.nakliyeci});

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);

    final unvan = (nakliyeci['unvan'] ?? 'Firma').toString();
    final profilFoto = (nakliyeci['profilFoto'] ??
            'https://cdn-icons-png.flaticon.com/512/3135/3135715.png')
        .toString();
    final kapakFoto = (nakliyeci['kapakFoto'] ??
            'https://images.unsplash.com/photo-1497366216548-37526070297c?w=800')
        .toString();

    var kontrol = UyelikKontrol(nakliyeci);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // KAPAK
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(unvan, style: const TextStyle(fontSize: 16)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    kapakFoto,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // İÇERİK
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // PROFİL FOTOĞRAFI
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: const Color(0xFF0F172A),
                    child: CircleAvatar(
                      radius: 51,
                      backgroundImage: NetworkImage(profilFoto),
                      onBackgroundImageError: (_, __) {},
                    ),
                  ),
                  const SizedBox(height: 12),

                  // İSİM
                  Text(
                    unvan,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  // ROZET
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: kontrol.rozetRengi,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      kontrol.rozetMetni,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // İSTATİSTİKLER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _istatistik(
                          '⭐ ${(nakliyeci['puan'] ?? 5.0).toString()}',
                          'Puan'),
                      _istatistik(
                          '${nakliyeci['oySayisi'] ?? 0}', 'Değerlendirme'),
                      _istatistik(
                          '₺${nakliyeci['kmFiyat'] ?? '45'}', 'Km Fiyatı'),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // BİLGİLER
                  Card(
                    color: const Color(0xFF1E293B),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('İletişim',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.phone,
                                  size: 20, color: Colors.blueAccent),
                              const SizedBox(width: 10),
                              Text((nakliyeci['telefon'] ?? '-').toString()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.email,
                                  size: 20, color: Colors.blueAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    (nakliyeci['eposta'] ??
                                            nakliyeci['email'] ??
                                            '-')
                                        .toString(),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // BİYOGRAFİ
                  if ((nakliyeci['biyografi'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Card(
                      color: const Color(0xFF1E293B),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hakkında',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber)),
                            const SizedBox(height: 8),
                            Text(nakliyeci['biyografi'].toString()),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  
                // BUTONLAR - SATIR 1: Sohbet + Ara
Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.chat),
        label: const Text('Sohbet Et'),
        onPressed: () {
          if (kimlik.aktifKullanici == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Sohbet için giriş yapmalısınız!')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SohbetSayfasi(
                digerEmail: (nakliyeci['eposta'] ?? '').toString(),
                digerAd: unvan,
              ),
            ),
          );
        },
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.phone),
        label: const Text('Ara'),
        onPressed: () async {
          final tel = (nakliyeci['telefon'] ?? '').toString().trim();
          if (tel.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Telefon numarası yok!')),
            );
            return;
          }

          final temizTel = tel.replaceAll(RegExp(r'\D'), '');
          final url = Uri.parse('tel:$temizTel');

          try {
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Bu cihazda arama desteklenmiyor')),
                );
              }
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Arama başlatılamadı: $e')),
              );
            }
          }
        },
      ),
    ),
  ],
),

const SizedBox(height: 10),

// BUTONLAR - SATIR 2: Yorum Yap
Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.star, color: Colors.black),
        label: const Text('Yorum Yap',
            style: TextStyle(color: Colors.black)),
        onPressed: () {
          if (kimlik.aktifKullanici == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Yorum için giriş yapmalısınız!')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => YorumYapSayfasi(
                nakliyeciId: (nakliyeci['id'] ?? '').toString(),
                firmaAdi: unvan,
              ),
            ),
          );
        },
      ),
    ),
  ],
),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _istatistik(String ust, String alt) {
    return Column(
      children: [
        Text(ust,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(alt,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

// ============================================================
// İLAN EKLE
// ============================================================
class IlanEkleSayfasi extends StatefulWidget {
  const IlanEkleSayfasi({super.key});

  @override
  State<IlanEkleSayfasi> createState() => _IlanEkleSayfasiState();
}

class _IlanEkleSayfasiState extends State<IlanEkleSayfasi> {
  final _baslik = TextEditingController();
  final _kategori = TextEditingController();
  final _nereden = TextEditingController();
  final _nereye = TextEditingController();
  final _detay = TextEditingController();
  bool _kaydediliyor = false;

  Future<void> _ilanEkle() async {
    if (_baslik.text.trim().isEmpty ||
        _nereden.text.trim().isEmpty ||
        _nereye.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık, nereden ve nereye alanlarını doldurun.')),
      );
      return;
    }

    final kullanici = FirebaseAuth.instance.currentUser;
    if (kullanici == null) return;

    setState(() => _kaydediliyor = true);
    try {
      await FirebaseFirestore.instance.collection('ilanlar').add({
        'baslik': _baslik.text.trim(),
        'kategori': _kategori.text.trim(),
        'nereden': _nereden.text.trim(),
        'nereye': _nereye.text.trim(),
        'detay': _detay.text.trim(),
        'sahip': kullanici.email,
        'zaman': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İlan Ekle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _alan(_baslik, 'Başlık'),
            _alan(_kategori, 'Kategori'),
            _alan(_nereden, 'Nereden'),
            _alan(_nereye, 'Nereye'),
            _alan(_detay, 'Detay', maxLines: 4),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _kaydediliyor ? null : _ilanEkle,
                child: _kaydediliyor
                    ? const CircularProgressIndicator()
                    : const Text('İlanı Yayınla'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alan(TextEditingController controller, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

// ============================================================
// İLANLAR
// ============================================================
class IlanlarSekmesi extends StatelessWidget {
  const IlanlarSekmesi({super.key});

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ilanlar')
            .orderBy('zaman', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Hata: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var ilanlar = snap.data!.docs;

          if (ilanlar.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt, size: 70, color: Colors.grey),
                    SizedBox(height: 15),
                    Text(
                      'Henüz ilan yok.\nSağ alttaki + butonuna bas!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ilanlar.length,
            itemBuilder: (ctx, i) {
              var d = ilanlar[i].data() as Map<String, dynamic>;
              var ilanId = ilanlar[i].id;

              bool benimMi = d['sahip'] == kimlik.aktifKullanici?.email;

              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.inventory_2, color: Colors.white),
                  ),
                  title: Text(
                    '${d['baslik'] ?? 'İlan'} (${d['kategori'] ?? '-'})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('📍 ${d['nereden'] ?? '-'} ➡️ ${d['nereye'] ?? '-'}'),
                      if ((d['detay'] ?? '').toString().isNotEmpty)
                        Text('📝 ${d['detay']}'),
                      const SizedBox(height: 4),
                      if (benimMi)
                        const Text('✅ Senin ilanın',
                            style: TextStyle(
                                fontSize: 10, color: Colors.green)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: benimMi
                      ? IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.redAccent),
                          onPressed: () async {
                            bool? onay = await showDialog<bool>(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                title: const Text('İlanı Sil?'),
                                content:
                                    const Text('Bu ilanı silmek istediğine emin misin?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Hayır'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('Sil',
                                        style:
                                            TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (onay == true) {
                              await FirebaseFirestore.instance
                                  .collection('ilanlar')
                                  .doc(ilanId)
                                  .delete();
                            }
                          },
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const IlanEkleSayfasi(),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// MESAJLAR
// ============================================================
class MesajlarSekmesi extends StatelessWidget {
  const MesajlarSekmesi({super.key});

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);
    String benimEmail =
        (kimlik.aktifKullanici?.email ?? '').toLowerCase().trim();

    if (benimEmail.isEmpty) {
      return const Center(child: Text('Giriş yapmalısınız.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mesajlar')
          .orderBy('zaman', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(child: Text('Hata: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Benim mesajlarımı filtrele
        var tumMesajlar = snap.data!.docs;

        // Her kişiyle son mesajı bul
        Map<String, Map<String, dynamic>> sohbetler = {};

        for (var doc in tumMesajlar) {
          var d = doc.data() as Map<String, dynamic>;
          String gonderen =
              (d['gonderen'] ?? '').toString().toLowerCase();
          String alici = (d['alici'] ?? '').toString().toLowerCase();

          String? diger;
          if (gonderen == benimEmail) {
            diger = alici;
          } else if (alici == benimEmail) {
            diger = gonderen;
          }

          if (diger != null && diger.isNotEmpty) {
            if (!sohbetler.containsKey(diger)) {
              sohbetler[diger] = {
                'email': diger,
                'sonMesaj': d['mesaj'] ?? '',
                'zaman': d['zaman'],
              };
            }
          }
        }

        if (sohbetler.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 70, color: Colors.grey),
                  SizedBox(height: 15),
                  Text(
                    'Henüz mesajlaşman yok.\nFirmalar sekmesinden bir firmaya yaz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        var liste = sohbetler.values.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: liste.length,
          itemBuilder: (ctx, i) {
            var s = liste[i];
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.chat, color: Colors.white),
                ),
                title: Text(s['email'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(s['sonMesaj'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SohbetSayfasi(
                        digerEmail: s['email'] ?? '',
                        digerAd: s['email'] ?? '',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
// ============================================================
// PROFİL
// ============================================================
class ProfilSekmesi extends StatefulWidget {
  const ProfilSekmesi({super.key});

  @override
  State<ProfilSekmesi> createState() => _ProfilSekmesiState();
}

class _ProfilSekmesiState extends State<ProfilSekmesi> {
  final _ad = TextEditingController();
  final _tel = TextEditingController();
  final _bio = TextEditingController();
  final _profilFoto = TextEditingController();
  final _kapakFoto = TextEditingController();

  bool yukleniyor = false;
  bool yuklendi = false;

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);
    String uid = kimlik.aktifKullanici?.uid ?? '';
    String email = kimlik.aktifKullanici?.email ?? '';

    // Verileri bir kez çek
    if (!yuklendi && uid.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('kullaniciDetaylari')
          .doc(uid)
          .get()
          .then((doc) {
        if (doc.exists && mounted) {
          var d = doc.data()!;
          setState(() {
            _ad.text = d['adSoyad'] ?? '';
            _tel.text = d['telefon'] ?? '';
            _bio.text = d['biyografi'] ?? '';
            _profilFoto.text = d['profilFoto'] ?? '';
            _kapakFoto.text = d['kapakFoto'] ?? '';
            yuklendi = true;
          });
        }
      });
    }

    // Mevcut fotoğraflar (gösterim için)
    String profilFotoUrl = _profilFoto.text.trim().isNotEmpty
        ? _profilFoto.text.trim()
        : 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png';

    String kapakFotoUrl = _kapakFoto.text.trim().isNotEmpty
        ? _kapakFoto.text.trim()
        : 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=800';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ============ KAPAK FOTOĞRAFI ============
        SizedBox(
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                'https://i.hizliresim.com/dgflmu34.png',
                height: 30,
                fit: BoxFit.contain,
                headers: const {
                  'User-Agent': 'Mozilla/5.0',
                },
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1E293B),
                  child: const Center(
                    child: Icon(Icons.image, size: 60, color: Colors.grey),
                  ),
                ),
              ),
              // Karartma (yazı okunsun diye)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ============ PROFİL FOTOĞRAFI (ÜSTTE ORTADA) ============
        Transform.translate(
          offset: const Offset(0, -50),
          child: Column(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFF0F172A),
                child: CircleAvatar(
                  radius: 56,
                  backgroundImage: NetworkImage(profilFotoUrl),
                  onBackgroundImageError: (_, __) {},
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _ad.text.isNotEmpty ? _ad.text : email,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  kimlik.kullaniciRolu == 'nakliyeci'
                      ? 'Nakliyeci'
                      : 'Müşteri',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              if (_bio.text.isNotEmpty) ...[
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    _bio.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ============ İSTATİSTİKLER (Yıldız, Takipçi vs.) ============
        Transform.translate(
          offset: const Offset(0, -30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _istatistik('⭐ 5.0', 'Puan'),
                _istatistik('0', 'Takipçi'),
                _istatistik('0', 'Takip'),
              ],
            ),
          ),
        ),

        // ============ DÜZENLE FORMU ============
        Transform.translate(
          offset: const Offset(0, -20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✏️ Profili Düzenle',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: _ad,
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad / Firma Ünvanı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tel,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bio,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Biyografi',
                    hintText: 'Kendinden kısaca bahset...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _profilFoto,
                  decoration: const InputDecoration(
                    labelText: 'Profil Foto URL',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _kapakFoto,
                  decoration: const InputDecoration(
                    labelText: 'Kapak Foto URL',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent),
                    icon: yukleniyor
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(yukleniyor ? 'Kaydediliyor...' : 'Kaydet'),
                    onPressed: yukleniyor
                        ? null
                        : () async {
                            setState(() => yukleniyor = true);
                            await FirebaseFirestore.instance
                                .collection('kullaniciDetaylari')
                                .doc(uid)
                                .set({
                              'adSoyad': _ad.text.trim(),
                              'telefon': _tel.text.trim(),
                              'biyografi': _bio.text.trim(),
                              'profilFoto': _profilFoto.text.trim(),
                              'kapakFoto': _kapakFoto.text.trim(),
                            }, SetOptions(merge: true));

                            // Nakliyeci ise nakliyeciler tablosunu da güncelle
                            String docId = email
                                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                            var nakRef = FirebaseFirestore.instance
                                .collection('nakliyeciler')
                                .doc(docId);
                            var nakSnap = await nakRef.get();
                            if (nakSnap.exists) {
                              await nakRef.update({
                                'unvan': _ad.text.trim(),
                                'telefon': _tel.text.trim(),
                                'biyografi': _bio.text.trim(),
                                'profilFoto': _profilFoto.text.trim(),
                                'kapakFoto': _kapakFoto.text.trim(),
                              });
                            }

                            if (mounted) {
                              setState(() => yukleniyor = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('✅ Profil güncellendi!')),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _istatistik(String ustYazi, String altYazi) {
    return Column(
      children: [
        Text(ustYazi,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(altYazi,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
// ============================================================
// ÜYELİK KONTROL SINIFI
// ============================================================
class UyelikKontrol {
  final Map<String, dynamic> nakliyeci;

  UyelikKontrol(this.nakliyeci);

  /// Deneme süresi bitti mi?
  bool get denemeBittiMi {
    String tip = nakliyeci['uyelikTipi'] ?? 'Normal';
    if (tip != 'Deneme') return false;

    Timestamp? bitis = nakliyeci['denemeBitis'] as Timestamp?;
    if (bitis == null) return false;

    return DateTime.now().isAfter(bitis.toDate());
  }

  /// Deneme kaç gün kaldı?
  int get kalanGun {
    Timestamp? bitis = nakliyeci['denemeBitis'] as Timestamp?;
    if (bitis == null) return 0;

    Duration fark = bitis.toDate().difference(DateTime.now());
    return fark.inDays < 0 ? 0 : fark.inDays;
  }

  /// Ödeme yapıldı mı?
  bool get odemeYapildi => nakliyeci['odemeYapildi'] ?? false;

  /// Üyelik tipi: Deneme / Plus / Pro / Normal
  String get tip => nakliyeci['uyelikTipi'] ?? 'Normal';

  /// Kullanıcı aktif mi? (Listede görünebilir mi?)
  bool get aktifMi {
    if (tip == 'Deneme') return !denemeBittiMi;
    if (tip == 'Plus') return odemeYapildi;
    if (tip == 'Pro') return odemeYapildi;
    return true;
  }

  /// Rozet rengi
  Color get rozetRengi {
    if (denemeBittiMi) return Colors.red;
    if (tip == 'Deneme') return Colors.orange;
    if (tip == 'Plus') return Colors.blue;
    if (tip == 'Pro') return Colors.amber;
    return Colors.grey;
  }

  /// Rozet metni
  String get rozetMetni {
    if (denemeBittiMi) return 'PASİF';
    if (tip == 'Deneme') return 'DENEME • $kalanGun GÜN';
    if (tip == 'Plus') return 'İŞLETME';
    if (tip == 'Pro') return 'PRO';
    return 'NORMAL';
  }
}

// ============================================================
// SOHBET
// ============================================================
class SohbetSayfasi extends StatefulWidget {
  final String digerEmail;
  final String digerAd;

  const SohbetSayfasi({
    super.key,
    required this.digerEmail,
    required this.digerAd,
  });

  @override
  State<SohbetSayfasi> createState() => _SohbetSayfasiState();
}

class _SohbetSayfasiState extends State<SohbetSayfasi> {
  final _mesaj = TextEditingController();

  @override
  void dispose() {
    _mesaj.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
  final kimlik = context.read<KimlikYoneticisi>();
  final metin = _mesaj.text.trim();
  final gonderen = kimlik.aktifKullanici?.email;
  if (metin.isEmpty || gonderen == null) return;
  
  _mesaj.clear();
  
  await FirebaseFirestore.instance.collection('mesajlar').add({
    'gonderen': gonderen.toLowerCase().trim(),
    'alici': widget.digerEmail.toLowerCase().trim(),
    'mesaj': metin,
    'zaman': FieldValue.serverTimestamp(),
  });

  // BİLDİRİM GÖNDER           ← YENİ EKLENEN KISIM BURADAN BAŞLIYOR
  try {
    await FirebaseFirestore.instance.collection('bildirimler').add({
      'hedefEmail': widget.digerEmail.toLowerCase().trim(),
      'baslik': '💬 Yeni Mesaj',
      'detay': '$gonderen: $metin',
      'tip': 'mesaj',
      'okundu': false,
      'zaman': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    debugPrint('Bildirim hatası: $e');
  }
}                             

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);
    final benimEmail =
        (kimlik.aktifKullanici?.email ?? '').toLowerCase().trim();
    final digerEmail = widget.digerEmail.toLowerCase().trim();

    return Scaffold(
      appBar: AppBar(title: Text(widget.digerAd)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('mesajlar')
                  .orderBy('zaman', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // İki taraf arasındaki mesajları filtrele
                final tumMesajlar = snapshot.data!.docs;
                final mesajlar = tumMesajlar.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final g = (d['gonderen'] ?? '').toString().toLowerCase().trim();
                  final a = (d['alici'] ?? '').toString().toLowerCase().trim();

                  return (g == benimEmail && a == digerEmail) ||
                      (g == digerEmail && a == benimEmail);
                }).toList();

                if (mesajlar.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 70, color: Colors.grey),
                          SizedBox(height: 15),
                          Text(
                            'Henüz mesaj yok.\nİlk mesajı sen yaz!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: mesajlar.length,
                  itemBuilder: (_, i) {
                    final d = mesajlar[i].data() as Map<String, dynamic>;
                    final gonderen =
                        (d['gonderen'] ?? '').toString().toLowerCase().trim();
                    final benimMi = gonderen == benimEmail;

                    return Align(
                      alignment: benimMi
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.72,
                        ),
                        decoration: BoxDecoration(
                          color: benimMi
                              ? Colors.blueAccent
                              : const Color(0xFF374151),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(benimMi ? 14 : 4),
                            bottomRight: Radius.circular(benimMi ? 4 : 14),
                          ),
                        ),
                        child: Text(
                          (d['mesaj'] ?? '').toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mesaj,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _gonder(),
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz...',
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _gonder,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================
// YORUM YAP SAYFASI
// ============================================================
class YorumYapSayfasi extends StatefulWidget {
  final String nakliyeciId;
  final String firmaAdi;
  const YorumYapSayfasi({
    super.key,
    required this.nakliyeciId,
    required this.firmaAdi,
  });

  @override
  State<YorumYapSayfasi> createState() => _YorumYapSayfasiState();
}

class _YorumYapSayfasiState extends State<YorumYapSayfasi> {
  double _puan = 5.0;
  final _yorum = TextEditingController();
  bool _gonderiliyor = false;

  Future<void> _gonder() async {
    if (_yorum.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir yorum yazın!')),
      );
      return;
    }

    setState(() => _gonderiliyor = true);

    try {
      final kimlik = Provider.of<KimlikYoneticisi>(context, listen: false);
      String yazar = kimlik.aktifKullanici?.email ?? 'Anonim';

      var ref = FirebaseFirestore.instance
          .collection('nakliyeciler')
          .doc(widget.nakliyeciId);

      var doc = await ref.get();

      if (doc.exists) {
        var data = doc.data()!;
        double mevcutPuan = (data['puan'] ?? 5.0).toDouble();
        int oySayisi = data['oySayisi'] ?? 0;

        double yeniOrtalama =
            ((mevcutPuan * oySayisi) + _puan) / (oySayisi + 1);

        await ref.update({
          'puan': double.parse(yeniOrtalama.toStringAsFixed(1)),
          'oySayisi': oySayisi + 1,
        });

        await ref.collection('yorumlar').add({
          'yorum': _yorum.text.trim(),
          'puan': _puan,
          'yazar': yazar,
          'zaman': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Yorumunuz eklendi!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.firmaAdi} - Yorum')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              '${widget.firmaAdi}\nhakkında ne düşünüyorsun?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  iconSize: 45,
                  icon: Icon(
                    i < _puan.floor()
                        ? Icons.star
                        : (i < _puan ? Icons.star_half : Icons.star_border),
                    color: Colors.amber,
                  ),
                  onPressed: () =>
                      setState(() => _puan = (i + 1).toDouble()),
                );
              }),
            ),
            const SizedBox(height: 10),
            Text(
              '⭐ $_puan / 5.0',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _yorum,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Deneyiminizi yazın',
                hintText: 'Hizmet nasıldı? Fiyat uygun muydu?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                icon: _gonderiliyor
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                    _gonderiliyor ? 'Gönderiliyor...' : 'Yorumu Gönder'),
                onPressed: _gonderiliyor ? null : _gonder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BİLDİRİMLER SEKMESİ
// ============================================================
class BildirimlerSekmesi extends StatelessWidget {
  const BildirimlerSekmesi({super.key});

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);
    String email = (kimlik.aktifKullanici?.email ?? '').toLowerCase().trim();

    if (email.isEmpty) {
      return const Center(child: Text('Giriş yapmalısınız.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bildirimler')
          .where('hedefEmail', isEqualTo: email)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 60, color: Colors.orange),
                  const SizedBox(height: 15),
                  const Text('Bildirimler yüklenemedi',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var bildirimler = snap.data!.docs.toList();

        // Yeniden eskiye sırala
        bildirimler.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;
          Timestamp? aZ = aData['zaman'] as Timestamp?;
          Timestamp? bZ = bData['zaman'] as Timestamp?;
          if (aZ == null || bZ == null) return 0;
          return bZ.compareTo(aZ);
        });

        if (bildirimler.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 70, color: Colors.grey),
                  SizedBox(height: 15),
                  Text(
                    'Henüz bildiriminiz yok.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: bildirimler.length,
          itemBuilder: (ctx, i) {
            var doc = bildirimler[i];
            var d = doc.data() as Map<String, dynamic>;

            bool okundu = d['okundu'] ?? false;
            String tip = d['tip'] ?? 'genel';

            IconData ikon = Icons.notifications;
            Color renk = Colors.blueAccent;

            if (tip == 'mesaj') {
              ikon = Icons.chat;
              renk = Colors.green;
            } else if (tip == 'ilan') {
              ikon = Icons.inventory_2;
              renk = Colors.orange;
            } else if (tip == 'yorum') {
              ikon = Icons.star;
              renk = Colors.amber;
            } else if (tip == 'sistem') {
              ikon = Icons.celebration;
              renk = Colors.purple;
            } else if (tip == 'kampanya') {
              ikon = Icons.campaign;
              renk = Colors.pink;
            }

            return Card(
              color: okundu
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF2A3A5C),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                onTap: () async {
                  if (!okundu) {
                    await FirebaseFirestore.instance
                        .collection('bildirimler')
                        .doc(doc.id)
                        .update({'okundu': true});
                  }
                },
                leading: CircleAvatar(
                  backgroundColor: renk.withOpacity(0.2),
                  child: Icon(ikon, color: renk),
                ),
                title: Text(
                  d['baslik'] ?? '',
                  style: TextStyle(
                    fontWeight:
                        okundu ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(d['detay'] ?? '',
                    style: const TextStyle(fontSize: 12)),
                trailing: okundu
                    ? null
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================
// BİLDİRİM YARDIMCISI
// ============================================================
class BildirimYardimcisi {
  /// Tek kişiye bildirim
  static Future<void> gonder({
    required String hedefEmail,
    required String baslik,
    required String detay,
    String tip = 'genel',
  }) async {
    try {
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'hedefEmail': hedefEmail.toLowerCase().trim(),
        'baslik': baslik,
        'detay': detay,
        'tip': tip,
        'okundu': false,
        'zaman': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Bildirim hatası: $e');
    }
  }

  /// Tüm nakliyecilere bildirim
  static Future<void> tumNakliyecilere({
    required String baslik,
    required String detay,
    String tip = 'kampanya',
  }) async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('nakliyeciler')
          .get();
      for (var doc in snap.docs) {
        String email =
            (doc.data()['eposta'] ?? '').toString().toLowerCase().trim();
        if (email.isNotEmpty) {
          await gonder(
            hedefEmail: email,
            baslik: baslik,
            detay: detay,
            tip: tip,
          );
        }
      }
    } catch (e) {
      debugPrint('Toplu bildirim hatası: $e');
    }
  }

  /// Tüm müşterilere bildirim
  static Future<void> tumMusterilere({
    required String baslik,
    required String detay,
    String tip = 'kampanya',
  }) async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('kullaniciDetaylari')
          .where('rol', isEqualTo: 'musteri')
          .get();
      for (var doc in snap.docs) {
        String email =
            (doc.data()['eposta'] ?? '').toString().toLowerCase().trim();
        if (email.isNotEmpty) {
          await gonder(
            hedefEmail: email,
            baslik: baslik,
            detay: detay,
            tip: tip,
          );
        }
      }
    } catch (e) {
      debugPrint('Toplu bildirim hatası: $e');
    }
  }

  /// Herkese bildirim
  static Future<void> herkese({
    required String baslik,
    required String detay,
    String tip = 'kampanya',
  }) async {
    await tumNakliyecilere(baslik: baslik, detay: detay, tip: tip);
    await tumMusterilere(baslik: baslik, detay: detay, tip: tip);
  }
}

// ============================================================
// KAMPANYA GÖNDER SAYFASI
// ============================================================
class KampanyaGonderSayfasi extends StatefulWidget {
  const KampanyaGonderSayfasi({super.key});

  @override
  State<KampanyaGonderSayfasi> createState() =>
      _KampanyaGonderSayfasiState();
}

class _KampanyaGonderSayfasiState extends State<KampanyaGonderSayfasi> {
  final _baslik = TextEditingController();
  final _detay = TextEditingController();
  String _hedef = 'herkes';
  bool _gonderiliyor = false;

  Future<void> _gonder() async {
    if (_baslik.text.trim().isEmpty || _detay.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve detay gerekli!')),
      );
      return;
    }

    setState(() => _gonderiliyor = true);

    try {
      if (_hedef == 'nakliyeci') {
        await BildirimYardimcisi.tumNakliyecilere(
          baslik: _baslik.text.trim(),
          detay: _detay.text.trim(),
        );
      } else if (_hedef == 'musteri') {
        await BildirimYardimcisi.tumMusterilere(
          baslik: _baslik.text.trim(),
          detay: _detay.text.trim(),
        );
      } else {
        await BildirimYardimcisi.herkese(
          baslik: _baslik.text.trim(),
          detay: _detay.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Kampanya gönderildi!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📢 Kampanya Gönder')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text('Başlık',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _baslik,
              decoration: const InputDecoration(
                hintText: 'Örn: 🎉 Yılbaşı İndirimi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Detay',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _detay,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Örn: Pro pakette %50 indirim! 31 Aralık\'a kadar.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Kime gönderilsin?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('Herkese'),
              value: 'herkes',
              groupValue: _hedef,
              onChanged: (v) => setState(() => _hedef = v!),
            ),
            RadioListTile<String>(
              title: const Text('Sadece Nakliyecilere'),
              value: 'nakliyeci',
              groupValue: _hedef,
              onChanged: (v) => setState(() => _hedef = v!),
            ),
            RadioListTile<String>(
              title: const Text('Sadece Müşterilere'),
              value: 'musteri',
              groupValue: _hedef,
              onChanged: (v) => setState(() => _hedef = v!),
            ),
            const SizedBox(height: 25),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                ),
                icon: _gonderiliyor
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.campaign),
                label: Text(_gonderiliyor
                    ? 'Gönderiliyor...'
                    : 'Kampanyayı Gönder'),
                onPressed: _gonderiliyor ? null : _gonder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}