class UserModel{
  String uid;
  String firstName;
  String lastName;
  String phone;

  UserModel({this.firstName, this.lastName, this.phone});

  UserModel.fromJson(Map<String,dynamic> json){
    //uid = json['uid'];  -> because we always set key from firebase to uid, so here we can don't bind it
    firstName = json['firstName'];
    lastName = json['lastName'];
    phone = json['phone'];
  }

  Map<String,dynamic> toJson(){
    final Map<String,dynamic> data = new Map<String,dynamic>();
    data['firstName'] = this.firstName;
    data['lastName'] = this.lastName;
    data['phone'] = this.phone;
    //data['uid'] = this.uid;
    return data;
  }

}