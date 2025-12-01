import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/data_provider.dart';

class ViewDataScreen extends StatefulWidget {
  final bool enableEdit;
  
  const ViewDataScreen({super.key, this.enableEdit = false});

  @override
  State<ViewDataScreen> createState() => _ViewDataScreenState();
}

class _ViewDataScreenState extends State<ViewDataScreen> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _searchData() async {
    if (_idController.text.trim().isEmpty) {
      _showError('Please enter a data ID');
      return;
    }

    final dataProvider = context.read<DataProvider>();
    final success = await dataProvider.getDataById(_idController.text.trim());

    if (success && mounted && dataProvider.currentData != null) {
      setState(() {
        _nameController.text = dataProvider.currentData!.name;
        _messageController.text = dataProvider.currentData!.message;
      });
    } else if (mounted && dataProvider.errorMessage != null) {
      _showError(dataProvider.errorMessage!);
    }
  }

  Future<void> _updateData() async {
    final dataProvider = context.read<DataProvider>();
    
    if (dataProvider.currentData == null) {
      _showError('No data loaded to update');
      return;
    }

    final success = await dataProvider.updateData(
      id: _idController.text.trim(),
      name: _nameController.text.trim(),
      message: _messageController.text.trim(),
    );

    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted && dataProvider.errorMessage != null) {
      _showError(dataProvider.errorMessage!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearData() {
    context.read<DataProvider>().clearCurrentData();
    setState(() {
      _nameController.clear();
      _messageController.clear();
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.enableEdit ? 'Update Data' : 'View Data'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (context.watch<DataProvider>().currentData != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearData,
              tooltip: 'Clear',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Search by ID',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _idController,
                            decoration: const InputDecoration(
                              labelText: 'Data ID',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              hintText: 'Enter data ID',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Consumer<DataProvider>(
                          builder: (context, data, child) {
                            final isLoading = data.state == DataState.loading;
                            return ElevatedButton(
                              onPressed: isLoading ? null : _searchData,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 24,
                                ),
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Data Display Section
            Consumer<DataProvider>(
              builder: (context, dataProvider, child) {
                final data = dataProvider.currentData;
                
                if (data == null) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Enter a data ID to search',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Data Details',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.enableEdit && !_isEditing)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // ID Field (read-only)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'ID: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: SelectableText(
                                  data.id ?? 'N/A',
                                  style: const TextStyle(fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Name Field
                        TextField(
                          controller: _nameController,
                          enabled: _isEditing,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            prefixIcon: const Icon(Icons.label_outline),
                            border: const OutlineInputBorder(),
                            filled: !_isEditing,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Message Field
                        TextField(
                          controller: _messageController,
                          enabled: _isEditing,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Message',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 60),
                              child: Icon(Icons.message_outlined),
                            ),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                            filled: !_isEditing,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                        
                        if (_isEditing) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                      _nameController.text = data.name;
                                      _messageController.text = data.message;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Consumer<DataProvider>(
                                  builder: (context, data, child) {
                                    final isLoading = data.state == DataState.loading;
                                    return ElevatedButton(
                                      onPressed: isLoading ? null : _updateData,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Save Changes'),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
