import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    debugPrint("Firebase başlatma hatası: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => KimlikYoneticisi()),
        ChangeNotifierProvider(create: (context) => UygulamaVerisi()),
      ],
      child: const EENApp(),
    ),
  );
}

// ------------------------------------------------------------
// 1. KİMLİK YÖNETİCİSİ (AUTH)
// ------------------------------------------------------------
class KimlikYoneticisi extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? aktifKullanici;
  String hataMesaji = '';
  String kullaniciRolu = 'musteri';

  KimlikYoneticisi() {
    _auth.authStateChanges().listen((user) {
      aktifKullanici = user;
      notifyListeners();
    });
  }

  bool get adminMi {
    return aktifKullanici?.email == 'azatayirtir36@gmail.com';
  }

  void rolBelirle(String rol) {
    kullaniciRolu = rol;
    notifyListeners();
  }

  Future<bool> girisYap(String eposta, String sifre) async {
    try {
      hataMesaji = '';
      await _auth.signInWithEmailAndPassword(email: eposta, password: sifre);
      return true;
    } on FirebaseAuthException catch (e) {
      hataMesaji = e.message ?? 'Giris yapilamadi';
      notifyListeners();
      return false;
    }
  }

  Future<bool> kayitOl(String eposta, String sifre, Map<String, dynamic> detaylar) async {
    try {
      hataMesaji = '';
      UserCredential credential = await _auth.createUserWithEmailAndPassword(email: eposta, password: sifre);
      
      String uid = credential.user!.uid;
      await FirebaseFirestore.instance.collection('kullaniciDetaylari').doc(uid).set({
        'eposta': eposta,
        'rol': kullaniciRolu,
        ...detaylar,
        'zaman': FieldValue.serverTimestamp(),
      });

      if (kullaniciRolu == 'nakliyeci') {
        String docId = eposta.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        await FirebaseFirestore.instance.collection('nakliyeciler').doc(docId).set({
          'eposta': eposta,
          'unvan': detaylar['adSoyad'] ?? 'Nakliye Firmasi',
          'telefon': detaylar['telefon'] ?? '',
          'dogumTarihi': detaylar['dogumTarihi'] ?? '',
          'uyelikTipi': 'Normal',
          'kalanDoping': 0,
          'puan': 5.0,
          'oySayisi': 0,
          'kmFiyat': 45,
          'profilFoto': detaylar['profilFoto'] ?? 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
        });
      }

      return true;
    } on FirebaseAuthException catch (e) {
      hataMesaji = e.message ?? 'Kayit olusturulamadi';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sifreSifirla(String eposta) async {
    try {
      hataMesaji = '';
      await _auth.sendPasswordResetEmail(email: eposta);
      return true;
    } on FirebaseAuthException catch (e) {
      hataMesaji = e.message ?? 'Sifre sifirlama maili gonderilemedi';
      notifyListeners();
      return false;
    }
  }

  Future<void> cikisYap() async {
    await _auth.signOut();
  }
}

// ------------------------------------------------------------
// 2. MERKEZİ VERİ YÖNETİMİ (FIRESTORE)
// ------------------------------------------------------------
class UygulamaVerisi extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> nakliyeciler = [];
  List<Map<String, dynamic>> ilanlar = [];

  UygulamaVerisi() {
    _verileriDinle();
  }

  void _verileriDinle() {
    _firestore.collection('nakliyeciler').snapshots().listen((snapshot) {
      nakliyeciler = snapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': doc.id,
          'eposta': data['eposta']?.toString() ?? '',
          'unvan': data['unvan']?.toString() ?? '',
          'telefon': data['telefon']?.toString() ?? '',
          'dogumTarihi': data['dogumTarihi']?.toString() ?? '',
          'uyelikTipi': data['uyelikTipi'] ?? 'Normal',
          'kalanDoping': data['kalanDoping'] ?? 0,
          'puan': (data['puan'] ?? 5.0).toDouble(),
          'oySayisi': data['oySayisi'] ?? 0,
          'kmFiyat': data['kmFiyat'] ?? 40,
          'profilFoto': data['profilFoto']?.toString() ?? 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
        };
      }).toList();
      notifyListeners();
    });

    _firestore.collection('ilanlar').orderBy('zaman', descending: true).snapshots().listen((snapshot) {
      ilanlar = snapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': doc.id,
          'baslik': data['baslik'] ?? '',
          'kategori': data['kategori'] ?? '3+1',
          'nereden': data['nereden'] ?? '',
          'nereye': data['nereye'] ?? '',
          'detay': data['detay'] ?? '',
          'sahip': data['sahip'] ?? '',
        };
      }).toList();
      notifyListeners();
    });
  }

  Future<void> ilanEkle(String baslik, String kategori, String nereden, String nereye, String detay, String sahip) async {
    await _firestore.collection('ilanlar').add({
      'baslik': baslik,
      'kategori': kategori,
      'nereden': nereden,
      'nereye': nereye,
      'detay': detay,
      'sahip': sahip,
      'zaman': FieldValue.serverTimestamp(),
    });
  }

  Future<void> paketGuncelle(String eposta, String tip) async {
    String docId = eposta.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    int dopingHakki = (tip == 'Pro') ? 5 : 0;

    await _firestore.collection('nakliyeciler').doc(docId).set({
      'eposta': eposta,
      'uyelikTipi': tip,
      'kalanDoping': dopingHakki,
    }, SetOptions(merge: true));
  }

  Future<bool> dopingKullan(String eposta) async {
    String docId = eposta.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    var docRef = _firestore.collection('nakliyeciler').doc(docId);
    var snapshot = await docRef.get();

    if (snapshot.exists) {
      int mevcutDoping = snapshot.data()?['kalanDoping'] ?? 0;
      if (mevcutDoping > 0) {
        await docRef.update({'kalanDoping': mevcutDoping - 1});
        return true;
      }
    }
    return false;
  }

  Future<void> profilGuncelle(String uid, String eposta, Map<String, dynamic> yeniBilgiler) async {
    await _firestore.collection('kullaniciDetaylari').doc(uid).update(yeniBilgiler);

    String docId = eposta.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    var nakliyatRef = _firestore.collection('nakliyeciler').doc(docId);
    var nakSnap = await nakliyatRef.get();
    if (nakSnap.exists) {
      await nakliyatRef.update({
        if (yeniBilgiler.containsKey('adSoyad')) 'unvan': yeniBilgiler['adSoyad'],
        if (yeniBilgiler.containsKey('telefon')) 'telefon': yeniBilgiler['telefon'],
        if (yeniBilgiler.containsKey('dogumTarihi')) 'dogumTarihi': yeniBilgiler['dogumTarihi'],
        if (yeniBilgiler.containsKey('profilFoto')) 'profilFoto': yeniBilgiler['profilFoto'],
      });
    }
  }

  Future<void> sirketFotografiEkle(String nakliyeciDocId, String fotoUrl, String aciklama) async {
    await _firestore.collection('nakliyeciler').doc(nakliyeciDocId).collection('galeri').add({
      'fotoUrl': fotoUrl,
      'aciklama': aciklama,
      'zaman': FieldValue.serverTimestamp(),
    });
  }

  Future<void> nakliyeciHesabiniKapat(String nakliyeciDocId) async {
    await _firestore.collection('nakliyeciler').doc(nakliyeciDocId).delete();
  }

  Future<void> yorumVePuanEkle(String nakliyeciDocId, double yeniPuan, String yorum, String yazar) async {
    var ref = _firestore.collection('nakliyeciler').doc(nakliyeciDocId);
    var doc = await ref.get();
    if (doc.exists) {
      var data = doc.data()!;
      double mevcutPuan = (data['puan'] ?? 5.0).toDouble();
      int oySayisi = data['oySayisi'] ?? 0;

      double yeniOrtalamaPuan = ((mevcutPuan * oySayisi) + yeniPuan) / (oySayisi + 1);

      await ref.update({
        'puan': double.parse(yeniOrtalamaPuan.toStringAsFixed(1)),
        'oySayisi': oySayisi + 1,
      });

      await ref.collection('yorumlar').add({
        'yorum': yorum,
        'puan': yeniPuan,
        'yazar': yazar,
        'zaman': FieldValue.serverTimestamp(),
      });
    }
  }
}

