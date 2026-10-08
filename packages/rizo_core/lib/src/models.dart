// Models for the RIZO Service API. Field names match the JSON the server sends (see client/src/lib/types.ts).

typedef Json = Map<String, dynamic>;

String? _s(Object? v) => v?.toString();
String _str(Object? v, [String d = '']) => v == null ? d : v.toString();
int _int(Object? v, [int d = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? d : d);
double _dbl(Object? v, [double d = 0]) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? d : d);
bool _bool(Object? v, [bool d = false]) => v is bool ? v : d;
DateTime? _dt(Object? v) => v is String ? DateTime.tryParse(v) : null;
Json _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Json> _list(Object? v) => v is List ? v.map(_map).toList() : <Json>[];

/// An item with translated names (products, services, parts, categories ...).
class Named {
  const Named(this.name, {this.nameUz, this.nameRu, this.nameEn});
  factory Named.fromJson(Object? json) {
    final m = _map(json);
    return Named(_str(m['name']), nameUz: _s(m['nameUz']), nameRu: _s(m['nameRu']), nameEn: _s(m['nameEn']));
  }
  final String name;
  final String? nameUz;
  final String? nameRu;
  final String? nameEn;

  String localized(String locale) {
    final v = switch (locale) { 'uz' => nameUz, 'ru' => nameRu, 'en' => nameEn, _ => null };
    return (v != null && v.isNotEmpty) ? v : name;
  }
}

class StaffUser {
  StaffUser({required this.id, required this.name, required this.phone, required this.role, this.technicianType, this.isAvailable = true, this.locale = 'uz'});
  factory StaffUser.fromJson(Object? json) {
    final m = _map(json);
    return StaffUser(
      id: _str(m['id']),
      name: _str(m['name']),
      phone: _str(m['phone']),
      role: _str(m['role'], 'technician'),
      technicianType: _s(m['technicianType']),
      isAvailable: _bool(m['isAvailable'], true),
      locale: _str(m['locale'], 'uz'),
    );
  }
  final String id;
  final String name;
  final String phone;
  final String role; // admin | technician | receptionist | accountant | warehouse
  final String? technicianType; // mobile | service_center
  final bool isAvailable;
  final String locale;

  bool get isTechnician => role == 'technician';
  bool get isAdmin => role == 'admin';
  bool get isReceptionist => role == 'receptionist';

  /// Accountants and warehouse managers work on the website; the app is for technicians, the front desk and admins.
  bool get usesApp => isTechnician || isAdmin || isReceptionist;
}

class CustomerUser {
  CustomerUser({required this.id, required this.name, required this.phone, this.address, this.locale = 'uz', this.preferredChannel = 'both', this.telegramLinked = false, this.deletionRequested = false});
  factory CustomerUser.fromJson(Object? json) {
    final m = _map(json);
    return CustomerUser(
      id: _str(m['id']),
      name: _str(m['name']),
      phone: _str(m['phone']),
      address: _s(m['address']),
      locale: _str(m['locale'], 'uz'),
      preferredChannel: _str(m['preferredChannel'], 'both'),
      telegramLinked: _bool(m['telegramLinked']),
      deletionRequested: _bool(m['deletionRequested']),
    );
  }
  final String id;
  final String name;
  final String phone;
  final String? address;
  final String locale;

  /// sms | telegram | both
  final String preferredChannel;
  final bool telegramLinked;
  final bool deletionRequested;
}

class PersonRef {
  PersonRef({required this.id, required this.name, required this.phone, this.address});
  factory PersonRef.fromJson(Object? json) {
    final m = _map(json);
    return PersonRef(id: _str(m['id']), name: _str(m['name']), phone: _str(m['phone']), address: _s(m['address']));
  }
  final String id;
  final String name;
  final String phone;
  final String? address;
}

class ProductRef {
  ProductRef({required this.id, required this.names, required this.sku, required this.category});
  factory ProductRef.fromJson(Object? json) {
    final m = _map(json);
    return ProductRef(id: _str(m['id']), names: Named.fromJson(m), sku: _str(m['sku']), category: _str(m['category']));
  }
  final String id;
  final Named names;
  final String sku;
  final String category;
  String name(String locale) => names.localized(locale);
}

