import 'package:edmt_chat_app/screen/chat_screen.dart';
import 'package:edmt_chat_app/screen/register_screen.dart';
import 'package:edmt_chat_app/utils/utils.dart';
import 'package:firebase_auth_ui/firebase_auth_ui.dart';
import 'package:firebase_auth_ui/providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_transition/page_transition.dart';

import 'const/const.dart';
import 'firebase_utils/firebase_utils.dart';
import 'model/user_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FirebaseApp app = await Firebase.initializeApp();
  runApp(ProviderScope(child: MyApp(app: app)));
}

class MyApp extends StatelessWidget {
  FirebaseApp app;

  MyApp({this.app});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/register':
            return PageTransition(
                child: RegisterScreen(
                  app: app,
                  user: FirebaseAuth.FirebaseAuth.instance.currentUser ?? null,
                ),
                type: PageTransitionType.fade,
                settings: settings);
            break;
          case '/detail':
            return PageTransition(
                child: DetailScreen(
                  app: app,
                  user: FirebaseAuth.FirebaseAuth.instance.currentUser ?? null,
                ),
                type: PageTransitionType.fade,
                settings: settings);
            break;

          default:
            return null;
        }
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page', app: app),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final FirebaseApp app;

  final String title;

  MyHomePage({Key key, this.title, this.app}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  DatabaseReference _peopleRef, _chatListRef;
  FirebaseDatabase database;

  bool isUserInit = false;

  UserModel userLogged;

  final List<Tab> tabs = <Tab>[
    Tab(icon: Icon(Icons.chat), text: 'Chat'),
    Tab(icon: Icon(Icons.people), text: 'Friends'),
  ];

  TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: tabs.length, vsync: this);

    database = FirebaseDatabase(app: widget.app);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      processLogin(context);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: Text(widget.title),
        bottom: new TabBar(
          isScrollable: false,
          unselectedLabelColor: Colors.black45,
          labelColor: Colors.white,
          tabs: tabs,
          controller: _tabController,
        ),
      ),
      body: isUserInit
          ? TabBarView(
        controller: _tabController,
        children: tabs
            .map((Tab tab) => tab.text == 'Chat'
            ? loadChatList(database, _chatListRef)
            : loadPeople(database,_peopleRef))
            .toList(),
      )
          : Center(child: CircularProgressIndicator()),
    );
  }

  void processLogin(BuildContext context) async {
    var user = FirebaseAuth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      //if not login
      FirebaseAuthUi.instance()
          .launchAuth([AuthProvider.phone()]).then((fbUser) async {
        //refresh state
        await _chatListRefState(context);
      }).catchError((e) {
        if (e is PlatformException) {
          if (e.code == FirebaseAuthUi.kUserCancelledError)
            showOnlySnackBar(context, 'User cancelled login');
          else
            showOnlySnackBar(context, '${e.message ?? 'Unk error'}');
        }
      });
    } else {
      //already login
      await _chatListRefState(context);
    }
  }

  Future<FirebaseAuth.User> _chatListRefState(BuildContext context) async {
    if (FirebaseAuth.FirebaseAuth.instance.currentUser != null) {
      //already login get token
      FirebaseAuth.FirebaseAuth.instance.currentUser
          .getIdToken()
          .then((token) async {
        _peopleRef = database.reference().child(PEOPLE_REF);
        _chatListRef = database
            .reference()
            .child(CHATLIST_REF)
            .child(FirebaseAuth.FirebaseAuth.instance.currentUser.uid);

        //Load Information
        _peopleRef
            .child(FirebaseAuth.FirebaseAuth.instance.currentUser.uid)
            .once()
            .then((snapshot) {
          if (snapshot != null && snapshot.value != null) {
            setState(() {
              isUserInit = true;
            });
          } else {
            setState(() {
              isUserInit = true;
            });
            Navigator.pushNamed(context, '/register');
          }
        });
      });
    }
    return FirebaseAuth.FirebaseAuth.instance.currentUser;
  }




}