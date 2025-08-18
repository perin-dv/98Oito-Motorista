import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import '../data/services/audio_service.dart';

class NavigationWidget extends StatefulWidget {
  final LatLng destination;
  final String destinationName;
  final VoidCallback? onArrived;
  final Function(String)? onETAUpdate;

  const NavigationWidget({
    super.key,
    required this.destination,
    required this.destinationName,
    this.onArrived,
    this.onETAUpdate,
  });

  @override
  State<NavigationWidget> createState() => _NavigationWidgetState();
}

class _NavigationWidgetState extends State<NavigationWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  
  double _distanceToDestination = 0;
  String _eta = '--';
  String _instruction = 'Siga em frente';
  bool _isNearDestination = false;
  bool _hasArrived = false;
  
  final AudioService _audioService = AudioService();
  
  // Progresso da viagem (0.0 a 1.0)
  double _tripProgress = 0.0;
  double _initialDistance = 0.0;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    
    _startLocationTracking();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      _updateNavigation(position);
    });
  }

  void _updateNavigation(Position position) {
    setState(() {
      _currentPosition = position;
      
      // Calcula distância para o destino
      _distanceToDestination = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.destination.latitude,
        widget.destination.longitude,
      );
      
      // Define distância inicial se ainda não foi definida
      if (_initialDistance == 0.0) {
        _initialDistance = _distanceToDestination;
      }
      
      // Calcula progresso da viagem
      if (_initialDistance > 0) {
        _tripProgress = math.max(0.0, 
          math.min(1.0, 1.0 - (_distanceToDestination / _initialDistance))
        );
        _progressController.animateTo(_tripProgress);
      }
      
      // Calcula ETA baseado na velocidade
      if (position.speed > 0) {
        final etaSeconds = _distanceToDestination / position.speed;
        final etaMinutes = (etaSeconds / 60).round();
        _eta = etaMinutes > 0 ? '${etaMinutes} min' : '< 1 min';
      } else {
        _eta = '--';
      }
      
      // Atualiza instrução baseada na distância
      _updateInstruction();
      
      // Verifica se chegou próximo ao destino
      _checkProximity();
    });
    
    // Callback para atualizar ETA
    widget.onETAUpdate?.call(_eta);
  }

  void _updateInstruction() {
    if (_distanceToDestination < 50) {
      _instruction = 'Você chegou ao destino';
    } else if (_distanceToDestination < 100) {
      _instruction = 'Destino à frente';
    } else if (_distanceToDestination < 200) {
      _instruction = 'Aproximando-se do destino';
    } else if (_distanceToDestination < 500) {
      _instruction = 'Continue em frente';
    } else {
      _instruction = 'Siga em frente';
    }
  }

  void _checkProximity() {
    // Próximo ao destino (100m)
    if (_distanceToDestination <= 100 && !_isNearDestination) {
      _isNearDestination = true;
      _audioService.playArrivalSequence();
    }
    
    // Chegou ao destino (30m)
    if (_distanceToDestination <= 30 && !_hasArrived) {
      _hasArrived = true;
      _audioService.playRideCompletedSound();
      widget.onArrived?.call();
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header com progresso
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A4C93), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.navigation,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Navegando para',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _eta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 15),
                
                // Barra de progresso
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6600),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 10),
                
                Text(
                  '${(_tripProgress * 100).round()}% concluído',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Conteúdo principal
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Destino
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isNearDestination ? _pulseAnimation.value : 1.0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _isNearDestination 
                                  ? const Color(0xFFFF6600)
                                  : const Color(0xFF6A4C93),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.destinationName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDistance(_distanceToDestination),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Instrução de navegação
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isNearDestination 
                        ? const Color(0xFFFF6600).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: _isNearDestination 
                        ? Border.all(color: const Color(0xFFFF6600), width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isNearDestination 
                            ? Icons.location_on
                            : Icons.straight,
                        color: _isNearDestination 
                            ? const Color(0xFFFF6600)
                            : const Color(0xFF6A4C93),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _instruction,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isNearDestination 
                                ? const Color(0xFFFF6600)
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Informações adicionais se próximo
                if (_isNearDestination) ...[
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF4CAF50),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF4CAF50),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Prepare-se para finalizar a corrida',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

