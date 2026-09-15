import 'package:flutter_starter/app/services/domain/api_service.dart';

import 'notes_api_const.dart';

/// Style-A: the Repo picks the endpoint, the Impl only does HTTP.
abstract class NotesApiService {
  Future getChanges(String url, {Map<String, dynamic>? params});
  Future postOp(String url, Map<String, dynamic> params);
}

class NotesImpl extends NotesApiService {
  @override
  Future getChanges(String url, {Map<String, dynamic>? params}) async {
    final dynamic response = await ApiService().get(url, params: params);
    return response;
  }

  @override
  Future postOp(String url, Map<String, dynamic> params) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }
}

class NotesRepo {
  final NotesApiService notesApiService = NotesImpl();

  /// Returns the raw Dio Response, not `response.data`: the sync transport has
  /// to read `statusCode` to tell a 409 conflict from a 500.
  Future<dynamic> fetchChanges({
    DateTime? since,
    String? cursor,
    int limit = 200,
  }) {
    final params = <String, dynamic>{'limit': limit};
    if (since != null) params['since'] = since.toUtc().toIso8601String();
    if (cursor != null) params['cursor'] = cursor;
    return notesApiService.getChanges(NotesApiConst.pullUri, params: params);
  }

  /// `body` already carries `op_id` — the idempotency key.
  Future<dynamic> pushOp(Map<String, dynamic> body) =>
      notesApiService.postOp(NotesApiConst.pushUri, body);
}
