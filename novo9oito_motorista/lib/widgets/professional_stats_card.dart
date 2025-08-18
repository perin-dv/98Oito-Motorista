import 'package:flutter/material.dart';
import 'dart:math' as math;

class ProfessionalStatsCard extends StatefulWidget {
  final double todayEarnings;
  final int todayRides;
  final bool isOnline;
  final String currentTime;

  const ProfessionalStatsCard({
    super.key,
    required this.todayEarnings,
    required this.todayRides,
    required this.isOnline,
    required this.currentTime,
  });

  @override
  State<ProfessionalStatsCard> createState() => _ProfessionalStatsCardState();
}

class _ProfessionalStatsCardState extends State<ProfessionalStatsCard>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _counterController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _counterAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _counterController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    _counterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
    _counterController.forward();
  }

  @override
  void didUpdateWidget(ProfessionalStatsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.todayEarnings != oldWidget.todayEarnings ||
        widget.todayRides != oldWidget.todayRides) {
      _counterController.reset();
      _counterController.forward();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6A4C93),
              const Color(0xFF8B5CF6),
              const Color(0xFF6A4C93).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A4C93).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Padrão de fundo decorativo
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF6600).withOpacity(0.2),
                ),
              ),
            ),
            
            // Conteúdo principal
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header com status e horário
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: widget.isOnline 
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey[400],
                              shape: BoxShape.circle,
                              boxShadow: widget.isOnline ? [
                                BoxShadow(
                                  color: const Color(0xFF4CAF50).withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ] : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        widget.currentTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Título
                  const Text(
                    'Hoje',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Estatísticas
                  Row(
                    children: [
                      // Ganhos
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.attach_money,
                          label: 'Ganhos',
                          value: 'R\$ ${widget.todayEarnings.toStringAsFixed(2)}',
                          color: const Color(0xFFFF6600),
                          animation: _counterAnimation,
                        ),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Corridas
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.directions_car,
                          label: 'Corridas',
                          value: widget.todayRides.toString(),
                          color: Colors.white,
                          animation: _counterAnimation,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Barra de progresso da meta diária
                  _buildDailyGoalProgress(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Animation<double> animation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Transform.scale(
              scale: 0.8 + (0.2 * animation.value),
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDailyGoalProgress() {
    const dailyGoal = 200.0; // Meta diária de R$ 200
    final progress = math.min(widget.todayEarnings / dailyGoal, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Meta diária',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'R\$ ${dailyGoal.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: AnimatedBuilder(
            animation: _counterAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress * _counterAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6600), Color(0xFFFFAB40)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(0)}% da meta',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

