/// The fixture the Order placed demo is drawn from.
///
/// A confirmation's job is confirming *this* transaction, so the identifier
/// and the summary are the data — not the celebration. See
/// `docs/principles/screen-archetypes.md`, "Confirmation".
///
/// Delete this file with `order_placed_page.dart` when the app ships a real
/// checkout.
class OrderLine {
  const OrderLine({
    required this.title,
    required this.detail,
    required this.price,
  });

  final String title;

  /// The line under the title — a format, a size, a quantity.
  final String detail;

  /// Formatted, not a number: the screen states money the way the receipt
  /// does, and a currency the layout has never seen is how a total wraps.
  final String price;
}

class DemoOrder {
  const DemoOrder({
    required this.reference,
    required this.lines,
    required this.total,
    required this.paidWith,
    required this.arrives,
    required this.emailedTo,
    required this.cancelUntil,
  });

  /// The one thing that makes this screen about this order. Selectable on the
  /// page: a number the reader cannot copy is one they photograph.
  final String reference;

  final List<OrderLine> lines;
  final String total;
  final String paidWith;

  /// Dated, never "soon". A confirmation whose next step has no date is a
  /// receipt, and the reader comes back to the app to ask the question it
  /// declined to answer.
  final String arrives;

  final String emailedTo;

  /// The undo window, named here and nowhere else.
  final String cancelUntil;
}

const demoOrder = DemoOrder(
  reference: 'RS-4821',
  lines: [
    OrderLine(
      title: 'Rocketship Notebook',
      detail: 'A5 · dotted · 2',
      price: '£24.00',
    ),
    OrderLine(title: 'Ink refill', detail: 'Black · 1', price: '£10.98'),
  ],
  total: '£34.98',
  paidWith: 'Visa ending 4242',
  arrives: 'Arrives Thursday 12 March',
  emailedTo: 'ada@rocketship.dev',
  cancelUntil: 'You can cancel this order until 6pm today',
);
