class PurchaseService {
  static final PurchaseService _instance = PurchaseService._();
  static PurchaseService get instance => _instance;
  PurchaseService._();

  bool get isPremium => false;

  Future<void> init() async {}
  Future<bool> purchase() async => false;
  Future<bool> restore() async => false;
}