class MoneySummary {
  const MoneySummary({this.due = 0, this.paid = 0, this.refunded = 0, this.balance = 0});
  factory MoneySummary.fromJson(Object? json) {
    final m = _map(json);
    return MoneySummary(due: _dbl(m['due']), paid: _dbl(m['paid']), refunded: _dbl(m['refunded']), balance: _dbl(m['balance']));
  }
  final double due;
  final double paid;
  final double refunded;
  final double balance;
}

class GeoLocation {
  GeoLocation({required this.address, this.lat, this.lng});
  factory GeoLocation.fromJson(Object? json) {
    final m = _map(json);
    return GeoLocation(address: _str(m['address']), lat: m['lat'] is num ? (m['lat'] as num).toDouble() : null, lng: m['lng'] is num ? (m['lng'] as num).toDouble() : null);
  }
  final String address;
  final double? lat;
  final double? lng;
  Uri get mapsUri => lat != null && lng != null
      ? Uri.parse('https://www.google.com/maps?q=$lat,$lng')
      : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
}

class ActivePause {
  ActivePause({required this.id, required this.reason, required this.pausedAt, required this.hours});
  factory ActivePause.fromJson(Object? json) {
    final m = _map(json);
    return ActivePause(id: _str(m['id']), reason: _str(m['reason']), pausedAt: _dt(m['pausedAt']) ?? DateTime.now(), hours: _dbl(m['customTimerHours']));
  }
  final String id;
  final String reason;
  final DateTime pausedAt;
  final double hours;
}

class JobTimer {
  JobTimer({required this.startsAt, required this.durationMs});
  factory JobTimer.fromJson(Object? json) {
    final m = _map(json);
    return JobTimer(startsAt: _dt(m['startsAt']) ?? DateTime.now(), durationMs: _int(m['durationMs']));
  }
  final DateTime startsAt;
  final int durationMs;
  DateTime get endsAt => startsAt.add(Duration(milliseconds: durationMs));
}

/// A service request as staff see it (the same shape serves the admin lists and the technician board).
class Job {
  Job(this.raw)
      : id = _str(raw['id']),
        displayId = _str(raw['displayId']),
        type = _str(raw['type'], 'repair'),
        status = _str(raw['status'], 'new'),
        priority = _str(raw['priority'], 'medium'),
        locationType = _str(raw['locationType'], 'in_shop'),
        warrantyStatus = _str(raw['warrantyStatus'], 'not_applicable'),
        issueDescription = _str(raw['issueDescription']),
        decision = _s(raw['decision']),
        column = _s(raw['column']),
        serialNumber = _s(raw['serialNumber']),
        customer = PersonRef.fromJson(raw['customer']),
        product = ProductRef.fromJson(raw['product']),
        customerLocation = raw['customerLocation'] is Map ? GeoLocation.fromJson(raw['customerLocation']) : null,
        timer = raw['timer'] is Map ? JobTimer.fromJson(raw['timer']) : null,
        activePause = raw['activePause'] is Map ? ActivePause.fromJson(raw['activePause']) : null,
        payment = MoneySummary.fromJson(raw['payment']),
        scheduledAt = _dt(raw['scheduledAt']),
        enRouteAt = _dt(raw['enRouteAt']),
        etaMinutes = raw['etaMinutes'] is num ? (raw['etaMinutes'] as num).toInt() : null,
        visitSlot = _s(raw['visitSlot']),
        visitConfirmed = _dt(raw['visitConfirmedAt']) != null,
        escalationLevel = _int(raw['escalationLevel']),
        arrivedAt = _dt(raw['arrivedAt']),
        createdAt = _dt(raw['createdAt']),
        completedAt = _dt(raw['completedAt']),
        statusChangedAt = _dt(raw['statusChangedAt']),
        pickupConfirmedAt = _dt(raw['pickupConfirmedAt']),
        isOverdue = _bool(raw['isOverdue']),
        isLegallyOverdue = _bool(raw['isLegallyOverdue']),
        isRepeat = _bool(raw['isRepeat']),
        isPaidRepair = _bool(raw['isPaidRepair']),
        defectCodeId = _s(raw['defectCodeId']),
        assignedTechnicianId = _s(raw['assignedTechnicianId']),
        assignedTechnicianName = raw['assignedTechnician'] is Map ? _s((raw['assignedTechnician'] as Map)['name']) : null,
        estimateStatus = raw['estimate'] is Map ? _s((raw['estimate'] as Map)['status']) : null,
        rejectionReason = _s(raw['rejectionReason']),
        trackingToken = _s(raw['trackingToken']),
        paymentStatus = _str(raw['paymentStatus'], 'not_required'),
        serviceCenterName = raw['serviceCenter'] is Map ? _s((raw['serviceCenter'] as Map)['name']) : null,
        legalDueAt = _dt(raw['legalDueAt']),
        estimatedCost = raw['estimatedCost'] is num ? (raw['estimatedCost'] as num).toDouble() : null,
        finalCost = raw['finalCost'] is num ? (raw['finalCost'] as num).toDouble() : null,
        resolutionType = _s(raw['resolutionType']),
        technicianTypeRequired = _str(raw['technicianTypeRequired'], 'mobile');

