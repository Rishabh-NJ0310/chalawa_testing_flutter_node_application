import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

enum DataState {
  initial,
  loading,
  loaded,
  error,
}

class DataProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  DataState _state = DataState.initial;
  String? _errorMessage;
  DataModel? _currentData;
  final List<DataModel> _dataList = [];

  DataState get state => _state;
  String? get errorMessage => _errorMessage;
  DataModel? get currentData => _currentData;
  List<DataModel> get dataList => _dataList;

  /// Get data by ID
  Future<bool> getDataById(String id) async {
    try {
      _state = DataState.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _apiService.getDataById(id);

      if (result.success && result.data != null) {
        _currentData = result.data;
        _state = DataState.loaded;
        notifyListeners();
        return true;
      }

      _errorMessage = result.error ?? 'Data not found';
      _state = DataState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = DataState.error;
      notifyListeners();
      return false;
    }
  }

  /// Add new data
  Future<bool> addData({
    required String name,
    required String message,
  }) async {
    try {
      _state = DataState.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _apiService.addData(
        name: name,
        message: message,
      );

      if (result.success) {
        final newData = DataModel(
          id: result.data?['id']?.toString() ?? result.data?['data']?['id']?.toString(),
          name: name,
          message: message,
        );
        _dataList.add(newData);
        _currentData = newData;
        _state = DataState.loaded;
        notifyListeners();
        return true;
      }

      _errorMessage = result.error;
      _state = DataState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = DataState.error;
      notifyListeners();
      return false;
    }
  }

  /// Update data by ID
  Future<bool> updateData({
    required String id,
    required String name,
    required String message,
  }) async {
    try {
      _state = DataState.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _apiService.updateData(
        id: id,
        name: name,
        message: message,
      );

      if (result.success) {
        final updatedData = DataModel(
          id: id,
          name: name,
          message: message,
        );
        
        // Update in list if exists
        final index = _dataList.indexWhere((d) => d.id == id);
        if (index != -1) {
          _dataList[index] = updatedData;
        }
        
        _currentData = updatedData;
        _state = DataState.loaded;
        notifyListeners();
        return true;
      }

      _errorMessage = result.error;
      _state = DataState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = DataState.error;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    if (_state == DataState.error) {
      _state = DataState.initial;
    }
    notifyListeners();
  }

  void clearCurrentData() {
    _currentData = null;
    notifyListeners();
  }
}
