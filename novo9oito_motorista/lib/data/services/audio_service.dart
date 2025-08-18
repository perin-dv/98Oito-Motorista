import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  /// Configura se os sons estão habilitados
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// Configura se a vibração está habilitada
  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  /// Toca som de nova corrida disponível
  Future<void> playNewRideSound() async {
    if (!_soundEnabled) return;
    
    try {
      // Som de alerta para nova corrida
      await SystemSound.play(SystemSoundType.alert);
      
      // Vibração intensa
      if (_vibrationEnabled) {
        await HapticFeedback.heavyImpact();
        
        // Padrão de vibração: vibra 3 vezes
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.heavyImpact();
      }
      
      debugPrint('🔊 Som de nova corrida tocado');
    } catch (e) {
      debugPrint('❌ Erro ao tocar som de nova corrida: $e');
    }
  }

  /// Toca som de corrida aceita
  Future<void> playRideAcceptedSound() async {
    if (!_soundEnabled) return;
    
    try {
      await SystemSound.play(SystemSoundType.click);
      
      if (_vibrationEnabled) {
        await HapticFeedback.mediumImpact();
      }
      
      debugPrint('✅ Som de corrida aceita tocado');
    } catch (e) {
      debugPrint('❌ Erro ao tocar som de corrida aceita: $e');
    }
  }

  /// Toca som de corrida finalizada
  Future<void> playRideCompletedSound() async {
    if (!_soundEnabled) return;
    
    try {
      // Som de sucesso
      await SystemSound.play(SystemSoundType.click);
      
      if (_vibrationEnabled) {
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.lightImpact();
      }
      
      debugPrint('🎉 Som de corrida finalizada tocado');
    } catch (e) {
      debugPrint('❌ Erro ao tocar som de corrida finalizada: $e');
    }
  }

  /// Toca som de erro ou cancelamento
  Future<void> playErrorSound() async {
    if (!_soundEnabled) return;
    
    try {
      await SystemSound.play(SystemSoundType.alert);
      
      if (_vibrationEnabled) {
        await HapticFeedback.heavyImpact();
      }
      
      debugPrint('❌ Som de erro tocado');
    } catch (e) {
      debugPrint('❌ Erro ao tocar som de erro: $e');
    }
  }

  /// Toca som de navegação (quando próximo do destino)
  Future<void> playNavigationSound() async {
    if (!_soundEnabled) return;
    
    try {
      await SystemSound.play(SystemSoundType.click);
      
      if (_vibrationEnabled) {
        await HapticFeedback.selectionClick();
      }
      
      debugPrint('🧭 Som de navegação tocado');
    } catch (e) {
      debugPrint('❌ Erro ao tocar som de navegação: $e');
    }
  }

  /// Toca feedback tátil leve
  Future<void> playLightFeedback() async {
    if (!_vibrationEnabled) return;
    
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('❌ Erro ao tocar feedback leve: $e');
    }
  }

  /// Toca feedback tátil médio
  Future<void> playMediumFeedback() async {
    if (!_vibrationEnabled) return;
    
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('❌ Erro ao tocar feedback médio: $e');
    }
  }

  /// Toca feedback tátil forte
  Future<void> playHeavyFeedback() async {
    if (!_vibrationEnabled) return;
    
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('❌ Erro ao tocar feedback forte: $e');
    }
  }

  /// Sequência de sons para chegada próxima ao destino
  Future<void> playArrivalSequence() async {
    if (!_soundEnabled) return;
    
    try {
      // Sequência de 2 bips
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 300));
      await SystemSound.play(SystemSoundType.click);
      
      if (_vibrationEnabled) {
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 300));
        await HapticFeedback.mediumImpact();
      }
      
      debugPrint('🎯 Sequência de chegada tocada');
    } catch (e) {
      debugPrint('❌ Erro ao tocar sequência de chegada: $e');
    }
  }
}

