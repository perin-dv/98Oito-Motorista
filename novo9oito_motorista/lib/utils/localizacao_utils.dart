import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocalizacaoUtils
{
  /// Calcula a distância em km entre dois pontos usando Geolocator
  static double distanciaKm(double deLat, double deLng, double ateLat, double ateLng)
{
    final metros = Geolocator.distanceBetween(deLat, deLng, ateLat, ateLng);
    return metros / 1000.0;
  }

  /// Converte graus para radianos
  static double _deg2rad(double deg) => deg * (pi / 180.0);

  /// Calcula a direção (bearing) em graus do ponto A até o ponto B
  static double bearingGraus(double lat1, double lon1, double lat2, double lon2)
{
    final latRad1 = _deg2rad(lat1);
    final latRad2 = _deg2rad(lat2);
    final deltaLonRad  = _deg2rad(lon2 - lon1);

    final y = sin(deltaLonRad) * cos(latRad2);
    final x = cos(latRad1) * sin(latRad2) - sin(latRad1) * cos(latRad2) * cos(deltaLonRad);
    sin(latRad1) * cos(latRad2) * cos(deltaLonRad);
    final bearing = atan2(y, x) * 180.0 / pi;
    return (bearing + 360.0) % 360.0;
  }

  /// Calcula ETA aproximado em minutos, dado a velocidade km/h
  static Duration etaAprox(double distanciaKm, {double velocidadeKmH = 40})
{
    if (velocidadeKmH <= 0) return Duration.zero;
    final horas = distanciaKm / velocidadeKmH;
    return Duration(minutes: (horas * 60).round());
  }
}
