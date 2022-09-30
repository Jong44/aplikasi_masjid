import 'dart:async';
import 'dart:convert';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'commons.dart';
import 'info_state_model.dart';
import 'jadwal_model.dart';

void main() {
  // Wakelock.enable();
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        },
        child: MaterialApp(
            title: 'Flutter Android TV',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            debugShowCheckedModeBanner: false,
            home: const MyHomePage()));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key,}) : super(key: key);


  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>  with TickerProviderStateMixin{
  String? _timeString;
  String? _mDateString;
  String? _hDateString;
  String? jadwal;
  var hijriyah = HijriCalendar.now();
  final GlobalKey _listKey = GlobalKey();
  var adzan = Jadwal();
  final fDatabase = FirebaseDatabase.instance;
  var state = InfoStateModel(
    namaMasjid: 'Masjid Al Aqsho',
    alamat: 'Banguntapan, Yogyakarta',
    phone: '081234567890',
    idKota: '1104',
  );
  bool showTime = false;
  bool iqomah = false;
  Timer? iqomahCountDown;
  Timer? adzCountDown;
  String? adzanNow;
  String? titleAdzanNow;
  String? titleAdzanNowMini;
  Duration endCountDown = const Duration(minutes: 10);
  Duration adzanCountDown = const Duration(minutes: 10);

  @override
  void initState(){
    super.initState();
    initializeDateFormatting('id_ID');
    init();
    _timeString = _formatDateTime(DateTime.now());
    _mDateString = _formatMDate(DateTime.now());
    _hDateString = _formatHDate(hijriyah);
    getData();
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
  }


  void init()async{
    await Firebase.initializeApp();
  }

  Future<void> getData()async{
    await Future.wait([
      setCityId(),
      getJadwalAdzan(),
      if (jadwal != null)getJadwal( ),
    ]);
  }

  Future<void> setCityId() async {
    var pref = await SharedPreferences.getInstance();
    var city = await fDatabase.reference().child('setting').child('cityId').once();
    await pref.setString('cityId', city.value);
  }

  Future<void> getJadwalAdzan() async {
    var pref = await SharedPreferences.getInstance();
    var city = await fDatabase.reference().child('setting').child('cityId').once();
    print('https://api.myquran.com/v1/sholat/jadwal/${city.value ?? '1104'}/${DateTime.now().year}/${DateTime.now().month}');
    var url = Uri.parse('https://api.myquran.com/v1/sholat/jadwal/${city.value ?? '1104'}/${DateTime.now().year}/${DateTime.now().month}');
    var response = await http.get(url,);
    if (response.statusCode == 200){
      print(response.body);
      await pref.setString('jadwal', jsonEncode(jsonDecode(response.body)['data']));
      getJadwal();
    }else{
      throw Exception('Failed to load movie');
    }
  }

  Future<void> getJadwal()async{
    var pref = await SharedPreferences.getInstance();
    jadwal = pref.getString('jadwal');
    JadwalModel time = JadwalModel.fromJson(jsonDecode(jadwal!));
    var data = time.jadwal?.where((element) => element.date! == DateFormat('yyyy-MM-dd').format(DateTime.now())).toList();
    setState(() {
      adzan = data![0];
    });
  }

  void _getTime()async {
    var pref = await SharedPreferences.getInstance();
    final DateTime now = DateTime.now();
    final String formattedDateTime = _formatDateTime(now);
    final String formattedMDate = _formatMDate(now);
    final String formattedHDate = _formatHDate(hijriyah);
    int lastday = DateTime(now.year, now.month + 1, 0).day;
    String? cityId = pref.getString('cityId');
    var city = await fDatabase.reference().child('setting').child('cityId').once();
    if (city.value != cityId){
      getJadwalAdzan();
      setCityId();
    }
    if (DateFormat('HH:mm').format(now) == '23:59:59'){
      getJadwal();
    }
    if (now.day == lastday){
      getJadwalAdzan();
    }
    adzanTime();
    changeTitle();
    setState(() {
      _timeString = formattedDateTime;
      _mDateString = formattedMDate;
      _hDateString = formattedHDate;
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatMDate(DateTime dateTime) {
    return DateFormat('EEEE,\ndd MMM yyyy','id_ID').format(dateTime);
  }

  String _formatHDate(HijriCalendar dateTime) {
    return dateTime.toFormat('dd MMMM\nyyyy H');
  }

  List<String> lists = [];
  List<String> information = [];


  void startIqomah(){
    setState(() {
      iqomah = true;
      endCountDown = const Duration(minutes: 10);
    });
    Future.delayed(const Duration(seconds: 1)).then((value) {
      iqomahCountDown = Timer.periodic(const Duration(seconds: 1), (timer)async {
        setState(() {
          endCountDown -= const Duration(seconds: 1);
        });
        if (endCountDown.inMinutes % 60 == 0 && endCountDown.inSeconds % 60 == 0){
          Future.delayed(const Duration(seconds: 1)).then((value) {
            setState(() {
              iqomah = false;
              iqomahCountDown!.cancel();
              endCountDown = const Duration(seconds: 0,minutes: 0);
              AssetsAudioPlayer.newPlayer().dispose();
            });
          });
        }
        if (endCountDown.inMinutes % 60 == 0 && endCountDown.inSeconds % 60 == 05){
          AssetsAudioPlayer.newPlayer().open(
            Audio("assets/beep-3.mp3"),
            autoStart: true,
            showNotification: true,
          );
        }
        if (endCountDown.inMinutes % 60 == 0 && endCountDown.inSeconds % 60 == 0){
          AssetsAudioPlayer.newPlayer().open(
            Audio("assets/last-beep.wav"),
            autoStart: true,
            showNotification: true,
          );
          Future.delayed(const Duration(minutes: 15)).then((value){
            setState(() {
              showTime = false;
            });
          });
        }
      });
    });
  }

  String doubleDigitParse(int digit){
    if (digit < 10){
      return '0$digit';
    }else{
      return '$digit';
    }
  }

  String? waktu;
  void adzanTime(){
    final DateTime now = DateTime.now();
    if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.subuh!).hour)}:${DateFormat('HH:mm').parse(adzan.subuh!).minute - 10}'){
      setState(() {
        showTime = true;
        adzanNow = adzan.subuh;
        titleAdzanNowMini = 'Shubuh';
        titleAdzanNow = 'Sebentar Lagi Akan Memasuki Waktu Shubuh';
        if (now.second == 0){
          hideTime();
        }
      });
    }else if (DateFormat('HH:mm').format(now) == '${DateFormat('HH:mm').parse(adzan.dzuhur!).hour}:${DateFormat('HH:mm').parse(adzan.dzuhur!).minute - 10}'){
      setState(() {
        showTime = true;
        adzanNow = adzan.dzuhur;
        titleAdzanNowMini = 'Dhuhur';
        titleAdzanNow = 'Sebentar Lagi Akan Memasuki Waktu Dhuhur';
        if (now.second == 0){
          hideTime();
        }
      });
    }else if (DateFormat('HH:mm').format(now) == '${DateFormat('HH:mm').parse(adzan.ashar!).hour}:${DateFormat('HH:mm').parse(adzan.ashar!).minute - 10}'){
      setState(() {
        showTime = true;
        adzanNow = adzan.ashar;
        titleAdzanNowMini = 'Ashar';
        titleAdzanNow = 'Sebentar Lagi Akan Memasuki Waktu Ashar';
        if (now.second == 0){
          hideTime();
        }
      });
    }else if (DateFormat('HH:mm').format(now) == '${DateFormat('HH:mm').parse(adzan.maghrib!).hour}:${DateFormat('HH:mm').parse(adzan.maghrib!).minute - 10}'){
      setState(() {
        showTime = true;
        adzanNow = adzan.maghrib;
        titleAdzanNowMini = 'Maghrib';
        titleAdzanNow = 'Sebentar Lagi Akan Memasuki Waktu Maghrib';
        if (now.second == 0){
          hideTime();
        }
      });
    }else if (DateFormat('HH:mm').format(now) == '${DateFormat('HH:mm').parse(adzan.isya!).hour}:${DateFormat('HH:mm').parse(adzan.isya!).minute - 10}'){
      setState(() {
        showTime = true;
        adzanNow = adzan.isya;
        titleAdzanNowMini = 'Isya';
        titleAdzanNow = 'Sebentar Lagi Akan Memasuki Waktu Isya';
        if (now.second == 0){
          hideTime();
        }
      });
    }
  }


  void changeTitle(){
    final DateTime now = DateTime.now();
    if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.subuh!).hour)}:${doubleDigitParse(DateFormat('HH:mm').parse(adzan.subuh!).minute)}'){
      setState(() {
        titleAdzanNow = 'Sedang Memasuki Waktu Shubuh';
      });
    }else if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.dzuhur!).hour)}:${doubleDigitParse(DateFormat('HH:mm').parse(adzan.dzuhur!).minute)}'){
      setState(() {
        titleAdzanNow = 'Sedang Memasuki Waktu Dhuhur';
      });
    }else if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.ashar!).hour)}:${doubleDigitParse(DateFormat('HH:mm').parse(adzan.ashar!).minute)}'){
      setState(() {
        titleAdzanNow = 'Sedang Memasuki Waktu Ashar';
      });
    }else if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.maghrib!).hour)}:${doubleDigitParse(DateFormat('HH:mm').parse(adzan.maghrib!).minute)}'){
      setState(() {
        titleAdzanNow = 'Sedang Memasuki Waktu Maghrib';
      });
    }else if (DateFormat('HH:mm').format(now) == '${doubleDigitParse(DateFormat('HH:mm').parse(adzan.isya!).hour)}:${doubleDigitParse(DateFormat('HH:mm').parse(adzan.isya!).minute)}'){
      setState(() {
        titleAdzanNow = 'Sedang Memasuki Waktu Isya';
      });
    }
  }

  void hideTime(){
    Future.delayed(const Duration(minutes: 10)).then((value){
      startIqomah();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: true?SafeArea(
        child: Stack(
          children: [
            Stack(
              children: [
                // CarouselSlider(items: [
                //
                // ],
                //     options: CarouselOptions(
                //       autoPlay: true,
                //       autoPlayInterval: const Duration(minutes: 1),
                //       autoPlayAnimationDuration: Duration(seconds: 10),
                //       enableInfiniteScroll: true,
                //     )),
                FutureBuilder(
                    future: fDatabase.reference().child('setting').child('background').once(),
                    builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                      if (snapshot.hasError)return const Text('Empty');
                      if (snapshot.hasData) {
                        if (snapshot.data!.value != null){
                          String? bg = snapshot.data!.value;
                          return bg != null?Image.asset('assets/bg-1.jpg',fit: BoxFit.cover,width: MediaQuery.of(context).size.width,):Image.asset('assets/bg-1.jpg',fit: BoxFit.cover,width: MediaQuery.of(context).size.width,);
                        }
                      }
                      return const SizedBox();
                    }),
                Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [
                          Color.fromRGBO(0, 0, 0, 90),
                          Color.fromRGBO(0, 0, 0, 120),
                          Colors.black,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        tileMode: TileMode.mirror),
                  ),
                ),
              ],
            ),
            Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _timeString!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              // Container(
                              //   height: .5,
                              //   width: 145,
                              //   decoration: BoxDecoration(
                              //     color: primaryColor
                              //   ),
                              // ),
                              // SizedBox(height: 5,),
                              // Text(
                              //   '05:03:01',
                              //   style: TextStyle(
                              //       color: primaryTextColor,
                              //       fontSize: 24,
                              //       fontWeight: FontWeight.w700
                              //   ),
                              // ),
                              // RichText(
                              //   text: TextSpan(
                              //     text: 'menuju ',
                              //     style: TextStyle(
                              //       fontSize: 18,
                              //       color: primaryTextColor
                              //     ),
                              //     children: const <TextSpan>[
                              //       TextSpan(text: 'Dzuhur', style: TextStyle(fontWeight: FontWeight.bold,fontSize: 24)),
                              //     ],
                              //   ),
                              // )
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                ),
                                borderRadius: BorderRadius.circular(10)
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20,vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                FutureBuilder(
                                    future: fDatabase.reference().child('setting').child('logo').once(),
                                    builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                      if (snapshot.hasError)return const Text('Empty');
                                      if (snapshot.hasData) {
                                        if (snapshot.data!.value != null){
                                          String? nama = snapshot.data!.value;
                                          return Image.network(nama ?? '',height: 80,);
                                        }
                                      }
                                      return const SizedBox();
                                    }),
                                const SizedBox(width: 15,),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder(
                                        future: fDatabase.reference().child('setting').child('name').once(),
                                        builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                          if (snapshot.hasError)return const Text('Empty');
                                          if (snapshot.hasData) {
                                            if (snapshot.data!.value != null){
                                              String? nama = snapshot.data!.value;
                                              return Text(
                                                nama ?? '-',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 36,
                                                    fontWeight: FontWeight.bold
                                                ),
                                              );
                                            }
                                          }
                                          return const SizedBox();
                                        }),
                                    const SizedBox(height: 5,),
                                    FutureBuilder(
                                        future: fDatabase.reference().child('setting').child('address').once(),
                                        builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                          if (snapshot.hasError)return const Text('Empty');
                                          if (snapshot.hasData) {
                                            if (snapshot.data!.value != null){
                                              String? address = snapshot.data!.value;
                                              return SizedBox(
                                                width: MediaQuery.of(context).size.width * .35,
                                                child: Text(
                                                  address ?? '-',
                                                  maxLines: 2,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w400
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                          return const SizedBox();
                                        }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _mDateString!,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold
                                ),
                              ),
                              const SizedBox(height: 5,),
                              Container(
                                height: .5,
                                width: 145,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 5,),
                              Text(
                                _hDateString != null?'$_hDateString':'',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    FutureBuilder(
                        future: fDatabase.reference().child('image').once(),
                        builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                          if (snapshot.hasError)return const Text('error');
                          if (snapshot.hasData) {
                            lists.clear();
                            if (snapshot.data!.value != null){
                              Map<dynamic, dynamic> values = snapshot.data!.value;
                              values.forEach((key, values) {
                                lists.add(values);
                              });
                              return CarouselSlider(
                                options: CarouselOptions(
                                    viewportFraction: 1 ,
                                    height: MediaQuery.of(context).size.height * .5,
                                    autoPlay: true,
                                    aspectRatio: 1,
                                    autoPlayInterval: const Duration(minutes: 1),
                                    autoPlayAnimationDuration: const Duration(seconds: 10)
                                ),
                                items: lists.map((i) {
                                  return Builder(
                                    builder: (BuildContext context) {
                                      return Container(
                                          width: MediaQuery.of(context).size.width,
                                          margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
                                          child: i.contains('http')?ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Image.network(i,fit: BoxFit.contain,)):Column(
                                            children: [
                                              Container(
                                                decoration:BoxDecoration(
                                                  color: Color.fromRGBO(255, 255, 255, 50),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                padding:const EdgeInsets.symmetric(vertical: 10,horizontal: 24),
                                                child: const Text(
                                                  'Pengumuman dari Takmir Masjid',
                                                  style: TextStyle(
                                                      fontSize: 28,
                                                      fontWeight: FontWeight.bold
                                                  ),
                                                ),
                                                margin: EdgeInsets.only(right: 45),
                                              ),
                                              const SizedBox(height: 0),
                                              Container(
                                                  margin: const EdgeInsets.symmetric(horizontal: 30),
                                                  padding: const EdgeInsets.symmetric(horizontal: 20,vertical: 16),
                                                  height: MediaQuery.of(context).size.height * .36,
                                                  child: Center(
                                                    child :AutoSizeText(
                                                      i,
                                                      maxFontSize: 36,
                                                      minFontSize: 24,
                                                      textAlign:TextAlign.center,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 28,
                                                        fontFamily: 'RobotoMono',
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),)
                                              ),
                                            ],
                                          )
                                      );
                                    },
                                  );
                                }).toList(),
                              );
                            }
                          }
                          return const SizedBox();
                        }),
                  ],
                ),
                Positioned(
                  right: 16,
                  left: 16,
                  bottom: 55,
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height:80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              Text(
                                adzan.subuh ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 40),
                              ),
                              const Text(
                                'Shubuh',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 28),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16,),
                      Expanded(
                        child: SizedBox(
                          height:80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.terbit ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 40),
                              ),
                              const Text(
                                'Syuruq',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 28),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16,),
                      Expanded(
                        child: SizedBox(
                          height:80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.dzuhur ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 40),
                              ),
                              const Text(
                                'Dhuhur',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 28),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16,),
                      Expanded(
                        child: SizedBox(
                          height:80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.ashar ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 40),
                              ),
                              const Text(
                                'Ashar',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 28),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16,),
                      Expanded(
                        child: SizedBox(
                          height:80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.maghrib ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 40),
                              ),
                              const Text(
                                'Maghrib',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 28),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16,),
                      Expanded(
                        child: SizedBox(
                          height:80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.isya ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 40),
                              ),
                              const Text(
                                'Isya',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 28),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
            if (showTime)Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              color: secondaryColor,
              child: Stack(
                children: [
                  Image.asset('assets/bg_2.jpeg',fit: BoxFit.cover,width: MediaQuery.of(context).size.width,),
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(0, 0, 0, 50)
                    ),
                  ),
                  Positioned(
                      right:0,
                      bottom: 0,
                      child: SvgPicture.asset(
                        'assets/pattern-mandala.svg',
                        height: MediaQuery.of(context).size.height * .8,
                      )),
                  if (iqomah)Positioned(
                    right: 50,
                    bottom: 50,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            titleAdzanNowMini ?? '-',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 24),
                          ),
                          Text(
                            adzanNow ?? '-',
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 34),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(

                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        iqomah?const Text(
                          'Sebentar Lagi Akan Memasuki Jadwal Iqomah',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 30),
                        ):Text(
                          titleAdzanNow ?? '-',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 30),
                        ),
                        const SizedBox(height: 16,),
                        if (iqomah)Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(0,1),
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 16,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(1,2),
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 6,),
                            const Text(
                              ':',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 80),
                            ),
                            const SizedBox(width: 6,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(3,4),
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 16,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(4,5),
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                          ],
                        )else Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                adzanNow?.substring(0,1) ?? '-',
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 16,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                adzanNow?.substring(1,2) ?? '-',
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 6,),
                            const Text(
                              ':',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 80),
                            ),
                            const SizedBox(width: 6,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                adzanNow?.substring(3,4) ?? '-',
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 16,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                adzanNow?.substring(4,5) ?? '-',
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ):SafeArea(
        child: Stack(
          children: [
            Image.asset('assets/bg.jpeg',fit: BoxFit.cover,width: MediaQuery.of(context).size.width,),
            Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                          color: primaryColor
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FutureBuilder(
                                    future: fDatabase.reference().child('setting').child('logo').once(),
                                    builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                      if (snapshot.hasError)return const Text('Empty');
                                      if (snapshot.hasData) {
                                        if (snapshot.data!.value != null){
                                          String? nama = snapshot.data!.value;
                                          return Image.network(nama ?? '',height: 60,);
                                        }
                                      }
                                      return const SizedBox();
                                    }),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                FutureBuilder(
                                    future: fDatabase.reference().child('setting').child('name').once(),
                                    builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                      if (snapshot.hasError)return const Text('Empty');
                                      if (snapshot.hasData) {
                                        if (snapshot.data!.value != null){
                                          String? nama = snapshot.data!.value;
                                          return Text(
                                            nama ?? '-',
                                            style: GoogleFonts.lobster(
                                              textStyle: const TextStyle(
                                                  color: primaryTextColor,
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.w400
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      return const SizedBox();
                                    }),
                                const SizedBox(height: 5,),
                                FutureBuilder(
                                    future: fDatabase.reference().child('setting').child('address').once(),
                                    builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                                      if (snapshot.hasError)return const Text('Empty');
                                      if (snapshot.hasData) {
                                        if (snapshot.data!.value != null){
                                          String? address = snapshot.data!.value;
                                          return Text(
                                            address ?? '-',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w400
                                            ),
                                          );
                                        }
                                      }
                                      return const SizedBox();
                                    }),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _timeString!,
                                  style: const TextStyle(
                                      color: primaryTextColor,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700
                                  ),
                                ),
                                const SizedBox(height: 5,),
                                Text(
                                  '${_mDateString! }${_hDateString != null?' | $_hDateString':''}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    FutureBuilder(
                        future: fDatabase.reference().child('image').once(),
                        builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                          if (snapshot.hasError)return const Text('error');
                          if (snapshot.hasData) {
                            lists.clear();
                            if (snapshot.data!.value != null){
                              Map<dynamic, dynamic> values = snapshot.data!.value;
                              values.forEach((key, values) {
                                lists.add(values);
                              });
                              return CarouselSlider(
                                options: CarouselOptions(
                                    viewportFraction: 1,
                                    height: MediaQuery.of(context).size.height * .63,
                                    autoPlay: true,
                                    aspectRatio: 1,
                                    autoPlayInterval: const Duration(minutes: 1),
                                    autoPlayAnimationDuration: const Duration(seconds: 10)
                                ),
                                items: lists.map((i) {
                                  return Builder(
                                    builder: (BuildContext context) {
                                      return SizedBox(
                                          width: MediaQuery.of(context).size.width,
                                          child: i.contains('http')?Image.network(i,fit: BoxFit.cover,):Container(
                                              decoration: BoxDecoration(
                                                  color: secondaryColor.withOpacity(.5)
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                                child: Center(child: Text(
                                                  i,
                                                  style: const TextStyle(
                                                      fontSize: 36,
                                                      color: Colors.white
                                                  ),
                                                )),
                                              )
                                          )
                                      );
                                    },
                                  );
                                }).toList(),
                              );
                            }
                          }
                          return const SizedBox();
                        }),
                    Expanded(
                      child: Container(
                        color:primaryColor,
                      ),
                    )
                  ],
                ),
                Positioned(
                  right: 16,
                  left: 16,
                  bottom: 55,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height:80,
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4)
                              )
                            ],
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.subuh ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 30),
                              ),
                              const Text(
                                'Shubuh',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16,),
                      Expanded(
                        child: Container(
                          height:80,
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4)
                              )
                            ],
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.dhuha ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 30),
                              ),
                              const Text(
                                'Syuruq',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16,),
                      Expanded(
                        child: Container(
                          height:80,
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4)
                              )
                            ],
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.dzuhur ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 30),
                              ),
                              const Text(
                                'Dhuhur',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16,),
                      Expanded(
                        child: Container(
                          height:80,
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4)
                              )
                            ],
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.ashar ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 30),
                              ),
                              const Text(
                                'Ashar',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16,),
                      Expanded(
                        child: Container(
                          height:80,
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4)
                              )
                            ],
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.maghrib ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 30),
                              ),
                              const Text(
                                'Maghrib',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16,),
                      Expanded(
                        child: Container(
                          height:80,
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4)
                              )
                            ],
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                adzan.isya ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 30),
                              ),
                              const Text(
                                'Isya',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
            if (showTime)Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              color: primaryColor,
              child: Stack(
                children: [
                  Positioned(
                      right:0,
                      bottom: 0,
                      child: SvgPicture.asset(
                        'assets/pattern-mandala.svg',
                        height: MediaQuery.of(context).size.height * .8,
                      )),
                  if (iqomah)Positioned(
                    right: 50,
                    bottom: 50,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            titleAdzanNowMini ?? '-',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 24),
                          ),
                          Text(
                            adzanNow ?? '-',
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 34),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(

                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        iqomah?const Text(
                          'Sebentar Lagi Akan Memasuki Jadwal Iqomah',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 30),
                        ):Text(
                          titleAdzanNow ?? '-',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 30),
                        ),
                        const SizedBox(height: 16,),
                        if (iqomah)Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(0,1),
                                style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 16,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(1,2),
                                style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 6,),
                            const Text(
                              ':',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 80),
                            ),
                            const SizedBox(width: 6,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(3,4),
                                style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 16,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                '${doubleDigitParse(endCountDown.inMinutes % 60)}:${doubleDigitParse(endCountDown.inSeconds % 60)}'.substring(4,5),
                                style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                          ],
                        )else Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                adzanNow?.substring(0,1) ?? '-',
                                style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 16,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                adzanNow?.substring(1,2) ?? '-',
                                style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 6,),
                            const Text(
                              ':',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 80),
                            ),
                            const SizedBox(width: 6,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                adzanNow?.substring(3,4) ?? '-',
                                style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                            const SizedBox(width: 16,),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15)
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                adzanNow?.substring(4,5) ?? '-',
                                style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 80),
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: !showTime?Container(
        height: 50,
        color:Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FutureBuilder(
                future: fDatabase.reference().child('setting').child('logo').once(),
                builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                  if (snapshot.hasError)return const Text('Empty');
                  if (snapshot.hasData) {
                    if (snapshot.data!.value != null){
                      String? nama = snapshot.data!.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Image.network(nama ?? '',height: 30,),
                      );
                    }
                  }
                  return const SizedBox();
                }),
            Expanded(
              child: FutureBuilder(
                  future: fDatabase.reference().child('information').once(),
                  builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                    if (snapshot.hasError)return const Text('error');
                    if (snapshot.hasData) {
                      information.clear();
                      if (snapshot.data!.value != null){
                        Map<dynamic, dynamic> values = snapshot.data!.value;
                        values.forEach((key, values) {
                          information.add(values);
                        });
                        return Marquee(
                          text: information.length == 1?information[0] :'${information[0]}        ${information[1]}',
                          blankSpace: 50,
                          style: const TextStyle(
                              color:Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 30
                          ),
                        );
                      }
                    }
                    return const SizedBox();
                  }),
            ),
            // Expanded(
            //   child: FutureBuilder(
            //       future: fDatabase.reference().child('information').once(),
            //       builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
            //         if (snapshot.hasError)return Text('Empty');
            //         if (snapshot.hasData) {
            //           if (snapshot.data!.value != null){
            //             Map<dynamic, dynamic> values = snapshot.data!.value;
            //             print(values);
            //             String? info;
            //             values.forEach((key, values) {
            //               info = values;
            //             });
            //             return Marquee(
            //               text: info ?? '',
            //               blankSpace: 50,
            //               style: TextStyle(
            //                   color:Colors.black,
            //                   fontWeight: FontWeight.w600,
            //                   fontSize: 30
            //               ),
            //             );
            //           }
            //         }
            //         return SizedBox();
            //       }),
            // ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: FutureBuilder(
                  future: fDatabase.reference().child('setting').child('logo').once(),
                  builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
                    if (snapshot.hasError)return const Text('Empty');
                    if (snapshot.hasData) {
                      if (snapshot.data!.value != null){
                        String? nama = snapshot.data!.value;
                        return Image.network(nama ?? '',height: 30,);
                      }
                    }
                    return const SizedBox();
                  }),
            ),
          ],
        ),
      ):const SizedBox(),
      // floatingActionButton: FloatingActionButton(
      //   child: Icon(
      //     Icons.add
      //   ),
      //   onPressed: (){
      //     startIqomah();
      //   },
      // ),
    );
  }
}
