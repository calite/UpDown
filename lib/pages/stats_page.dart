import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../widgets/app_drawer.dart';
import '../config/app_config.dart';

/// Página de estadísticas.
/// Contiene 3 secciones que pueden mostrarse o no según configuración:
/// 1. Totales globales (gráfico circular)
/// 2. Comparación entre equipos (gráfico de barras)
/// 3. Detalle por integrantes de cada equipo (gráfico de barras por miembro)
class StatsPage extends StatelessWidget {
  final Map<String, dynamic> args;
  const StatsPage({super.key, this.args = const {}});

  @override
  Widget build(BuildContext context) {
    int totalPositives = 0;
    int totalNegatives = 0;

    // Calculamos totales de todos los equipos
    for (Team team in mockTeams) {
      for (Member member in team.members) {
        totalPositives += member.positives;
        totalNegatives += member.negatives;
      }
    }

    final int total = totalPositives + totalNegatives;

    return Scaffold(
      appBar: AppBar(title: const Text("📊 Estadísticas")),
      endDrawer: AppDrawer(args: args),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =============================
            // 1. SECCIÓN TOTAL (GLOBAL)
            // =============================
            if (AppConfig.showGlobalStats) ...[
              const Text(
                "📌 Totales globales",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Gráfico circular global
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        color: Colors.green,
                        value: totalPositives.toDouble(),
                        title:
                            "${((totalPositives / (total == 0 ? 1 : total)) * 100).toStringAsFixed(1)}%",
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.red,
                        value: totalNegatives.toDouble(),
                        title:
                            "${((totalNegatives / (total == 0 ? 1 : total)) * 100).toStringAsFixed(1)}%",
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Leyenda de colores
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegend(Colors.green, "Positivos: $totalPositives"),
                  const SizedBox(width: 20),
                  _buildLegend(Colors.red, "Negativos: $totalNegatives"),
                ],
              ),

              const SizedBox(height: 40),
            ],

            // =============================
            // 2. SECCIÓN POR EQUIPOS
            // =============================
            if (AppConfig.showTeamStats) ...[
              const Text(
                "📌 Comparación entre equipos",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxYTeams(mockTeams).toDouble(),
                    barGroups: _buildTeamBarGroups(),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final int index = value.toInt();
                            if (index >= 0 && index < mockTeams.length) {
                              return Text(
                                mockTeams[index].name,
                                style: const TextStyle(fontSize: 12),
                              );
                            }
                            return const Text("");
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),

                    // Tooltip al tocar cada barra
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            rod.toY.toInt().toString(),
                            const TextStyle(color: Colors.white, fontSize: 14),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],

            // =============================
            // 3. SECCIÓN DETALLE POR EQUIPO
            // =============================
            if (AppConfig.showMemberStats) ...[
              const Text(
                "📌 Detalle por equipo",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Un gráfico para cada equipo con sus integrantes
              ...mockTeams.map((team) {
                final positives = team.members.map((m) => m.positives).toList();
                final negatives = team.members.map((m) => m.negatives).toList();
                final names = team.members.map((m) => m.name).toList();

                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "🏷️ ${team.name}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _getMaxY(positives, negatives).toDouble(),
                              barGroups: _buildMemberBarGroups(
                                positives,
                                negatives,
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final int idx = value.toInt();
                                      if (idx >= 0 && idx < names.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            names[idx],
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        );
                                      }
                                      return const Text("");
                                    },
                                  ),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),

                              // Tooltip con valores de cada barra
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem:
                                      (group, groupIndex, rod, rodIndex) {
                                        return BarTooltipItem(
                                          rod.toY.toInt().toString(),
                                          const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        );
                                      },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildLegend(Colors.green, "Positivos"),
                            const SizedBox(width: 20),
                            _buildLegend(Colors.red, "Negativos"),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  // =============================
  // FUNCIONES AUXILIARES
  // =============================

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
          margin: const EdgeInsets.only(right: 8),
        ),
        Text(text),
      ],
    );
  }

  List<BarChartGroupData> _buildTeamBarGroups() {
    List<BarChartGroupData> groups = [];
    for (int i = 0; i < mockTeams.length; i++) {
      final team = mockTeams[i];
      int positives = team.members.fold(0, (sum, m) => sum + m.positives);
      int negatives = team.members.fold(0, (sum, m) => sum + m.negatives);
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: positives.toDouble(),
              color: Colors.green,
              width: 8,
            ),
            BarChartRodData(
              toY: negatives.toDouble(),
              color: Colors.red,
              width: 8,
            ),
          ],
          barsSpace: 4,
        ),
      );
    }
    return groups;
  }

  List<BarChartGroupData> _buildMemberBarGroups(
    List<int> positives,
    List<int> negatives,
  ) {
    List<BarChartGroupData> groups = [];
    for (int i = 0; i < positives.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: positives[i].toDouble(),
              color: Colors.green,
              width: 8,
            ),
            BarChartRodData(
              toY: negatives[i].toDouble(),
              color: Colors.red,
              width: 8,
            ),
          ],
          barsSpace: 4,
        ),
      );
    }
    return groups;
  }

  int _getMaxYTeams(List<Team> teams) {
    int maxVal = 0;
    for (var team in teams) {
      final positives = team.members.fold(0, (sum, m) => sum + m.positives);
      final negatives = team.members.fold(0, (sum, m) => sum + m.negatives);
      maxVal = [maxVal, positives, negatives].reduce((a, b) => a > b ? a : b);
    }
    return maxVal + 5;
  }

  int _getMaxY(List<int> positives, List<int> negatives) {
    final maxPos = positives.isNotEmpty
        ? positives.reduce((a, b) => a > b ? a : b)
        : 0;
    final maxNeg = negatives.isNotEmpty
        ? negatives.reduce((a, b) => a > b ? a : b)
        : 0;
    final maxVal = maxPos > maxNeg ? maxPos : maxNeg;
    return maxVal + 5;
  }
}
