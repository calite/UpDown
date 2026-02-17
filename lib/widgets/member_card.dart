import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/widgets/generated_avatar.dart';

class MemberCard extends StatelessWidget {
  final Member member;
  final Member currentUser;
  final Team team;

  final VoidCallback? onHistory;
  final VoidCallback? onSuggestPositive;
  final VoidCallback? onSuggestNegative;
  final VoidCallback? onDirectPositive;
  final VoidCallback? onDirectNegative;
  final VoidCallback? onToggleActive;
  final VoidCallback? onMakeAdmin;
  final VoidCallback? onDeleteMember;

  const MemberCard({
    super.key,
    required this.member,
    required this.currentUser,
    required this.team,
    this.onHistory,
    this.onSuggestPositive,
    this.onSuggestNegative,
    this.onDirectPositive,
    this.onDirectNegative,
    this.onToggleActive,
    this.onMakeAdmin,
    this.onDeleteMember,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: GeneratedAvatar.circle(seed: member.id, label: member.displayName),
        title: Text(member.displayName),
        subtitle: Text(
          'Positivos: ${member.positives} | Negativos: ${member.negatives}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.thumb_up, color: Colors.green),
              onPressed: () {
                if (currentUser.role == UserRole.user && currentUser != member) {
                  onSuggestPositive?.call();
                } else if (currentUser.role == UserRole.admin) {
                  onDirectPositive?.call();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.thumb_down, color: Colors.red),
              onPressed: () {
                if (currentUser.role == UserRole.user && currentUser != member) {
                  onSuggestNegative?.call();
                } else if (currentUser.role == UserRole.admin) {
                  onDirectNegative?.call();
                }
              },
            ),
            if (currentUser.role == UserRole.admin)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'toggleActive') {
                    onToggleActive?.call();
                  } else if (value == 'makeAdmin') {
                    onMakeAdmin?.call();
                  } else if (value == 'deleteMember') {
                    onDeleteMember?.call();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggleActive',
                    child: Text(member.isActive ? 'Deshabilitar' : 'Reactivar'),
                  ),
                  const PopupMenuItem(
                    value: 'makeAdmin',
                    child: Text('Hacer administrador'),
                  ),
                  const PopupMenuItem(
                    value: 'deleteMember',
                    child: Text('Eliminar integrante'),
                  ),
                ],
              ),
          ],
        ),
        onTap: onHistory,
      ),
    );
  }
}
