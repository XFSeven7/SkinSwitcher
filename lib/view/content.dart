import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SkinImageViewer(),
    );
  }
}

class SkinImageViewer extends StatefulWidget {
  @override
  _SkinImageViewerState createState() => _SkinImageViewerState();
}

class _SkinImageViewerState extends State<SkinImageViewer> {
  List<File> leftImageFiles = [];
  File? selectedLeftImage;
  String? rightDirectory;
  bool _dragging = false;
  String leftBtnText = "选择源文件夹";
  String rightBtnText = "选择对应文件夹";
  String filterStr = "";

  Future<void> _pickLeftFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      List<FileSystemEntity> files = Directory(selectedDirectory)
          .listSync()
          .where((file) =>
      file is File &&
          (file.path.endsWith('.png') ||
              file.path.endsWith('.jpg') ||
              file.path.endsWith('.jpeg') ||
              file.path.endsWith('.webp') ||
              file.path.endsWith('.gif')))
          .toList();
      setState(() {
        leftBtnText = selectedDirectory;
        leftImageFiles = files.cast<File>();
      });
    }
  }

  Future<void> _pickRightFolder() async {
    rightDirectory = await FilePicker.platform.getDirectoryPath();
    setState(() {
      rightBtnText = rightDirectory!;
    });
  }

  bool _hasCorrespondingImage(String leftImageName) {
    if (rightDirectory == null) {
      return false;
    }
    String rightImagePath = path.join(rightDirectory!, leftImageName);
    return File(rightImagePath).existsSync();
  }

  // 提示用户后缀不同的对话框
  Future<void> _showDifferentExtensionDialog(BuildContext context,
      String extension, File file) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 用户必须点击按钮才能关闭对话框
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('文件后缀不同'),
          content: Text(
              '拖拽的文件后缀是 .$extension，和当前选择的文件类型不同，是否继续操作？'),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop(); // 取消操作
              },
            ),
            TextButton(
              child: Text('继续'),
              onPressed: () async {
                // imageFiles.add(file);
                String fileName = path.basenameWithoutExtension(
                    selectedLeftImage!.path); // 获取文件名，不包含后缀
                String fileExtension = path.extension(file.path); // 获取文件的后缀名
                String destPath = path.join(
                    rightDirectory!, "$fileName$fileExtension"); // 拼接文件名和后缀
                debugPrint("destPath: $destPath");
                await file.copy(destPath); // 复制文件
                setState(() {
                  _dragging = false;
                });
                Navigator.of(context).pop(); // 继续操作
              },
            ),
          ],
        );
      },
    );
  }

  Widget _getRightImageWidget() {
    if (selectedLeftImage == null || rightDirectory == null) {
      return Center(child: Text('未选择图片或右侧文件夹'));
    }

    String rightImagePath =
    path.join(rightDirectory!, path.basename(selectedLeftImage!.path));

    // 提取文件的后缀名
    String _getFileExtension(String path) {
      return path
          .split('.')
          .last;
    }

    if (File(rightImagePath).existsSync()) {
      return Center(
        child: Stack(
          children: [
            Center(
              child: Image.file(
                File(rightImagePath),
                fit: BoxFit.contain,
              ),
            ),
            // 右上角的删除按钮
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  // 执行删除操作
                  final file = File(rightImagePath);
                  debugPrint("删除图片$rightImagePath");
                  if (await file.exists()) {
                    await file.delete();
                    setState(() {});
                  }
                },
              ),
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 右上角的复制按钮
            Container(
              child: TextButton(
                child: Text('快速复制源文件'),
                onPressed: () async {
                  String fileName = path.basename(selectedLeftImage!.path);
                  String destPath = path.join(rightDirectory!, fileName);
                  File newFile = File(selectedLeftImage!.path);
                  await newFile.copy(destPath);
                  setState(() {});
                },
              ),
            ),
            Text('暂无对应图片，拖拽文件产生对应关系'),
            DropTarget(
              onDragEntered: (details) {
                setState(() {
                  _dragging = true;
                });
              },
              onDragExited: (details) {
                setState(() {
                  _dragging = false;
                });
              },
              onDragDone: (details) async {
                debugPrint("detail = $details");

                // 选中的图片的后缀
                String selectedExtension =
                _getFileExtension(selectedLeftImage!.path);

                String dropExtension =
                _getFileExtension(details.files.first.path);

                if (selectedExtension != dropExtension) {
                  // 后缀不同，弹出提示框
                  File dropFile = new File(details.files.first.path);
                  _showDifferentExtensionDialog(
                      context, selectedExtension, dropFile);
                } else {
                  if (details.files.isNotEmpty && selectedLeftImage != null) {
                    String fileName = path.basename(selectedLeftImage!.path);
                    String destPath = path.join(rightDirectory!, fileName);
                    File newFile = File(details.files.first.path);
                    await newFile.copy(destPath);
                    setState(() {
                      // Update UI after drop
                      _dragging = false;
                    });
                  }
                }
              },
              child: Container(
                height: 300,
                width: 300,
                color:
                _dragging ? Colors.blue.withOpacity(0.4) : Colors.grey[200],
                child: Center(
                  child: Text("拖拽图片到这里"),
                ),
              ),
            )
          ],
        ),
      );
    }
  }

  /// 筛选包含指定文字的文件名
  List<File> filterFilesByText(String text, List<File> leftImageFiles) {
    // 创建一个新的集合，用于存储符合条件的文件
    List<File> filteredFiles = [];

    // 遍历文件列表
    for (File file in leftImageFiles) {
      // 获取文件名
      String fileName = file.path
          .split(Platform.pathSeparator)
          .last;

      // 检查文件名是否包含指定的文字
      if (fileName.contains(text)) {
        // 如果包含，将该文件添加到新集合
        filteredFiles.add(file);
      }
    }

    return filteredFiles;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _pickLeftFolder,
                    child: Text(leftBtnText),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero, // 设为 0 即可去掉圆角
                      ),
                    ),
                  ),
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: '名字筛选',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    filterStr = text;
                    setState(() {

                    });
                  },
                ),
                Expanded(
                  child: leftImageFiles.isEmpty
                      ? Center(child: Text('左边未选择图片'))
                      : ListView.builder(
                    itemCount: filterFilesByText(filterStr, leftImageFiles).length,
                    itemBuilder: (context, index) {
                      String imageName =
                      path.basename(filterFilesByText(filterStr, leftImageFiles)[index].path);
                      bool hasCorrespondingImage =
                      _hasCorrespondingImage(imageName);
                      bool isSelected =
                          selectedLeftImage == filterFilesByText(filterStr, leftImageFiles)[index];

                      return Container(
                        decoration: BoxDecoration(
                          color: hasCorrespondingImage
                              ? Colors.green.withOpacity(0.3)
                              : Colors.red.withOpacity(0.3),
                          border: isSelected
                              ? Border.all(
                            color: Colors.blue,
                            width: 3.0,
                          )
                              : null,
                        ),
                        child: ListTile(
                          leading: Image.file(
                            filterFilesByText(filterStr, leftImageFiles)[index],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                          title: Text(imageName),
                          onTap: () {
                            setState(() {
                              selectedLeftImage = filterFilesByText(filterStr, leftImageFiles)[index];
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(
            color: Colors.black,
            width: 1,
            thickness: 1,
          ),
          Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _pickRightFolder,
                          child: Text(rightBtnText),
                          style: ElevatedButton.styleFrom(
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero, // 设为 0 即可去掉圆角
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _getRightImageWidget(),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: TextButton(
                      onPressed: () async {
                        final Uri url =
                        Uri.parse('https://github.com/XFSeven7/SkinSwitcher');
                        bool a = await launchUrl(url);
                        debugPrint("$a");

                        setState(() {});
                      },
                      child: Text("查看教程"),
                    ),
                  ),
                ],

              )),
        ],
      ),
    );
  }
}
