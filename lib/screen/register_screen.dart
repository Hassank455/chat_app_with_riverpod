import 'package:edmt_chat_app/const/const.dart';
import 'package:edmt_chat_app/model/user_model.dart';
import 'package:edmt_chat_app/utils/utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  FirebaseApp app;
  User user;

  RegisterScreen({this.app, this.user});

  TextEditingController _firstNameController = new TextEditingController();
  TextEditingController _lastNameController = new TextEditingController();
  TextEditingController _phoneController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('REGISTER'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextField(
                    keyboardType: TextInputType.name,
                    controller: _firstNameController,
                    decoration: InputDecoration(hintText: 'First Name'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextField(
                    keyboardType: TextInputType.name,
                    controller: _lastNameController,
                    decoration: InputDecoration(hintText: 'Last Name'),
                  ),
                ),
              ],
            ),
            TextField(
              readOnly: true,
              controller: _phoneController,
              decoration: InputDecoration(hintText: user.phoneNumber ?? 'NULL'),
            ),
            RaisedButton(
              onPressed: () {
                if (_firstNameController == null ||
                    _firstNameController.text.isEmpty)
                  showOnlySnackBar(context, 'Please enter first name');
                else if (_lastNameController == null ||
                    _lastNameController.text.isEmpty)
                  showOnlySnackBar(context, 'Please enter last name');
                else {
                  UserModel userModel = new UserModel(
                    firstName: _firstNameController.text,
                    lastName: _lastNameController.text,
                    phone: user.phoneNumber,
                  );

                  //Submit on Firebase
                  FirebaseDatabase(app: app)
                      .reference()
                      .child(PEOPLE_REF)
                      .child(user.uid)
                      .set(<String, dynamic>{
                    'firstName': userModel.firstName,
                    'lastName': userModel.lastName,
                    'phone': userModel.phone,
                  }).then((value) {
                    showOnlySnackBar(context, 'Register Success');
                    Navigator.pop(context);
                  }).catchError((e) => showOnlySnackBar(context, '$e'));
                }
              },
              child: Text('REGISTER', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}