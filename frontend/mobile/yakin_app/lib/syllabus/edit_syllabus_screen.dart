import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditSyllabusScreen extends StatefulWidget {
  const EditSyllabusScreen({super.key});

  @override
  State<EditSyllabusScreen> createState() => _EditSyllabusScreenState();
}

class _EditSyllabusScreenState extends State<EditSyllabusScreen> {
  String? studentNumber;
  Map<String, dynamic> syllabusData = {};
  bool isLoading = true;

  final daysOfWeek = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday"
  ];

  // TextEditingController'ları saklamak için
  Map<String, List<Map<String, TextEditingController>>> controllers = {};

  @override
  void initState() {
    super.initState();
    _loadStudentNumberAndSyllabus();
  }

  Future<void> _loadStudentNumberAndSyllabus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    studentNumber = prefs.getString('studentNumber');

    if (studentNumber != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentNumber)
            .get();

        if (userDoc.exists) {
          setState(() {
            syllabusData =
                userDoc.get('syllabus') as Map<String, dynamic>? ?? {};
            _initializeControllers();
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kullanıcı bulunamadı.')),
          );
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Öğrenci numarası bulunamadı.')),
      );
    }
  }

  // TextEditingController'ları başlatmak için
  void _initializeControllers() {
    for (var day in daysOfWeek) {
      var dayLessons = syllabusData[day] as List<dynamic>? ?? [];
      controllers[day] = [];

      for (var lesson in dayLessons) {
        var lessonNameController =
            TextEditingController(text: lesson['lessonName']);
        var timeController = TextEditingController(text: lesson['time']);

        controllers[day]?.add({
          'lessonName': lessonNameController,
          'time': timeController,
        });
      }
    }
  }

  // Ders eklemek için fonksiyon
  void _addLesson(String day) {
    setState(() {
      syllabusData[day] ??= [];
      (syllabusData[day] as List).add({
        'lessonName': '',
        'time': '',
      });

      // Yeni kontrolörleri oluştur
      var lessonNameController = TextEditingController();
      var timeController = TextEditingController();

      controllers[day] ??= [];
      controllers[day]?.add({
        'lessonName': lessonNameController,
        'time': timeController,
      });
    });
  }

  // Ders silmek için fonksiyon
  void _removeLesson(String day, int index) {
    setState(() {
      (syllabusData[day] as List).removeAt(index);

      // Kontrolörleri de kaldır
      controllers[day]?.removeAt(index);
    });
  }

  // Ders programını kaydetmek için fonksiyon
  Future<void> _saveSyllabus() async {
    if (studentNumber != null) {
      try {
        // Kontrolörlerden değerleri al ve syllabusData'yı güncelle
        for (var day in daysOfWeek) {
          var dayControllers = controllers[day] ?? [];
          var lessons = [];

          for (var i = 0; i < dayControllers.length; i++) {
            var lessonName = dayControllers[i]['lessonName']!.text;
            var time = dayControllers[i]['time']!.text;

            lessons.add({
              'lessonName': lessonName,
              'time': time,
            });
          }

          syllabusData[day] = lessons;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(studentNumber)
            .update({'syllabus': syllabusData});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ders programı kaydedildi.')),
        );

        Navigator.pop(context); // Geri dön
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ders Programını Düzenle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSyllabus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: daysOfWeek.map((day) {
            var dayLessons = syllabusData[day] as List<dynamic>? ?? [];
            var dayControllers = controllers[day] ?? [];
            return ExpansionTile(
              title: Text(day),
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dayLessons.length,
                  itemBuilder: (context, index) {
                    var lesson = dayLessons[index] as Map<String, dynamic>;

                    var lessonNameController =
                        dayControllers[index]['lessonName']!;
                    var timeController = dayControllers[index]['time']!;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Ders Adı',
                              ),
                              controller: lessonNameController,
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Saat',
                              ),
                              controller: timeController,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () {
                                _removeLesson(day, index);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _addLesson(day);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Ders Ekle'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}