  factory Job.fromJson(Object? json) => Job(_map(json));

  final Json raw;
  final String id;
  final String displayId;
  final String type;
  final String status;
  final String priority;
  final String locationType;
  final String warrantyStatus;
  final String issueDescription;
  final String? decision;
  final String? column;
  final String? serialNumber;
  final PersonRef customer;
  final ProductRef product;
  final GeoLocation? customerLocation;
  final JobTimer? timer;
  final ActivePause? activePause;
  final MoneySummary payment;
  final DateTime? scheduledAt;
  final DateTime? enRouteAt;
  final int? etaMinutes;
  final String? visitSlot;
  final bool visitConfirmed;
  final int escalationLevel;
  final DateTime? arrivedAt;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final DateTime? statusChangedAt;
  final DateTime? pickupConfirmedAt;
  final bool isOverdue;
  final bool isLegallyOverdue;
  final bool isRepeat;
  final bool isPaidRepair;
  final String? defectCodeId;
  final String? assignedTechnicianId;
  final String? assignedTechnicianName;
  final String? estimateStatus;
  final String? rejectionReason;
  final String? trackingToken;
  final String paymentStatus;
  final String? serviceCenterName;
  final DateTime? legalDueAt;
  final double? estimatedCost;
  final double? finalCost;
  final String? resolutionType;
  final String technicianTypeRequired;

  bool get isRepair => type == 'repair';
  bool get isOnSite => locationType == 'on_site';
}

class EstimateLine {
  EstimateLine(Json m)
      : id = _str(m['id']),
        kind = _str(m['kind'], 'service'),
        name = _str(m['name']),
        names = m['names'] is Map ? Named.fromJson(m['names']) : null,
        quantity = _int(m['quantity'], 1),
        unitPrice = _dbl(m['unitPrice']),
        isOptional = _bool(m['isOptional']),
        isSelected = _bool(m['isSelected'], true),
        isFulfilled = _bool(m['isFulfilled'], true);
  final String id;
  final String kind;
  final String name;
  final Named? names;
  final int quantity;
  final double unitPrice;
  final bool isOptional;
  final bool isSelected;
  final bool isFulfilled;
  double get total => quantity * unitPrice;
  String label(String locale) => names?.localized(locale) ?? name;
}

class Estimate {
  Estimate(Json m)
      : id = _str(m['id']),
        status = _str(m['status'], 'draft'),
        note = _s(m['note']),
        validUntil = _dt(m['validUntil']),
        sentAt = _dt(m['sentAt']),
        approvedAt = _dt(m['approvedAt']),
        approvedBy = _s(m['approvedBy']),
        declineReason = _s(m['declineReason']),
        canRespond = _bool(m['canRespond']),
        total = _dbl(m['total']),
        lines = _list(m['lines']).map(EstimateLine.new).toList();
  final String id;
  final String status;
  final String? note;
  final DateTime? validUntil;
  final DateTime? sentAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? declineReason;
  final bool canRespond;
  final double total;
  final List<EstimateLine> lines;
}

class NoteRow {
  NoteRow(Json m)
      : id = _str(m['id']),
        text = _str(m['text']),
        authorScope = _str(m['authorScope'], 'staff'),
        authorName = _s(m['authorName']),
        isVisibleToCustomer = _bool(m['isVisibleToCustomer']),
        createdAt = _dt(m['createdAt']);
  final String id;
  final String text;
  final String authorScope;
  final String? authorName;
  final bool isVisibleToCustomer;
  final DateTime? createdAt;
}

