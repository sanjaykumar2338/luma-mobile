import 'api_client.dart';
import 'models.dart';
import 'sermon_companion_models.dart';

dynamic companionData(dynamic response) => response is Map && response['data'] != null ? response['data'] : response;

class SermonCompanionApi {
  const SermonCompanionApi(this.client);
  final ApiClient client;

  Future<List<SermonCompanion>> list() async {
    final response = await client.request('/sermon-companions', auth: true);
    final data = companionData(response);
    final list = data is Map ? data['data'] : data;
    return listValue(list).whereType<Map>().map((item) => SermonCompanion.fromJson(item.cast<String, dynamic>())).toList();
  }

  Future<SermonCompanion> create({required String title, String? speaker, String? churchName, String? sermonDate, String? youtubeUrl, String personalNotes = '', List<String> scriptureReferences = const []}) async {
    final response = await client.request('/sermon-companions', method: 'POST', auth: true, body: {'title': title, if (speaker?.trim().isNotEmpty == true) 'speaker': speaker!.trim(), if (churchName?.trim().isNotEmpty == true) 'church_name': churchName!.trim(), if (sermonDate?.trim().isNotEmpty == true) 'sermon_date': sermonDate!.trim(), if (youtubeUrl?.trim().isNotEmpty == true) 'youtube_url': youtubeUrl!.trim(), if (personalNotes.trim().isNotEmpty) 'personal_notes': personalNotes.trim(), if (scriptureReferences.isNotEmpty) 'scripture_references': scriptureReferences});
    return SermonCompanion.fromJson((companionData(response) as Map).cast<String, dynamic>());
  }

  Future<SermonCompanion> detail(int id) async {
    final response = await client.request('/sermon-companions/$id', auth: true);
    return SermonCompanion.fromJson((companionData(response) as Map).cast<String, dynamic>());
  }

  Future<SermonCompanion> update(int id, Map<String, dynamic> body) async {
    final response = await client.request('/sermon-companions/$id', method: 'PATCH', auth: true, body: body);
    return SermonCompanion.fromJson((companionData(response) as Map).cast<String, dynamic>());
  }

  Future<SermonCompanion> upload(int id, String path, String kind) async {
    final response = await client.uploadSermonCompanionAttachment(companionId: id, filePath: path, kind: kind);
    return SermonCompanion.fromJson((companionData(response) as Map).cast<String, dynamic>());
  }

  Future<SermonCompanion> queueRecap(int id) async {
    final response = await client.request('/sermon-companions/$id/recap', method: 'POST', auth: true, idempotencyKey: 'mobile-companion-$id-recap-v1');
    return detailFrom(response);
  }

  Future<SermonCompanionPlan> queuePlan(int id, int days) async {
    final response = await client.request('/sermon-companions/$id/devotional-plans', method: 'POST', auth: true, body: {'days_count': days}, idempotencyKey: 'mobile-companion-$id-plan-$days-v1');
    return SermonCompanionPlan.fromJson((companionData(response) as Map).cast<String, dynamic>());
  }

  SermonCompanion detailFrom(dynamic response) => SermonCompanion.fromJson((companionData(response) as Map).cast<String, dynamic>());

  Future<List<SermonCompanionDay>> days(int planId) async {
    final response = await client.request('/sermon-companion-plans/$planId/days', auth: true);
    final data = companionData(response);
    final list = data is Map ? data['data'] : data;
    return listValue(list).whereType<Map>().map((item) => SermonCompanionDay.fromJson(item.cast<String, dynamic>())).toList();
  }

  Future<SermonCompanionDay> completeDay(int dayId) async {
    final response = await client.request('/sermon-companion-days/$dayId/complete', method: 'POST', auth: true);
    return SermonCompanionDay.fromJson((companionData(response) as Map).cast<String, dynamic>());
  }

  Future<List<SermonCompanionJournalEntry>> journal(int id) async {
    final response = await client.request('/sermon-companions/$id/journal', auth: true);
    final data = companionData(response);
    final list = data is Map ? data['data'] : data;
    return listValue(list).whereType<Map>().map((item) => SermonCompanionJournalEntry.fromJson(item.cast<String, dynamic>())).toList();
  }

  Future<SermonCompanionJournalEntry> saveJournal(int id, {required String entryType, required String content, required String clientKey, int? dayId}) async {
    final response = await client.request('/sermon-companions/$id/journal', method: 'POST', auth: true, body: {'entry_type': entryType, 'content': content, 'client_key': clientKey, if (dayId != null) 'devotional_day_id': dayId});
    return SermonCompanionJournalEntry.fromJson((companionData(response) as Map).cast<String, dynamic>());
  }

  Future<List<SermonCompanionMemoryCard>> memoryCards(int id) async {
    final response = await client.request('/sermon-companions/$id/memory-cards', auth: true);
    final data = companionData(response);
    final list = data is Map ? data['data'] : data;
    return listValue(list).whereType<Map>().map((item) => SermonCompanionMemoryCard.fromJson(item.cast<String, dynamic>())).toList();
  }

  Future<SermonCompanionMemoryCard> practiceMemory(int cardId, bool completed) async {
    final response = await client.request('/sermon-companion-memory-cards/$cardId/practice', method: 'POST', auth: true, body: {'completed': completed});
    return SermonCompanionMemoryCard.fromJson((companionData(response) as Map).cast<String, dynamic>());
  }
}
