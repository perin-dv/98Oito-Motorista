import 'package:flutter/material.dart';
import 'dart:async';
import '../data/services/audio_service.dart';

class RideNotificationOverlay extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final int timeoutSeconds;

  const RideNotificationOverlay({
    super.key,
    required this.rideData,
    required this.onAccept,
    required this.onDecline,
    this.timeoutSeconds = 15,
  });

  @override
  State<RideNotificationOverlay> createState() => _RideNotificationOverlayState();
}

class _RideNotificationOverlayState extends State<RideNotificationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  
  Timer? _timeoutTimer;
  Timer? _soundTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeoutSeconds;
    
    // Configurar animações
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Iniciar animações
    _animationController.forward();
    _pulseController.repeat(reverse: true);
    
    // Tocar som inicial
    AudioService().playNewRideSound();
    
    // Timer para tocar som repetidamente
    _soundTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_remainingSeconds > 0) {
        AudioService().playNewRideSound();
      }
    });
    
    // Timer de timeout
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        _decline();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _timeoutTimer?.cancel();
    _soundTimer?.cancel();
    super.dispose();
  }

  void _accept() {
    AudioService().playRideAcceptedSound();
    _animationController.reverse().then((_) {
      widget.onAccept();
    });
  }

  void _decline() {
    AudioService().playErrorSound();
    _animationController.reverse().then((_) {
      widget.onDecline();
    });
  }

  @override
  Widget build(BuildContext context) {
    final valor = widget.rideData['valor'] ?? 0;
    final origem = widget.rideData['origemDescricao'] ?? 'Origem não informada';
    final destino = widget.rideData['destinoDescricao'] ?? 'Destino não informado';
    
    return Material(
      color: Colors.black54,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * MediaQuery.of(context).size.height),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Card principal da notificação
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Título com animação de pulso
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6A4C93), Color(0xFF8B5CF6)],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Text(
                                  '🚗 NOVA CORRIDA!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Valor da corrida
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6600).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: const Color(0xFFFF6600),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            'R\$ ${valor.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFFFF6600),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Origem e destino
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4CAF50),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      origem,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 10),
                              
                              // Linha pontilhada
                              Container(
                                height: 20,
                                child: CustomPaint(
                                  painter: DottedLinePainter(),
                                  child: Container(),
                                ),
                              ),
                              
                              const SizedBox(height: 10),
                              
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF6600),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      destino,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Timer
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _remainingSeconds <= 5 
                                ? Colors.red.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Tempo restante: ${_remainingSeconds}s',
                            style: TextStyle(
                              color: _remainingSeconds <= 5 
                                  ? Colors.red
                                  : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 25),
                        
                        // Botões de ação
                        Row(
                          children: [
                            // Botão Recusar
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _decline,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  foregroundColor: Colors.grey[700],
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: const Text(
                                  'Recusar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 15),
                            
                            // Botão Aceitar
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _accept,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: const Text(
                                  'Aceitar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 15.0;

    while (startX < size.width - 15) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

