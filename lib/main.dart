import 'dart:async';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';
import 'package:expansion_tile_card/expansion_tile_card.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StayActive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _isRunning = false;
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  List<String> _keyPressEvents = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });

    _colorAnimation = ColorTween(begin: const Color(0xff243441), end: const Color(0xffc94e65)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _simulateKeyPress() {
    final input = calloc<INPUT>();
    input.ref.type = INPUT_TYPE.INPUT_KEYBOARD;
    input.ref.ki.wVk = VIRTUAL_KEY.VK_SHIFT; // Virtual-Key Code for Shift
    input.ref.ki.dwFlags = 0; // 0 for key press
    SendInput(1, input, sizeOf<INPUT>());

    input.ref.ki.dwFlags = KEYBD_EVENT_FLAGS.KEYEVENTF_KEYUP; // KEYEVENTF_KEYUP for key release
    SendInput(1, input, sizeOf<INPUT>());
    calloc.free(input);

    // Ajouter l'événement de pression de touche à la liste
    setState(() {
      _keyPressEvents.add('[${DateTime.now().toLocal()}] Shift key pressed');
    }); // Mettre à jour l'interface utilisateur
  }

  void _startStayActive() {
    SetThreadExecutionState(EXECUTION_STATE.ES_CONTINUOUS | EXECUTION_STATE.ES_DISPLAY_REQUIRED);

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _simulateKeyPress();
    });
    setState(() {
      _isRunning = true;
      _controller.forward();
    });
  }

  void _stopStayActive() {
    _timer?.cancel();
    SetThreadExecutionState(EXECUTION_STATE.ES_CONTINUOUS);

    setState(() {
      _isRunning = false;
      _controller.stop();
      _controller.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff243441),
      appBar: AppBar(
        title: const Text('StayActive', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff243441),
      ),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isRunning)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _colorAnimation.value ?? Colors.red, width: 5),
                    ),
                  );
                },
              ),
            ElevatedButton(
              onPressed: _isRunning ? _stopStayActive : _startStayActive,
              child: Text(_isRunning ? 'Stop' : 'Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRunning ? const Color(0xffc94e65) : const Color(0xff29cfc5),
                foregroundColor: const Color(0xff243441),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                elevation: 30,
                shadowColor: _isRunning ? const Color(0xffc94e65) : const Color(0xff29cfc5),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: _isExpanded? 200 : 60, // Adjust the height to a fixed value or a smaller percentage
        color: Color(0xff243441),
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: _isExpanded? 200 : 50, // Adjust the height to a fixed value or a smaller percentage
          child: SingleChildScrollView(
          padding: EdgeInsets.all(0),// Remove Expanded widget
            child: ExpansionTileCard(
              baseColor: Colors.white,
              expandedColor: Colors.white,
              title: const Text('Console outputs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
              animateTrailing: true,
              children: [
                if (_isExpanded)
                  SingleChildScrollView(
                    padding: EdgeInsets.all(0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: _keyPressEvents.map((event) => ListTile(
                          title: Text(event, style: TextStyle(fontSize: 9),),
                        dense: true,
                      )).toList(),
                    ),
                  )
              ],
              onExpansionChanged: (value) {
                setState(() {
                  _isExpanded = value;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    SetThreadExecutionState(EXECUTION_STATE.ES_CONTINUOUS);
    _controller.dispose();
    super.dispose();
  }
}
