import 'package:flutter_starter/app/services/domain/api_const.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

/// Abstract class for Location API Service
abstract class LocationApiService {
  Future getParishes();
  Future getCitiesByParish(String parishId);
  Future getZonesByCity(String cityId);
}

/// Implementation of LocationApiService
class LocationImpl extends LocationApiService {
  @override
  Future getParishes() async {
    return await ApiService(logisticsBaseUrl: true).get(
      ApiConstant.parishesUri,
      params: {'page': 1, 'limit': 100},
    );
  }

  @override
  Future getCitiesByParish(String parishId) async {
    return await ApiService(logisticsBaseUrl: true).get(
      ApiConstant.citiesInParish(parishId),
      params: {'page': 1, 'limit': 100},
    );
  }

  @override
  Future getZonesByCity(String cityId) async {
    return await ApiService(logisticsBaseUrl: true).get(
      ApiConstant.zonesInCity(cityId),
      params: {'page': 1, 'limit': 100},
    );
  }
}

/// Repository for Location
class LocationRepo {
  final LocationApiService _api = LocationImpl();

  Future<List<Map<String, dynamic>>> fetchParishes() async {
    final response = await _api.getParishes();
    if (response != null && response.data != null) {
      final data = response.data;
      if (data['status'] == true && data['data'] != null) {
        final items = data['data']['items'] as List;
        return items.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchCitiesByParish(String parishId) async {
    final response = await _api.getCitiesByParish(parishId);
    if (response != null && response.data != null) {
      final data = response.data;
      if (data['status'] == true && data['data'] != null) {
        final rawData = data['data'];
        final List items = rawData is List ? rawData : (rawData['items'] as List? ?? []);
        return items.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchZonesByCity(String cityId) async {
    final response = await _api.getZonesByCity(cityId);
    if (response != null && response.data != null) {
      final data = response.data;
      if (data['status'] == true && data['data'] != null) {
        final rawData = data['data'];
        final List items = rawData is List ? rawData : (rawData['items'] as List? ?? []);
        return items.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }
}
