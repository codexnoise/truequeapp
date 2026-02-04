import 'package:flutter/material.dart';
import '../../domain/entities/item_entity.dart';

class EditItemPage extends StatefulWidget {
  final ItemEntity item;

  const EditItemPage({super.key, required this.item});

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _desiredItemController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(text: widget.item.description);
    _desiredItemController = TextEditingController(text: widget.item.desiredItem);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _desiredItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Artículo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // TODO: Implement delete functionality
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Eliminar Artículo'),
                  content: const Text('¿Estás seguro de que quieres eliminar este artículo?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: actually delete
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(); // Go back from edit page
                      },
                      child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _desiredItemController,
                decoration: const InputDecoration(labelText: 'Artículo Deseado'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement update logic
                },
                child: const Text('Guardar Cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}