class PaymentRow {
  PaymentRow(Json m)
      : id = _str(m['id']),
        kind = _str(m['kind'], 'payment'),
        method = _str(m['method'], 'cash'),
        amount = _dbl(m['amount']),
        note = _s(m['note']),
        createdByName = _s(m['createdByName']),
        createdAt = _dt(m['createdAt']);
  final String id;
  final String kind;
  final String method;
  final double amount;
  final String? note;
  final String? createdByName;
  final DateTime? createdAt;
}

class TimelineEvent {
  TimelineEvent(Json m)
      : key = _str(m['key']),
        kind = _str(m['kind']),
        at = _dt(m['at']),
        title = _str(m['title']),
        detail = _s(m['detail']),
        titleKey = _s(m['titleKey']),
        detailKey = _s(m['detailKey']),
        params = _map(m['params']);
  final String key;
  final String kind;
  final DateTime? at;
  final String title;
  final String? detail;
  final String? titleKey;
  final String? detailKey;
  final Json params;
}

class CatalogChoice {
  CatalogChoice(Json m)
      : id = _str(m['id']),
        names = Named.fromJson(m),
        price = _dbl(m['price']),
        stockQuantity = m['stockQuantity'] is num ? (m['stockQuantity'] as num).toInt() : null,
        carried = _int(m['carried']),
        lowStock = _bool(m['lowStock']);
  final String id;
  final Named names;
  final double price;
  final int? stockQuantity;

  /// How many the technician carries (van stock); used before the warehouse stock.
  final int carried;
  final bool lowStock;

  /// What can be used on a job right now.
  int get available => (stockQuantity ?? 0) + carried;
}

class DefectCode {
  DefectCode(Json m)
      : id = _str(m['id']),
        code = _str(m['code']),
        names = Named.fromJson(m);
  final String id;
  final String code;
  final Named names;
}

/// Everything about one job for the technician: lines, photos, estimates, catalog, cost, what is still missing.
class JobWork {
  JobWork(this.raw)
      : job = Job(_map(raw['job'])),
        serviceLines = _list(raw['serviceLines']),
        partLines = _list(raw['partLines']),
        extraExpenses = _list(raw['extraExpenses']),
        photos = _list(raw['photos']),
        estimates = _list(raw['estimates']).map(Estimate.new).toList(),
        defectCodes = _list(raw['defectCodes']).map(DefectCode.new).toList(),
        partOrders = _list(raw['partOrders']),
        notes = _list(raw['notes']).map(NoteRow.new).toList(),
        timeline = _list(raw['timeline']).map(TimelineEvent.new).toList(),
        cost = _map(raw['cost']),
        canComplete = _bool(raw['canComplete']),
        missing = (raw['missing'] is List ? (raw['missing'] as List).map((e) => e.toString()).toList() : <String>[]),
        decision = _s(raw['decision']),
        resolutionType = _s(raw['resolutionType']),
        replacement = raw['replacement'] is Map ? _map(raw['replacement']) : null,
        catalogServices = _list(_map(raw['catalog'])['services']).map(CatalogChoice.new).toList(),
        catalogParts = _list(_map(raw['catalog'])['parts']).map(CatalogChoice.new).toList(),
        replacementProducts = _list(_map(raw['catalog'])['replacementProducts']).map(ProductRef.fromJson).toList(),
        checklist = JobChecklist(_map(raw['checklist'])),
        blockZeroStock = _bool(_map(raw['settings'])['blockZeroStock'], true);

  final Json raw;
  final Job job;
  final List<Json> serviceLines;
  final List<Json> partLines;
  final List<Json> extraExpenses;
  final List<Json> photos;
  final List<Estimate> estimates;
  final List<DefectCode> defectCodes;
  final List<Json> partOrders;
  final List<NoteRow> notes;
  final List<TimelineEvent> timeline;
  final Json cost;
  final bool canComplete;
  final List<String> missing;
  final String? decision;
  final String? resolutionType;
  final Json? replacement;
  final List<CatalogChoice> catalogServices;
  final List<CatalogChoice> catalogParts;
  final List<ProductRef> replacementProducts;
  final JobChecklist checklist;
  final bool blockZeroStock;