// ------------------------------------------------------------
// 3. UYGULAMA İSKELETİ & YENİ LOGO WIDGET
// ------------------------------------------------------------
class EENAppLogoWidget extends StatelessWidget {
  final double height;
  const EENAppLogoWidget({super.key, this.height = 50});

  @override
  Widget build(BuildContext context) {
    // Hızlı Resim üzerinden aldığın ham bağlantı
    return Image.network(
      'https://i.hizliresim.com/fkqgitum.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF0F2C59),
                shape: BoxShape.circle,
              ),
              child: const Text('K', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            const SizedBox(width: 8),
            const Text('EENApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        );
      },
    );
  }
}

class EENApp extends StatelessWidget {
  const EENApp({super.key});

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EENApp Nakliye Pazaryeri',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: kimlik.aktifKullanici == null ? const RolSecimEkrani() : const AnaSekran(),
    );
  }
}

// ------------------------------------------------------------
// 4. GİRİŞ TİPİ SEÇİMİ VE GİRİŞ / KAYIT EKRANI
// ------------------------------------------------------------
class RolSecimEkrani extends StatelessWidget {
  const RolSecimEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context, listen: false);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EENAppLogoWidget(height: 75),
              const SizedBox(height: 25),
              const Text(
                "EENApp'a Hoş Geldiniz",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                'Nasıl devam etmek istersiniz?',
                style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  icon: const Icon(Icons.person, color: Colors.white),
                  label: const Text('Müşteri Girişi / Kaydı', style: TextStyle(fontSize: 16, color: Colors.white)),
                  onPressed: () {
                    kimlik.rolBelirle('musteri');
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const KimlikEkrani()));
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  icon: const Icon(Icons.business, color: Colors.black),
                  label: const Text('Nakliyeci Girişi / Kaydı', style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    kimlik.rolBelirle('nakliyeci');
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const KimlikEkrani()));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KimlikEkrani extends StatefulWidget {
  const KimlikEkrani({super.key});

  @override
  State<KimlikEkrani> createState() => _KimlikEkraniState();
}

