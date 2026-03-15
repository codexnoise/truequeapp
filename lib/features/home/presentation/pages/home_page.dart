import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../domain/entities/item_entity.dart';
import '../providers/home_provider.dart';
import '../widgets/category_constants.dart';
import '../widgets/item_card_widget.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  String _searchQuery = '';
  String? _selectedCategory;
  bool _showOnlyFreeItems = false;

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;

    switch (index) {
      case 0:
        setState(() => _currentIndex = 0);
        break;
      case 1:
        setState(() => _currentIndex = index);
        context.pushNamed('conversations').then((_) {
          if (mounted) setState(() => _currentIndex = 0);
        });
        break;
      case 2:
        setState(() => _currentIndex = index);
        context.pushNamed('my-items').then((_) {
          if (mounted) setState(() => _currentIndex = 0);
        });
        break;
      case 3:
        setState(() => _currentIndex = index);
        context.pushNamed('profile').then((_) {
          if (mounted) setState(() => _currentIndex = 0);
        });
        break;
    }
  }

  List<ItemEntity> _filterItems(List<ItemEntity> items) {
    var filtered = items;

    if (_showOnlyFreeItems) {
      filtered = filtered.where((item) => item.desiredItem == 'Donation').toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered.where((item) => item.categoryId == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) => item.title.toLowerCase().contains(_searchQuery)).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final availableItems = ref.watch(availableItemsProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'TRUEQUEAPP',
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
              color: colorScheme.onSurface,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none, color: colorScheme.onSurface),
                onPressed: () => context.pushNamed('notifications'),
              ),
              if (unreadCount.hasValue && unreadCount.value! > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount.value! > 9 ? '9+' : '${unreadCount.value}',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout, color: colorScheme.onSurface),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar artículos...',
                    prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('CATEGORÍAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2, color: colorScheme.onSurface)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16),
                  children: [
                    _CategoryChip(
                      label: 'Todos',
                      isSelected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    ...categories.entries.map((entry) {
                      return _CategoryChip(
                        label: entry.value,
                        isSelected: _selectedCategory == entry.key,
                        onTap: () => setState(() => _selectedCategory = entry.key),
                      );
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CheckboxListTile(
                  title: const Text("Solo donaciones"),
                  value: _showOnlyFreeItems,
                  onChanged: (bool? value) {
                    setState(() {
                      _showOnlyFreeItems = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: colorScheme.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: availableItems.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(child: Text("No hay artículos disponibles de otros usuarios."));
                    }

                    final filteredItems = _filterItems(items);

                    if (filteredItems.isEmpty) {
                      return const Center(child: Text("Ningún artículo coincide con tu búsqueda."));
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return ItemCard(item: item);
                      },
                    );
                  },
                  loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
                  error: (err, stack) => Center(child: Text("Error: $err")),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed('add-item'),
        backgroundColor: colorScheme.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.add, color: colorScheme.onPrimary),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surface,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensajes'),
          BottomNavigationBarItem(icon: Icon(Icons.format_list_bulleted), label: 'Mis Artículos'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  const _CategoryChip({required this.label, this.isSelected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
