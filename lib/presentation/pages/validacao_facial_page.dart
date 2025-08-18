import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class ValidacaoFacialPage extends StatefulWidget {
  const ValidacaoFacialPage({super.key});

  @override
  State<ValidacaoFacialPage> createState() => _ValidacaoFacialPageState();
}

class _ValidacaoFacialPageState extends State<ValidacaoFacialPage> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isValidating = false;
  bool _validationSuccess = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // Usar câmera frontal se disponível
        final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Erro ao inicializar câmera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Validação Facial',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Instruções
          Container(
            padding: const EdgeInsets.all(20),
            child: const Column(
              children: [
                Icon(
                  Icons.face,
                  size: 60,
                  color: Color(0xFFFF6600), // Laranja
                ),
                SizedBox(height: 16),
                Text(
                  'Posicione seu rosto no centro da tela',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Mantenha o rosto bem iluminado e olhe diretamente para a câmera',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Câmera
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _validationSuccess
                      ? Colors.green
                      : const Color(0xFFFF6600), // Laranja
                  width: 4,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildCameraPreview(),
              ),
            ),
          ),

          // Overlay de validação
          if (_isValidating)
            Container(
              padding: const EdgeInsets.all(20),
              child: const Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6600)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Validando...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

          if (_validationSuccess)
            Container(
              padding: const EdgeInsets.all(20),
              child: const Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 60,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Validação realizada com sucesso!',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Botão de captura
          if (!_isValidating && !_validationSuccess)
            Container(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _isCameraInitialized ? _capturarFoto : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6600), // Laranja
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt),
                    SizedBox(width: 8),
                    Text(
                      'Capturar Foto',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          if (_validationSuccess)
            Container(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check),
                    SizedBox(width: 8),
                    Text(
                      'Continuar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6600)),
            ),
            SizedBox(height: 16),
            Text(
              'Inicializando câmera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        CameraPreview(_cameraController!),

        // Overlay para guiar o posicionamento do rosto
        Center(
          child: Container(
            width: 250,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(150),
            ),
            child: const Center(
              child: Text(
                'Posicione seu rosto aqui',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _capturarFoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isValidating = true;
    });

    try {
      final XFile foto = await _cameraController!.takePicture();

      // Simular processo de validação facial
      await Future.delayed(const Duration(seconds: 3));

      // Simular resultado positivo (em produção, seria uma API real)
      final bool validacaoSucesso = true; // Resultado da API de validação

      if (mounted) {
        setState(() {
          _isValidating = false;
          _validationSuccess = validacaoSucesso;
        });

        if (validacaoSucesso) {
          // Salvar resultado da validação
          _salvarValidacao(foto.path);
        } else {
          _mostrarErroValidacao();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar foto: $e')),
        );
      }
    }
  }

  void _salvarValidacao(String fotoPath) {
    // Implementar salvamento da validação no Firebase
    print('Validação facial realizada com sucesso: $fotoPath');
  }

  void _mostrarErroValidacao() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validação não realizada'),
        content: const Text(
          'Não foi possível validar seu rosto. Certifique-se de que:\n\n'
          '• Seu rosto está bem iluminado\n'
          '• Você está olhando diretamente para a câmera\n'
          '• Não há obstáculos cobrindo seu rosto',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}

