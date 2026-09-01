import 'package:hive/hive.dart';

part 'diary_model.g.dart'; // file sẽ được generate

@HiveType(typeId: 0) // mỗi model cần 1 typeId duy nhất
class DiaryModel {
  @HiveField(0)
  int id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  String userId;

  DiaryModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.userId,
  });
}
