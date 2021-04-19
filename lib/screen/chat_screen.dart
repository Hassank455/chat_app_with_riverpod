import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:edmt_chat_app/const/const.dart';
import 'package:edmt_chat_app/model/chat_info.dart';
import 'package:edmt_chat_app/model/chat_message.dart';
import 'package:edmt_chat_app/state/state_manger.dart';
import 'package:edmt_chat_app/utils/utils.dart';
import 'package:edmt_chat_app/widget/bubble.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/all.dart';
import 'package:sliding_sheet/sliding_sheet.dart';
import 'package:uuid/uuid.dart';

import 'camera_screen.dart';

class DetailScreen extends ConsumerWidget {
  DetailScreen({this.app, this.user});

  FirebaseApp app;
  User user;

  DatabaseReference offsetRef, chatRef;
  FirebaseDatabase database;

  TextEditingController _textEditingController = TextEditingController();
  ScrollController _scrollController = ScrollController();

  @override
  Widget build(context, watch) {
    var friendUser = watch(chatUser).state;

    var isShowPicture = watch(isCapture).state;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('${friendUser.firstName} ${friendUser.lastName}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                flex: 8,
                child: friendUser.uid != null
                    ? FirebaseAnimatedList(
                        controller: _scrollController,
                        sort: (DataSnapshot a, DataSnapshot b) =>
                            b.key.compareTo(a.key),
                        reverse: true,
                        query: loadChatContent(context, app),
                        itemBuilder: (BuildContext context,
                            DataSnapshot snapshot,
                            Animation<double> animation,
                            int index) {
                          var chatContent = ChatMessage.fromJson(
                              json.decode(json.encode(snapshot.value)));

                          return SizeTransition(
                            sizeFactor: animation,
                            child: chatContent.picture
                                ? chatContent.senderId == user.uid
                                    ? bubbleImageFromUser(chatContent)
                                    : bubbleImageFromFriend(chatContent)
                                : chatContent.senderId == user.uid
                                    ? bubbleTextFromUser(chatContent)
                                    : bubbleTextFromFriend(chatContent),
                          );
                        },
                      )
                    : Center(
                        child: CircularProgressIndicator(),
                      ),
              ),
              Expanded(
                flex: isShowPicture ? 2 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isShowPicture
                        ? Container(
                            width: 80,
                            height: 80,
                            child: Stack(
                              children: [
                                Image.file(
                                    File(context
                                        .read(thumbnailImage)
                                        .state
                                        .path),
                                    fit: BoxFit.fill),
                                Align(
                                  alignment: Alignment.topRight,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      context.read(isCapture).state = false;
                                    },
                                  ),
                                )
                              ],
                            ),
                          )
                        : Container(),
                    Expanded(
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.add_a_photo),
                            onPressed: () {
                              showBottomSheetPicture(context);
                            },
                          ),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.multiline,
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              decoration: InputDecoration(
                                  hintText: 'Enter your message'),
                              controller: _textEditingController,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.send),
                            onPressed: () {
                              offsetRef.once().then((DataSnapshot snapshot) {
                                var offset = snapshot.value as int;
                                var estimatedServerTimeInMs =
                                    DateTime.now().millisecondsSinceEpoch +
                                        offset;

                                submitChat(context, estimatedServerTimeInMs);
                              });

                              // Auto Scroll chat layout to end
                              autoScroll(_scrollController);
                            },
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
      ),
    );
  }

  loadChatContent(BuildContext context, FirebaseApp app) {
    database = FirebaseDatabase(app: app);
    offsetRef = database.reference().child('.info/serverTimeOffset');
    chatRef = database
        .reference()
        .child(CHAT_REF)
        .child(getRoomId(user.uid, context.read(chatUser).state.uid))
        .child(DETAIL_REF);
    return chatRef;
  }

  void submitChat(BuildContext context, int estimatedServerTimeInMs) {
    ChatMessage chatMessage = ChatMessage();
    chatMessage.name = createName(context.read(userLogged).state);
    chatMessage.content = _textEditingController.text;
    chatMessage.timeStamp = estimatedServerTimeInMs;
    chatMessage.senderId = user.uid;

    //Image and Text
    if (context.read(isCapture).state)
      chatMessage.picture = true;
    else
      chatMessage.picture = false;
    submitChatToFirebase(context, chatMessage, estimatedServerTimeInMs);
  }

  void submitChatToFirebase(BuildContext context, ChatMessage chatMessage,
      int estimatedServerTimeInMs) {
    chatRef.once().then((DataSnapshot snapshot) {
      if (snapshot != null) // if user already create chat befor
        createChat(context, chatMessage, estimatedServerTimeInMs);
    });
  }

  void createChat(BuildContext context, ChatMessage chatMessage,
      int estimatedServerTimeInMs) {
    //create chat info
    ChatInfo chatInfo = new ChatInfo(
      createId: user.uid,
      friendName: createName(context.read(chatUser).state),
      friendId: context.read(chatUser).state.uid,
      createName: createName(context.read(userLogged).state),
      lastMessage: chatMessage.picture ? '<Image>' : chatMessage.content,
      lastUpdate: DateTime.now().millisecondsSinceEpoch,
      createDate: DateTime.now().millisecondsSinceEpoch,
    );

    //Add on Firebase
    database
        .reference()
        .child(CHATLIST_REF)
        .child(user.uid)
        .child(context.read(chatUser).state.uid)
        .set(<String, dynamic>{
      'lastUpdate': chatInfo.lastUpdate,
      'lastMessage': chatInfo.lastMessage,
      'createId': chatInfo.createId,
      'friendId': chatInfo.friendId,
      'createName': chatInfo.createName,
      'friendName': chatInfo.friendName,
      'createDate': chatInfo.createDate,
    }).then((value) {
      //After success, copy to Friend chat list
      database
          .reference()
          .child(CHATLIST_REF)
          .child(context.read(chatUser).state.uid)
          .child(user.uid)
          .set(<String, dynamic>{
        'lastUpdate': chatInfo.lastUpdate,
        'lastMessage': chatInfo.lastMessage,
        'createId': chatInfo.createId,
        'friendId': chatInfo.friendId,
        'createName': chatInfo.createName,
        'friendName': chatInfo.friendName,
        'createDate': chatInfo.createDate,
      }).then((value) async {
        if (chatMessage.picture) {
          //Upload picture
          var pictureName = Uuid().v1();
          FirebaseStorage storage = FirebaseStorage.instanceFor(app: app);
          Reference ref =
              storage.ref().child('images').child('$pictureName.jpg');
          final metaData = SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'picked-file-path': context.read(thumbnailImage).state.path
              });
          var filePath = context.read(thumbnailImage).state.path;

          File file = new File(filePath);
          var task = await uploadFile(ref, metaData, file);
          task.whenComplete(() {
            //When upload done, we will get download url to submit chat
            storage
                .ref()
                .child('images/$pictureName.jpg')
                .getDownloadURL()
                .then((value) {
              //After success, add on chat Reference
              chatMessage.pictureLink = value; // Add value to link
              writeChatToFirebase(context, chatRef, chatMessage);
            });
          });
        } else {
          // if only text
          //After success, add on chat Reference
          writeChatToFirebase(context, chatRef, chatMessage);
        }
      }).catchError((e) => showOnlySnackBar(
              context, 'Error can\'t submit Friend chat list'));
    }).catchError((e) =>
            showOnlySnackBar(context, 'Error can\'t submit User chat list'));
  }

  void showBottomSheetPicture(BuildContext context) async {
    final result = await showSlidingBottomSheet(context, builder: (context) {
      return SlidingSheetDialog(
        elevation: 8,
        cornerRadius: 16,
        snapSpec: const SnapSpec(
          snap: true,
          snappings: [0.2],
          positioning: SnapPositioning.relativeToAvailableSpace,
        ),
        builder: (context, state) {
          return Container(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      await _navigateCamera(context);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.camera),
                        SizedBox(width: 20),
                        Text(
                          'Camera',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        )
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {},
                    child: Row(
                      children: [
                        Icon(Icons.photo),
                        SizedBox(width: 20),
                        Text(
                          'Photo',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  _navigateCamera(BuildContext context) async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (context) => MyCameraPage()));
    //Set State
    context.read(thumbnailImage).state = result;
    context.read(isCapture).state = true;

    Navigator.pop(context); // Close Sliding Sheet
  }

  Future<UploadTask> uploadFile(
      Reference ref, SettableMetadata metaData, File file) async {
    var uploadTask = ref.putData(await file.readAsBytes(), metaData);
    return Future.value(uploadTask);
  }

  void writeChatToFirebase(BuildContext context, DatabaseReference chatRef,
      ChatMessage chatMessage) {
    chatRef.push().set(<String, dynamic>{
      'uid': chatMessage.uid,
      'name': chatMessage.name,
      'content': chatMessage.content,
      'pictureLink': chatMessage.pictureLink,
      'picture': chatMessage.picture,
      'senderId': chatMessage.senderId,
      'timeStamp': chatMessage.timeStamp,
    }).then((value) {
      //clear text content
      _textEditingController.text = '';
      //Set picture hide
      if (chatMessage.picture) context.read(isCapture).state = false;

      //Auto Scroll
      autoScrollReverse(_scrollController);
    }).catchError((e) => showOnlySnackBar(context, 'Error submit CHAT REF'));
  }
}
