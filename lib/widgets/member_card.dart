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
  final VoidCallback? onMakeGestor;
  final VoidCallback? onDeleteMember;
  final VoidCallback? onEditMember;
  final Color? backgroundColor;

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
    this.onMakeGestor,
    this.onDeleteMember,
    this.onEditMember,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isSelf = currentUser.id == member.id;
    final canRate = currentUser.isActive;
    final canUsePositive = currentUser.role == UserRole.user
        ? onSuggestPositive != null
        : onDirectPositive != null;
    final canUseNegative = currentUser.role == UserRole.user
        ? onSuggestNegative != null
        : onDirectNegative != null;
    final canOpenMenu =
        onEditMember != null ||
        onToggleActive != null ||
        onMakeGestor != null ||
        onDeleteMember != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: backgroundColor,
      child: ListTile(
        leading: GeneratedAvatar.circle(
          seed: member.id,
          label: member.displayName,
        ),
        title: Row(
          children: [
            Expanded(child: Text(member.displayName)),
            if (member.alias.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  member.alias.trim(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          'Positivos: ${member.positives} | Negativos: ${member.negatives}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isSelf && canRate && canUsePositive)
              IconButton(
                icon: const Icon(Icons.thumb_up, color: Colors.green),
                onPressed: () {
                  if (currentUser.role == UserRole.user) {
                    onSuggestPositive?.call();
                  } else if (currentUser.role == UserRole.admin ||
                      currentUser.role == UserRole.gestor) {
                    onDirectPositive?.call();
                  }
                },
              ),
            if (!isSelf && canRate && canUseNegative)
              IconButton(
                icon: const Icon(Icons.thumb_down, color: Colors.red),
                onPressed: () {
                  if (currentUser.role == UserRole.user) {
                    onSuggestNegative?.call();
                  } else if (currentUser.role == UserRole.admin ||
                      currentUser.role == UserRole.gestor) {
                    onDirectNegative?.call();
                  }
                },
              ),
            if (canOpenMenu)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'editMember') {
                    onEditMember?.call();
                  } else if (value == 'toggleActive') {
                    onToggleActive?.call();
                  } else if (value == 'makeGestor') {
                    onMakeGestor?.call();
                  } else if (value == 'deleteMember') {
                    onDeleteMember?.call();
                  }
                },
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[];
                  if (onEditMember != null) {
                    items.add(
                      const PopupMenuItem(
                        value: 'editMember',
                        child: Text('Editar datos'),
                      ),
                    );
                  }
                  if (onToggleActive != null) {
                    items.add(
                      PopupMenuItem(
                        value: 'toggleActive',
                        child: Text(
                          member.isActive ? 'Deshabilitar' : 'Reactivar',
                        ),
                      ),
                    );
                  }
                  if (onMakeGestor != null) {
                    items.add(
                      const PopupMenuItem(
                        value: 'makeGestor',
                        child: Text('Hacer gestor'),
                      ),
                    );
                  }
                  if (onDeleteMember != null) {
                    items.add(
                      const PopupMenuItem(
                        value: 'deleteMember',
                        child: Text('Eliminar integrante'),
                      ),
                    );
                  }
                  return items;
                },
              ),
          ],
        ),
        onTap: onHistory,
      ),
    );
  }
}