  double costValue(String key) => _dbl(cost[key]);
  bool get coveredByWarranty => _bool(cost['coveredByWarranty']);
  bool get isDone => (job.column ?? 'new') == 'completed';
}

class PortalEstimateLine {
  PortalEstimateLine(Json m)
      : id = _str(m['id']),
        name = _str(m['name']),
        names = m['names'] is Map ? Named.fromJson(m['names']) : null,
        quantity = _int(m['quantity'], 1),
        unitPrice = _dbl(m['unitPrice']),
        isOptional = _bool(m['isOptional']),
        isSelected = _bool(m['isSelected'], true);
  final String id;
  final String name;
  final Named? names;
  final int quantity;
  final double unitPrice;
  final bool isOptional;
  final bool isSelected;
  String label(String locale) => names?.localized(locale) ?? name;
}

class PortalEstimate {
  PortalEstimate(Json m)
      : id = _str(m['id']),
        status = _str(m['status'], 'sent'),
        validUntil = _dt(m['validUntil']),
        note = _s(m['note']),
        canRespond = _bool(m['canRespond']),
        total = _dbl(m['total']),
        lines = _list(m['lines']).map(PortalEstimateLine.new).toList();
  final String id;
  final String status;
  final DateTime? validUntil;
  final String? note;
  final bool canRespond;
  final double total;
  final List<PortalEstimateLine> lines;
}

class PortalMessage {
  PortalMessage(Json m)
      : id = _str(m['id']),
        text = _str(m['text']),
        fromCustomer = _bool(m['fromCustomer']),
        createdAt = _dt(m['createdAt']);
  final String id;
  final String text;
  final bool fromCustomer;
  final DateTime? createdAt;
}

class ServiceCenter {
  ServiceCenter(Json m)
      : id = _str(m['id']),
        name = _str(m['name']),
        address = _str(m['address']),
        phone = _s(m['phone']),
        workingHours = _s(m['workingHours']),
        lat = m['lat'] is num ? (m['lat'] as num).toDouble() : null,
        lng = m['lng'] is num ? (m['lng'] as num).toDouble() : null,
        isAuthorized = _bool(m['isAuthorized']);
  final String id;
  final String name;
  final String address;
  final String? phone;
  final String? workingHours;
  final double? lat;
  final double? lng;
  final bool isAuthorized;
}

/// A booking window of a day and how many visits are still free in it.
class VisitSlot {
  VisitSlot(Json m)
      : slot = _str(m['slot']),
        free = _bool(m['free']),
        left = _int(m['left']);
  final String slot;
  final bool free;
  final int left;
}

/// What the customer can do about the visit of a request.
class VisitInfo {
  VisitInfo(Json m)
      : slot = _s(m['slot']),
        confirmed = _bool(m['confirmed']),
        canBook = _bool(m['canBook']),
        canReschedule = _bool(m['canReschedule']),
        canCancel = _bool(m['canCancel']);
  final String? slot;
  final bool confirmed;
  final bool canBook;
  final bool canReschedule;
  final bool canCancel;
}

/// Paid warranty extension on offer ("+12 months").
class WarrantyPlanInfo {
  WarrantyPlanInfo(Json m)
      : id = _str(m['id']),
        names = Named.fromJson(m),
        months = _int(m['months']),
        price = _dbl(m['price']);
  final String id;
  final Named names;
  final int months;
  final double price;
}

/// A self-help guide.
class HelpArticleInfo {
  HelpArticleInfo(Json m)
      : id = _str(m['id']),
        category = _s(m['productCategory']),
        title = _map(m['title']),
        body = _map(m['body']),
        videoUrl = _s(m['videoUrl']);
  final String id;
  final String? category;
  final Json title;
  final Json body;
  final String? videoUrl;

