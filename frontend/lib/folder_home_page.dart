import 'package:flutter/material.dart';
import 'note_page.dart';

class FolderHomePage extends StatefulWidget {
  const FolderHomePage({super.key});

  static const background = Color(0xFFFBFCF7);
  static const cobaltBlue = Color(0xFF004377);

  @override
  State<FolderHomePage> createState() => _FolderHomePageState();
}

class _FolderHomePageState extends State<FolderHomePage> {
  List<String> folderNames = ['강의자료', 'AI노트'];
  List<bool> isEditing = [];
  List<TextEditingController> controllers = [];

  @override
  void initState() {
    super.initState();
    isEditing = List.filled(folderNames.length, false, growable: true);
    controllers = List.generate(
      folderNames.length,
      (index) => TextEditingController(text: folderNames[index]),
      growable: true,
    );
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolderHomePage.background,
      appBar: AppBar(
        title: const Text('iPlanner', style: TextStyle(color: FolderHomePage.cobaltBlue)),
        backgroundColor: FolderHomePage.background,
        iconTheme: const IconThemeData(color: FolderHomePage.cobaltBlue),
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: FolderHomePage.background,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const DrawerHeader(
              child: Text('메뉴', style: TextStyle(fontSize: 20, color: FolderHomePage.cobaltBlue)),
            ),
            ExpansionTile(
              title: const Text('PDF', style: TextStyle(color: FolderHomePage.cobaltBlue)),
              children: const [
                ListTile(title: Text('- A과목')),
                ListTile(title: Text('- B과목')),
                ListTile(title: Text('- PDF')),
              ],
            ),
            ListTile(
              title: const Text('AI 학습플래너', style: TextStyle(color: FolderHomePage.cobaltBlue)),
              onTap: () {
                Navigator.pushNamed(context, '/home');
              },
            ),
            const ListTile(
              title: Text('스터디 타이머', style: TextStyle(color: FolderHomePage.cobaltBlue)),
            ),
            const ListTile(
              title: Text('마이페이지', style: TextStyle(color: FolderHomePage.cobaltBlue)),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 16,
          childAspectRatio: 1,
          children: List.generate(folderNames.length, (index) => _buildFolder(index)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: FolderHomePage.cobaltBlue,
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFolder(int index) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.folder, size: 48, color: FolderHomePage.cobaltBlue),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              isEditing[index] = true;
            });
          },
          child: isEditing[index]
              ? SizedBox(
                  width: 80,
                  height: 30,
                  child: TextField(
                    controller: controllers[index],
                    autofocus: true,
                    onSubmitted: (value) {
                      setState(() {
                        folderNames[index] = value;
                        isEditing[index] = false;
                      });
                    },
                    onEditingComplete: () {
                      setState(() {
                        folderNames[index] = controllers[index].text;
                        isEditing[index] = false;
                      });
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      border: OutlineInputBorder(),
                    ),
                  ),
                )
              : Text(
                  folderNames[index],
                  style: const TextStyle(color: FolderHomePage.cobaltBlue),
                ),
        ),
      ],
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.create_new_folder, color: FolderHomePage.cobaltBlue),
                title: const Text('폴더'),
                onTap: () {
                  Navigator.pop(context);
                  _createFolder();
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file, color: FolderHomePage.cobaltBlue),
                title: const Text('불러오기'),
                onTap: () {
                  Navigator.pop(context);
                  _importFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file, color: FolderHomePage.cobaltBlue),
                title: const Text('노트'),
                onTap: () {
                  Navigator.pop(context);
                  _createNote();
                },
              ),
            ],
          ),
        );
      },
    );
  }
  String _generateUniqueFolderName() {
    String baseName = '새 폴더';
    String newName = baseName;
    int counter = 1;

    // 중복되면 숫자 붙이기
    while (folderNames.contains(newName)) {
      newName = '$baseName ($counter)';
      counter++;
    }

    return newName;
  }

  void _createFolder() {
    debugPrint('📁 폴더 생성!');
    // 폴더 생성 시 리스트에 추가
    setState(() {
      String uniqueName = _generateUniqueFolderName();
      folderNames.add(uniqueName);
      controllers.add(TextEditingController(text: uniqueName)); 
      isEditing.add(false); // 생성만 하고 편집은 나중에
    });

    // build가 끝난 후에 편집 모드 on
    Future.delayed(Duration(milliseconds: 50), () {
      setState(() {
        isEditing[folderNames.length - 1] = true;
      });
    });

  }

  void _createNote() {
      debugPrint('📝 노트 생성!');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotePage()),
    );
  }

  void _importFile() {
    debugPrint('📂 파일 불러오기!');
    // 여기에 파일 불러오기 로직 추가
  }
}