class _KimlikEkraniState extends State<KimlikEkrani> {
  final TextEditingController _epostaController = TextEditingController();
  final TextEditingController _sifreController = TextEditingController();
  
  final TextEditingController _adSoyadController = TextEditingController();
  final TextEditingController _telefonController = TextEditingController();
  final TextEditingController _dogumTarihiController = TextEditingController();
  final TextEditingController _profilFotoController = TextEditingController();

  bool kayitModu = false;
  bool yukleniyor = false;

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);
    String rolBaslik = kimlik.kullaniciRolu == 'musteri' ? 'Müşteri' : 'Nakliyeci';

    return Scaffold(
      appBar: AppBar(title: Text('$rolBaslik ${kayitModu ? 'Kayıt Ol' : 'Giriş Yap'}'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (kayitModu) ...[
                  const Text('Sizi Yakından Tanıyalım', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _adSoyadController,
                    decoration: const InputDecoration(labelText: 'Ad Soyad / Firma Ünvanı', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _telefonController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefon Numarası', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _dogumTarihiController,
                    decoration: const InputDecoration(labelText: 'Doğum Tarihi (GG.AA.YYYY)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _profilFotoController,
                    decoration: const InputDecoration(labelText: 'Profil Fotoğrafı URL Linki (İsteğe Bağlı)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                ],
                TextField(
                  controller: _epostaController,
                  decoration: const InputDecoration(labelText: 'E-posta Adresi', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _sifreController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                if (!kayitModu)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SifreUnuttumSayfasi()),
                        );
                      },
                      child: const Text('Şifremi Unuttum?', style: TextStyle(color: Colors.blueAccent)),
                    ),
                  ),
                const SizedBox(height: 10),
                if (kimlik.hataMesaji.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Text(kimlik.hataMesaji, style: const TextStyle(color: Colors.redAccent)),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: yukleniyor ? null : () async {
                      setState(() => yukleniyor = true);
                      bool sonuc;
                      if (kayitModu) {
                        sonuc = await kimlik.kayitOl(
                          _epostaController.text.trim(),
                          _sifreController.text.trim(),
                          {
                            'adSoyad': _adSoyadController.text.trim(),
                            'telefon': _telefonController.text.trim(),
                            'dogumTarihi': _dogumTarihiController.text.trim(),
                            'profilFoto': _profilFotoController.text.trim().isNotEmpty 
                                ? _profilFotoController.text.trim() 
                                : 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
                          },
                        );
                      } else {
                        sonuc = await kimlik.girisYap(_epostaController.text.trim(), _sifreController.text.trim());
                      }
                      setState(() => yukleniyor = false);
                      if (sonuc && mounted) {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }
                    },
                    child: yukleniyor 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(kayitModu ? 'Kayıt Ol' : 'Giriş Yap', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => kayitModu = !kayitModu),
                  child: Text(kayitModu ? 'Zaten hesabın var mı? Giriş yap' : 'Hesabın yok mu? Kayıt ol'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SifreUnuttumSayfasi extends StatefulWidget {
  const SifreUnuttumSayfasi({super.key});

  @override
  State<SifreUnuttumSayfasi> createState() => _SifreUnuttumSayfasiState();
}

class _SifreUnuttumSayfasiState extends State<SifreUnuttumSayfasi> {
  final TextEditingController _epostaController = TextEditingController();
  bool gonderiliyor = false;

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Şifremi Sıfırla')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              'Hesabınıza kayıtlı e-posta adresinizi girin, Firebase üzerinden şifre sıfırlama bağlantısı gönderelim.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _epostaController,
              decoration: const InputDecoration(labelText: 'E-posta Adresi', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: gonderiliyor ? null : () async {
                  if (_epostaController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen e-posta adresinizi girin!')));
                    return;
                  }
                  setState(() => gonderiliyor = true);
                  bool basarili = await kimlik.sifreSifirla(_epostaController.text.trim());
                  setState(() => gonderiliyor = false);

                  if (basarili && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Şifre sıfırlama maili gönderildi! E-postanızı kontrol edin.')),
                    );
                    Navigator.pop(context);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(kimlik.hataMesaji.isNotEmpty ? kimlik.hataMesaji : 'Bir hata oluştu!')),
                    );
                  }
                },
                child: gonderiliyor
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Şifre Sıfırlama Maili Gönder', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 5. ANA EKRAN (SEKMELİ YAPI VE BİLDİRİMLER)
// ------------------------------------------------------------
class AnaSekran extends StatefulWidget {
  const AnaSekran({super.key});

  @override
  State<AnaSekran> createState() => _AnaSekranState();
}

class _AnaSekranState extends State<AnaSekran> {
  int _secilenIndex = 0;

  final List<Widget> _sayfalar = [
    const FirmalarListesiSekmesi(),
    const IlanlarSekmesi(),
    const SohbetlerListesiSekmesi(),
    const BildirimlerSekmesi(),
    const AbonelikSekmesi(),
    const ProfilSekmesi(),
  ];

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);

    String baslikMetni = 'EENApp';
    if (kimlik.adminMi) {
      baslikMetni = '👑 Admin Paneli';
    } else {
      switch (_secilenIndex) {
        case 0: baslikMetni = 'Nakliye Firmaları'; break;
        case 1: baslikMetni = 'Müşteri İlanları'; break;
        case 2: baslikMetni = 'Mesajlarım'; break;
        case 3: baslikMetni = 'Bildirimler'; break;
        case 4: baslikMetni = 'Paketler'; break;
        case 5: baslikMetni = 'Profilim'; break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const EENAppLogoWidget(height: 28),
            const SizedBox(width: 10),
            Text(baslikMetni, style: const TextStyle(fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => kimlik.cikisYap(),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: _sayfalar[_secilenIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _secilenIndex,
        onTap: (index) => setState(() => _secilenIndex = index),
        selectedItemColor: kimlik.adminMi ? Colors.amber : Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Firmalar'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'İlanlar'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Mesajlar'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Bildirim'),
          BottomNavigationBarItem(icon: Icon(Icons.star, color: Colors.amber), label: 'Paketler'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class FirmalarListesiSekmesi extends StatelessWidget {
  const FirmalarListesiSekmesi({super.key});

  @override
  Widget build(BuildContext context) {
    final uygulamaVerisi = Provider.of<UygulamaVerisi>(context);
    final kimlik = Provider.of<KimlikYoneticisi>(context);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: uygulamaVerisi.nakliyeciler.isEmpty
          ? const Center(child: Text('Henüz sistemde kayıtlı nakliyeci firma bulunmuyor.'))
          : ListView.builder(
              itemCount: uygulamaVerisi.nakliyeciler.length,
              itemBuilder: (context, index) {
                var nakliyeci = uygulamaVerisi.nakliyeciler[index];
                String tip = nakliyeci['uyelikTipi'];

                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(backgroundImage: NetworkImage(nakliyeci['profilFoto'])),
                    title: Text(nakliyeci['unvan'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Tel: ${nakliyeci['telefon']} | ⭐ ${nakliyeci['puan']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tip == 'Pro')
                          const Chip(label: Text('PRO', style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Colors.amber)
                        else if (tip == 'Is Hesabi')
                          const Chip(label: Text('İŞ', style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Colors.blue),
                        
                        if (kimlik.adminMi) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                            tooltip: 'Hesabı Kapat / Sil',
                            onPressed: () async {
                              bool? onay = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Hesabı Kapat'),
                                  content: Text('${nakliyeci['unvan']} adlı nakliyeci hesabını silmek istediğinize emin misiniz?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet, Sil', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );

                              if (onay == true) {
                                await uygulamaVerisi.nakliyeciHesabiniKapat(nakliyeci['id']);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('🗑️ Nakliyeci hesabı kapatıldı/silindi.')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NakliyeciDetaySayfasi(nakliyeci: nakliyeci)),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class IlanlarSekmesi extends StatelessWidget {
  const IlanlarSekmesi({super.key});

  @override
  Widget build(BuildContext context) {
    final uygulamaVerisi = Provider.of<UygulamaVerisi>(context);

    return Scaffold(
      body: uygulamaVerisi.ilanlar.isEmpty
          ? const Center(child: Text('Henüz ilan eklenmemiş. Sağ alttan ekleyebilirsin!'))
          : ListView.builder(
              itemCount: uygulamaVerisi.ilanlar.length,
              itemBuilder: (context, index) {
                var ilan = uygulamaVerisi.ilanlar[index];
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text("${ilan['baslik']} (${ilan['kategori']})", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('📍 ${ilan['nereden']} ➡️ ${ilan['nereye']}\nDetay: ${ilan['detay']}'),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const IlanEkleSayfasi()),
          );
        },
      ),
    );
  }
}

class SohbetlerListesiSekmesi extends StatelessWidget {
  const SohbetlerListesiSekmesi({super.key});

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);
    String aktifKullaniciAdi = kimlik.aktifKullanici?.email ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sohbetler').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var tumSohbetler = snapshot.data!.docs;
        var benimSohbetlerim = tumSohbetler.where((doc) {
          return doc.id.contains(aktifKullaniciAdi.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_'));
        }).toList();

        if (benimSohbetlerim.isEmpty) {
          return const Center(
            child: Text('Henüz aktif bir mesajlaşmanız bulunmuyor.\nFirmalar sayfasından sohbet başlatabilirsiniz.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          itemCount: benimSohbetlerim.length,
          itemBuilder: (context, index) {
            var sohbetDoc = benimSohbetlerim[index];
            String sohbetId = sohbetDoc.id;
            
            String digerTaraf = sohbetId.replaceAll(aktifKullaniciAdi.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_'), '').replaceAll('_', ' ').trim();

            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.chat, color: Colors.white)),
                title: Text(digerTaraf.isNotEmpty ? digerTaraf : 'Sohbet', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Mesajları görüntülemek için tıklayın', style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SohbetSayfasi(
                        firmaAdi: digerTaraf,
                        kullaniciAdi: aktifKullaniciAdi,
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

class BildirimlerSekmesi extends StatelessWidget {
  const BildirimlerSekmesi({super.key});

  final List<Map<String, dynamic>> bildirimListesi = const [
    {
      'baslik': 'EENApp Sistemine Hoş Geldiniz',
      'detay': 'Nakliye pazaryeri uygulamamız güncellendi. Yeni ilanları inceleyebilirsiniz.',
      'zaman': 'Bugün',
      'okundu': false,
      'ikon': Icons.celebration,
    },
    {
      'baslik': 'Kampanya Duyurusu',
      'detay': 'Pro üyelik paketlerinde bu aya özel avantajları kaçırmayın!',
      'zaman': 'Dün',
      'okundu': true,
      'ikon': Icons.star,
    },
    {
      'baslik': 'Güvenlik Bilgilendirmesi',
      'detay': 'Şifrenizi kimseyle paylaşmayınız.',
      'zaman': '3 gün önce',
      'okundu': true,
      'ikon': Icons.security,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: bildirimListesi.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        var bildirim = bildirimListesi[index];
        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              child: Icon(bildirim['ikon'], color: Colors.blueAccent),
            ),
            title: Text(
              bildirim['baslik'], 
              style: TextStyle(
                fontWeight: bildirim['okundu'] ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(bildirim['detay'], style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(bildirim['zaman'], style: const TextStyle(fontSize: 10, color: Colors.cyanAccent)),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class AbonelikSekmesi extends StatelessWidget {
  const AbonelikSekmesi({super.key});

  void _odemeSayfasinaGit(BuildContext context, String paketAdi, int tutar) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OdemeSayfasi(paketAdi: paketAdi, tutar: tutar)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);
    final veri = Provider.of<UygulamaVerisi>(context);
    
    String eposta = kimlik.aktifKullanici?.email ?? '';
    bool nakliyeciMi = false;
    Map<String, dynamic> mevcutNakliyeci = {'uyelikTipi': 'Normal', 'kalanDoping': 0};

    if (!kimlik.adminMi) {
      try {
        mevcutNakliyeci = veri.nakliyeciler.firstWhere(
          (n) => n['eposta'] == eposta,
        );
        nakliyeciMi = true;
      } catch (e) {
        nakliyeciMi = false;
      }
    }

    if (!kimlik.adminMi && !nakliyeciMi) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 70, color: Colors.blueAccent),
              SizedBox(height: 20),
              Text(
                'Bu Sayfa Yalnızca Nakliyeci Firmalara Özeldir',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Müşteri hesaplarında paket ve doping işlemleri yer almaz. İlan verebilir ve nakliyeci firmalarla sohbet edebilirsiniz.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    String tip = mevcutNakliyeci['uyelikTipi'] ?? 'Normal';
    int kalanDoping = mevcutNakliyeci['kalanDoping'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView(
        children: [
          const Icon(Icons.verified, size: 70, color: Colors.amber),
          const SizedBox(height: 10),
          Text(
            kimlik.adminMi ? 'Admin Hesabı: Tam Yetki' : 'Mevcut Paketiniz: $tip',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            'Kalan Ücretsiz Doping Hakkı: $kalanDoping adet',
            style: const TextStyle(fontSize: 16, color: Colors.cyanAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('İş Hesabı (Aylık ₺250)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('Temel firma listeleme ve müşteri taleplerine erişim.'),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: () => _odemeSayfasinaGit(context, 'Is Hesabi', 250),
                    child: const Text('₺250 Öde ve İş Hesabına Geç'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),

          Card(
            color: const Color(0xFF2A281E),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⭐ Pro Üyelik (Aylık ₺1000)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
                  const SizedBox(height: 5),
                  const Text('Ayda 5 Ücretsiz Doping Hakkı + En Üstte Listelenme!'),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    onPressed: () => _odemeSayfasinaGit(context, 'Pro', 1000),
                    child: const Text('₺1000 Öde ve Pro Üye Ol', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (kalanDoping > 0)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(vertical: 12)),
              icon: const Icon(Icons.flash_on),
              label: Text('Ücretsiz Doping Kullan (Kalan: $kalanDoping)'),
              onPressed: () async {
                bool basarili = await veri.dopingKullan(eposta);
                if (basarili) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚀 Doping uygulandı! İlanınız öne çıkarıldı.')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doping hakkınız kalmadı!')));
                }
              },
            ),
        ],
      ),
    );
  }
}

class ProfilSekmesi extends StatefulWidget {
  const ProfilSekmesi({super.key});

  @override
  State<ProfilSekmesi> createState() => _ProfilSekmesiState();
}

class _ProfilSekmesiState extends State<ProfilSekmesi> {
  final TextEditingController _adSoyadController = TextEditingController();
  final TextEditingController _telefonController = TextEditingController();
  final TextEditingController _dogumTarihiController = TextEditingController();
  final TextEditingController _profilFotoController = TextEditingController();
  
  final TextEditingController _sirketFotoUrlController = TextEditingController();
  final TextEditingController _sirketAciklamaController = TextEditingController();

  bool yukleniyor = false;
  bool veriYuklendi = false;

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);
    final veri = Provider.of<UygulamaVerisi>(context, listen: false);
    String uid = kimlik.aktifKullanici?.uid ?? '';
    String eposta = kimlik.aktifKullanici?.email ?? '';

    if (!veriYuklendi && uid.isNotEmpty) {
      FirebaseFirestore.instance.collection('kullaniciDetaylari').doc(uid).get().then((doc) {
        if (doc.exists) {
          var data = doc.data()!;
          setState(() {
            _adSoyadController.text = data['adSoyad'] ?? '';
            _telefonController.text = data['telefon'] ?? '';
            _dogumTarihiController.text = data['dogumTarihi'] ?? '';
            _profilFotoController.text = data['profilFoto'] ?? '';
            veriYuklendi = true;
          });
        }
      });
    }

    bool nakliyeciHesabiMi = kimlik.kullaniciRolu == 'nakliyeci';
    String nakliyeciDocId = eposta.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView(
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(
                _profilFotoController.text.trim().isNotEmpty 
                    ? _profilFotoController.text.trim() 
                    : 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('E-posta: $eposta', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          TextField(
            controller: _adSoyadController,
            decoration: const InputDecoration(labelText: 'Ad Soyad / Firma Ünvanı', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _telefonController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon Numarası', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _dogumTarihiController,
            decoration: const InputDecoration(labelText: 'Doğum Tarihi (GG.AA.YYYY)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _profilFotoController,
            onChanged: (val) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Profil Fotoğrafı URL Linki', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: yukleniyor ? null : () async {
                setState(() => yukleniyor = true);
                await veri.profilGuncelle(uid, eposta, {
                  'adSoyad': _adSoyadController.text.trim(),
                  'telefon': _telefonController.text.trim(),
                  'dogumTarihi': _dogumTarihiController.text.trim(),
                  'profilFoto': _profilFotoController.text.trim().isNotEmpty 
                      ? _profilFotoController.text.trim() 
                      : 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
                });
                setState(() => yukleniyor = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Profil başarıyla güncellendi!')));
                }
              },
              child: yukleniyor 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Bilgileri Güncelle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),

          if (nakliyeciHesabiMi) ...[
            const SizedBox(height: 30),
            const Divider(color: Colors.grey),
            const SizedBox(height: 10),
            const Text('📷 Şirket / Galeri Fotoğrafı Paylaş', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 5),
            const Text('Araçlarınızdan veya taşıma işlerinizden fotoğraflar ekleyerek müşterilere gösterin.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: _sirketFotoUrlController,
              decoration: const InputDecoration(labelText: 'Fotoğraf URL Linki', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sirketAciklamaController,
              decoration: const InputDecoration(labelText: 'Fotoğraf Açıklaması (Örn: 10 Tonluk Kapalı Kasa Nakliye Aracı)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 45,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Şirket Fotoğrafını Yayınla', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  if (_sirketFotoUrlController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir fotoğraf URL adresi girin!')));
                    return;
                  }
                  await veri.sirketFotografiEkle(
                    nakliyeciDocId,
                    _sirketFotoUrlController.text.trim(),
                    _sirketAciklamaController.text.trim(),
                  );
                  _sirketFotoUrlController.clear();
                  _sirketAciklamaController.clear();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Şirket fotoğrafınız galeriye eklendi!')));
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OdemeSayfasi extends StatefulWidget {
  final String paketAdi;
  final int tutar;
  const OdemeSayfasi({super.key, required this.paketAdi, required this.tutar});

  @override
  State<OdemeSayfasi> createState() => _OdemeSayfasiState();
}

class _OdemeSayfasiState extends State<OdemeSayfasi> {
  final _kartSahibiController = TextEditingController();
  final _kartNumarasiController = TextEditingController();
  final _sktController = TextEditingController();
  final _cvvController = TextEditingController();
  bool isleniyor = false;

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context, listen: false);
    final veri = Provider.of<UygulamaVerisi>(context, listen: false);
    String eposta = kimlik.aktifKullanici?.email ?? 'nakliyeci@app.com';

    return Scaffold(
      appBar: AppBar(title: Text('${widget.paketAdi} - Güvenli Ödeme (₺${widget.tutar})')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Icon(Icons.credit_card, size: 70, color: Colors.blueAccent),
            const SizedBox(height: 15),
            Text('${widget.paketAdi} paketini aktif etmek için kart bilgilerinizi girmeniz zorunludur.', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            TextField(
              controller: _kartSahibiController,
              decoration: const InputDecoration(labelText: 'Kart Üzerindeki İsim', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _kartNumarasiController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kart Numarası (16 Hane)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sktController,
                    decoration: const InputDecoration(labelText: 'SKT (AA/YY)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'CVV', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: isleniyor ? null : () async {
                  if (_kartSahibiController.text.isEmpty || _kartNumarasiController.text.length < 16) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen geçerli kart bilgileri giriniz!')));
                    return;
                  }
                  setState(() => isleniyor = true);
                  await Future.delayed(const Duration(seconds: 1));
                  await veri.paketGuncelle(eposta, widget.paketAdi);
                  setState(() => isleniyor = false);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Ödeme başarılı! ${widget.paketAdi} aktif edildi.')));
                    Navigator.pop(context);
                  }
                },
                child: isleniyor 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('₺${widget.tutar} Ödemeyi Tamamla', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NakliyeciDetaySayfasi extends StatelessWidget {
  final Map<String, dynamic> nakliyeci;
  const NakliyeciDetaySayfasi({super.key, required this.nakliyeci});

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);

    return Scaffold(
      appBar: AppBar(title: Text(nakliyeci['unvan'])),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(nakliyeci['profilFoto']),
              ),
            ),
            const SizedBox(height: 20),
            Text('Unvan: ${nakliyeci['unvan']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Telefon: ${nakliyeci['telefon']}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text('Üyelik Tipi: ${nakliyeci['uyelikTipi']}', style: const TextStyle(fontSize: 16, color: Colors.amber)),
            const SizedBox(height: 10),
            Text('Kilometre Fiyatı: ₺${nakliyeci['kmFiyat']}', style: const TextStyle(fontSize: 16, color: Colors.cyanAccent)),
            const SizedBox(height: 10),
            Text('Puan: ⭐ ${nakliyeci['puan']} (${nakliyeci['oySayisi']} Değerlendirme)', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.star),
                label: const Text('Yıldız Ver ve Yorum Yap', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YorumYapSayfasi(nakliyeciId: nakliyeci['id'], firmaAdi: nakliyeci['unvan']),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                icon: const Icon(Icons.chat),
                label: const Text('Firma ile Canlı Sohbet Et', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SohbetSayfasi(
                        firmaAdi: nakliyeci['unvan'],
                        kullaniciAdi: kimlik.aktifKullanici?.email ?? 'Musteri',
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 25),

            const Text('📸 Şirket / Araç Galerisi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
            const Divider(),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('nakliyeciler')
                  .doc(nakliyeci['id'])
                  .collection('galeri')
                  .orderBy('zaman', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var fotolar = snapshot.data!.docs;

                if (fotolar.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Firma henüz galeriye fotoğraf eklememiş.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: fotolar.length,
                    itemBuilder: (context, index) {
                      var fData = fotolar[index].data() as Map<String, dynamic>;
                      return Container(
                        width: 180,
                        margin: const EdgeInsets.only(right: 10),
                        child: Card(
                          color: const Color(0xFF1E293B),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Image.network(
                                  fData['fotoUrl'] ?? '',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Text(
                                  fData['aciklama'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 25),
            const Text('Firma Yorumları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('nakliyeciler')
                  .doc(nakliyeci['id'])
                  .collection('yorumlar')
                  .orderBy('zaman', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var yorumlar = snapshot.data!.docs;

                if (yorumlar.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Henüz yorum yapılmamış.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: yorumlar.length,
                  itemBuilder: (context, index) {
                    var yData = yorumlar[index].data() as Map<String, dynamic>;
                    return Card(
                      color: const Color(0xFF1E293B),
                      child: ListTile(
                        title: Text(yData['yazar'] ?? 'Anonim', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(yData['yorum'] ?? ''),
                        trailing: Text('⭐ ${yData['puan']}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class YorumYapSayfasi extends StatefulWidget {
  final String nakliyeciId;
  final String firmaAdi;
  const YorumYapSayfasi({super.key, required this.nakliyeciId, required this.firmaAdi});

  @override
  State<YorumYapSayfasi> createState() => _YorumYapSayfasiState();
}

class _YorumYapSayfasiState extends State<YorumYapSayfasi> {
  double secilenPuan = 5.0;
  final TextEditingController _yorumController = TextEditingController();
  bool gonderiliyor = false;

  @override
  Widget build(BuildContext context) {
    final veri = Provider.of<UygulamaVerisi>(context, listen: false);
    final kimlik = Provider.of<KimlikYoneticisi>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.firmaAdi} - Yorum & Puan')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Firmaya Puanınız:', style: TextStyle(fontSize: 16)),
            Slider(
              value: secilenPuan,
              min: 1.0,
              max: 5.0,
              divisions: 4,
              label: secilenPuan.toString(),
              activeColor: Colors.amber,
              onChanged: (val) => setState(() => secilenPuan = val),
            ),
            Text('⭐ $secilenPuan Yıldız', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 20),
            TextField(
              controller: _yorumController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Deneyiminizi buraya yazın...', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: gonderiliyor ? null : () async {
                  if (_yorumController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir yorum yazın!')));
                    return;
                  }
                  setState(() => gonderiliyor = true);
                  await veri.yorumVePuanEkle(
                    widget.nakliyeciId,
                    secilenPuan,
                    _yorumController.text.trim(),
                    kimlik.aktifKullanici?.email ?? 'Musteri',
                  );
                  setState(() => gonderiliyor = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Yorumunuz başarıyla eklendi!')));
                    Navigator.pop(context);
                  }
                },
                child: gonderiliyor 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Yorumu Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IlanEkleSayfasi extends StatefulWidget {
  const IlanEkleSayfasi({super.key});

  @override
  State<IlanEkleSayfasi> createState() => _IlanEkleSayfasiState();
}

class _IlanEkleSayfasiState extends State<IlanEkleSayfasi> {
  final _baslikController = TextEditingController();
  final _neredenController = TextEditingController();
  final _nereyeController = TextEditingController();
  final _detayController = TextEditingController();
  
  String _secilenKategori = '3+1';
  final List<String> _kategoriler = ['1+1', '2+1', '3+1', '4+1 veya üstü', 'Ofis / Parsel Yük'];

  @override
  Widget build(BuildContext context) {
    final kimlik = Provider.of<KimlikYoneticisi>(context);
    final veri = Provider.of<UygulamaVerisi>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni İlan / Yük Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(controller: _baslikController, decoration: const InputDecoration(labelText: 'İlan Başlığı (Örn: Komple Ev Eşyası)')),
            const SizedBox(height: 16),
            const Text('Ev / Yük Kategorisi Seçin:', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              value: _secilenKategori,
              dropdownColor: const Color(0xFF1E293B),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _kategoriler.map((kat) {
                return DropdownMenuItem(value: kat, child: Text(kat));
              }).toList(),
              onChanged: (yeniDeger) {
                setState(() {
                  _secilenKategori = yeniDeger!;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: _neredenController, decoration: const InputDecoration(labelText: 'Nereden (İl / İlçe)')),
            const SizedBox(height: 12),
            TextField(controller: _nereyeController, decoration: const InputDecoration(labelText: 'Nereye (İl / İlçe)')),
            const SizedBox(height: 12),
            TextField(controller: _detayController, decoration: const InputDecoration(labelText: 'Ek Detaylar (Kat, Asansör durumu vb.)')),
            const SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: () async {
                if (_baslikController.text.isNotEmpty) {
                  await veri.ilanEkle(
                    _baslikController.text,
                    _secilenKategori,
                    _neredenController.text,
                    _nereyeController.text,
                    _detayController.text,
                    kimlik.aktifKullanici?.email ?? 'Bilinmeyen',
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('İlanı Yayınla', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class SohbetSayfasi extends StatefulWidget {
  final String firmaAdi;
  final String kullaniciAdi;
  const SohbetSayfasi({super.key, required this.firmaAdi, required this.kullaniciAdi});

  @override
  State<SohbetSayfasi> createState() => _SohbetSayfasiState();
}

class _SohbetSayfasiState extends State<SohbetSayfasi> {
  final TextEditingController _mesajController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    String sohbetId = "${widget.kullaniciAdi}_${widget.firmaAdi}".replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    return Scaffold(
      appBar: AppBar(title: Text('${widget.firmaAdi} ile Sohbet')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sohbetler')
                  .doc(sohbetId)
                  .collection('mesajlar')
                  .orderBy('zaman', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var mesajlar = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: mesajlar.length,
                  itemBuilder: (context, index) {
                    var data = mesajlar[index].data() as Map<String, dynamic>;
                    bool bendenMi = data['gonderen'] == widget.kullaniciAdi;

                    return Align(
                      alignment: bendenMi ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bendenMi ? Colors.blueAccent : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(data['mesaj'] ?? ''),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mesajController,
                    decoration: const InputDecoration(hintText: 'Mesajınızı yazın...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: () async {
                    if (_mesajController.text.trim().isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('sohbetler')
                          .doc(sohbetId)
                          .collection('mesajlar')
                          .add({
                        'gonderen': widget.kullaniciAdi,
                        'mesaj': _mesajController.text.trim(),
                        'zaman': FieldValue.serverTimestamp(),
                      });
                      _mesajController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}