  static String _pick(Json m, String locale) {
    for (final k in [locale, 'uz', 'en', 'ru']) {
      final v = _str(m[k]);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String titleFor(String locale) => _pick(title, locale);
  String bodyFor(String locale) => _pick(body, locale);
}

/// A step the technician ticks off.
class ChecklistItem {
  ChecklistItem(Json m)
      : id = _str(m['id']),
        texts = {'uz': _str(m['uz']), 'ru': _str(m['ru']), 'en': _str(m['en'])},
        required = _bool(m['required']);
  final String id;
  final Map<String, String> texts;
  final bool required;
  String text(String locale) => (texts[locale] ?? '').isNotEmpty ? texts[locale]! : (texts['uz'] ?? texts['en'] ?? '');
}

/// The diagnosis and completion checklists of a job with what is ticked.
class JobChecklist {
  JobChecklist(Json m)
      : diagnosis = _list(_map(m['diagnosis'])['items']).map(ChecklistItem.new).toList(),
        diagnosisChecked = _strings(_map(m['diagnosis'])['checked']),
        completion = _list(_map(m['completion'])['items']).map(ChecklistItem.new).toList(),
        completionChecked = _strings(_map(m['completion'])['checked']);
  final List<ChecklistItem> diagnosis;
  final Set<String> diagnosisChecked;
  final List<ChecklistItem> completion;
  final Set<String> completionChecked;

  bool get isEmpty => diagnosis.isEmpty && completion.isEmpty;

  static Set<String> _strings(Object? v) => v is List ? v.map((e) => e.toString()).toSet() : <String>{};
}

/// A request as the customer sees it.
class PortalRequest {
  PortalRequest(this.raw)
      : id = _str(raw['id']),
        displayId = _str(raw['displayId']),
        type = _str(raw['type'], 'repair'),
        status = _str(raw['status'], 'new'),
        warrantyStatus = _str(raw['warrantyStatus'], 'not_applicable'),
        locationType = _str(raw['locationType'], 'in_shop'),
        issueDescription = _str(raw['issueDescription']),
        createdAt = _dt(raw['createdAt']),
        completedAt = _dt(raw['completedAt']),
        product = ProductRef.fromJson(raw['product']),
        technicianName = raw['assignedTechnician'] is Map ? _s((raw['assignedTechnician'] as Map)['name']) : null,
        feedbackRating = raw['feedback'] is Map ? _int((raw['feedback'] as Map)['rating']) : null,
        feedbackComment = raw['feedback'] is Map ? _s((raw['feedback'] as Map)['comment']) : null,
        feedbackTags = raw['feedback'] is Map && (raw['feedback'] as Map)['tags'] is List ? ((raw['feedback'] as Map)['tags'] as List).map((e) => e.toString()).toList() : const <String>[],
        canFeedback = _bool(raw['canFeedback']),
        pickupConfirmedAt = _dt(raw['pickupConfirmedAt']),
        canConfirmPickup = _bool(raw['canConfirmPickup']),
        serialNumber = _s(raw['serialNumber']),
        scheduledAt = _dt(raw['scheduledAt']),
        enRouteAt = _dt(raw['enRouteAt']),
        visit = VisitInfo(_map(raw['visit'])),
        etaMinutes = raw['eta'] is Map ? _int((raw['eta'] as Map)['minutes']) : null,
        dueBy = _dt(raw['dueBy']),
        repairWarrantyUntil = _s(raw['repairWarrantyUntil']),
        rejectionReason = _s(raw['rejectionReason']),
        serviceCenter = raw['serviceCenter'] is Map ? ServiceCenter(_map(raw['serviceCenter'])) : null,
        trackingToken = _str(raw['trackingToken']),
        payment = MoneySummary.fromJson(raw['payment']),
        estimate = raw['estimate'] is Map ? PortalEstimate(_map(raw['estimate'])) : null,
        messages = _list(raw['messages']).map(PortalMessage.new).toList(),
        saleInvoice = raw['sale'] is Map ? _s((raw['sale'] as Map)['invoiceNumber']) : null,
        saleWarrantyExpiry = raw['sale'] is Map ? _s((raw['sale'] as Map)['warrantyExpiry']) : null,
        saleWarrantyStatus = raw['sale'] is Map ? _s((raw['sale'] as Map)['warrantyStatus']) : null;

  final Json raw;
  final String id;
  final String displayId;
  final String type;
  final String status;
  final String warrantyStatus;
  final String locationType;
  final String issueDescription;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final ProductRef product;
  final String? technicianName;
  final int? feedbackRating;
  final String? feedbackComment;
  final List<String> feedbackTags;
  final bool canFeedback;
  final DateTime? pickupConfirmedAt;
  final bool canConfirmPickup;
  final String? serialNumber;
  final DateTime? scheduledAt;
  final DateTime? enRouteAt;
  final VisitInfo visit;
  final int? etaMinutes;
  final DateTime? dueBy;
  final String? repairWarrantyUntil;
  final String? rejectionReason;
  final ServiceCenter? serviceCenter;
  final String trackingToken;
  final MoneySummary payment;
  final PortalEstimate? estimate;
  final List<PortalMessage> messages;
  final String? saleInvoice;
  final String? saleWarrantyExpiry;
  final String? saleWarrantyStatus;
}

class PortalSale {
  PortalSale(Json m)
      : id = _str(m['id']),
        invoiceNumber = _str(m['invoiceNumber']),
        saleDate = _str(m['saleDate']),
        warrantyExpiry = _str(m['warrantyExpiry']),
        warrantyStatus = _str(m['warrantyStatus'], 'not_applicable'),
        serialNumber = _s(m['serialNumber']),
        isVerified = _bool(m['isVerified'], true),
        warrantyDaysLeft = m['warrantyDaysLeft'] is num ? (m['warrantyDaysLeft'] as num).toInt() : null,
        voided = _bool(m['voided']),
        product = ProductRef.fromJson(m['product']);
  final int? warrantyDaysLeft;
  final bool voided;
  final String id;
  final String invoiceNumber;
  final String saleDate;
  final String warrantyExpiry;
  final String warrantyStatus;
  final String? serialNumber;
  final bool isVerified;
  final ProductRef product;
}

class AlertItem {
  AlertItem(Json m)
      : id = _str(m['id']),
        requestId = _s(m['serviceRequestId']),
        message = _str(m['message']),
        code = _s(m['code']),
        params = _map(m['params']),
        isRead = _bool(m['isRead']),
        createdAt = _dt(m['createdAt']);
  final String id;
  final String? requestId;
  final String message;
  final String? code;
  final Json params;
  final bool isRead;
  final DateTime? createdAt;
}

class TechnicianInfo {
  TechnicianInfo(Json m)
      : id = _str(m['id']),
        name = _str(m['name']),
        phone = _str(m['phone']),
        technicianType = _s(m['technicianType']),
        isAvailable = _bool(m['isAvailable'], true),
        openJobCount = _int(m['openJobCount']);
  final String id;
  final String name;
  final String phone;
  final String? technicianType;
  final bool isAvailable;
  final int openJobCount;
}

class PartOrderRow {
  PartOrderRow(Json m)
      : id = _str(m['id']),
        quantity = _int(m['quantity'], 1),
        status = _str(m['status'], 'requested'),
        supplier = _s(m['supplier']),
        part = Named.fromJson(m['part']),
        stock = _int(_map(m['part'])['stockQuantity']),
        requestDisplayId = m['request'] is Map ? _s((m['request'] as Map)['displayId']) : null,
        requestId = m['request'] is Map ? _s((m['request'] as Map)['id']) : null,
        createdAt = _dt(m['createdAt']);
  final String id;
  final int quantity;
  final String status;
  final String? supplier;
  final Named part;
  final int stock;
  final String? requestDisplayId;
  final String? requestId;
  final DateTime? createdAt;
}

class DashboardData {
  DashboardData(this.raw)
      : totals = _map(raw['totals']),
        previous = raw['previous'] is Map ? _map(raw['previous']) : null,
        service = _map(raw['service']),
        byStatus = _list(raw['byStatus']),
        topProducts = _list(raw['topProducts']),
        warrantySplit = _map(raw['warrantySplit']);
  final Json raw;
  final Json totals;

  /// First-time fix, callbacks, callback cost and waiting times (see ServiceKpis on the website).
  final Json service;
  final Json? previous;
  final List<Json> byStatus;
  final List<Json> topProducts;
  final Json warrantySplit;
  double total(String key) => _dbl(totals[key]);
  double? totalOrNull(String key) => totals[key] is num ? (totals[key] as num).toDouble() : null;
}

/// Small helpers for reading raw JSON in the apps.
Json asMap(Object? v) => _map(v);
List<Json> asList(Object? v) => _list(v);
String asString(Object? v, [String d = '']) => _str(v, d);
double asDouble(Object? v, [double d = 0]) => _dbl(v, d);
int asInt(Object? v, [int d = 0]) => _int(v, d);
DateTime? asDate(Object? v) => _dt(v);
