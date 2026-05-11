class DocumentTable {
  String type; // 'text' or 'price'
  List<List<String>> cells;
  double vatRate; // For price tables (default 15%)

  DocumentTable({
    this.type = 'text',
    List<List<String>>? cells,
    this.vatRate = 0.15,
  }) : cells = cells ??
            [
              ['Header 1', 'Header 2', 'Header 3'],
              ['Row 1 Col 1', 'Row 1 Col 2', 'Row 1 Col 3'],
              ['Row 2 Col 1', 'Row 2 Col 2', 'Row 2 Col 3'],
            ];

  factory DocumentTable.priceTable({double vatRate = 0.15}) {
    return DocumentTable(
      type: 'price',
      vatRate: vatRate,
      cells: [
        ['Item', 'Description', 'Quantity', 'Unit Price', 'Total'],
        ['', '', '1', '0.00', '0.00'],
        ['', '', '1', '0.00', '0.00'],
      ],
    );
  }

  void addRow() {
    final newRow = List.generate(cells[0].length, (_) => '');
    cells.add(newRow);
  }

  void addColumn() {
    for (var row in cells) {
      row.add('');
    }
  }

  void removeRow(int index) {
    if (cells.length > 2 && index > 0) {
      // Keep at least header + 1 row
      cells.removeAt(index);
    }
  }

  void removeColumn(int index) {
    if (cells[0].length > 2) {
      // Keep at least 2 columns
      for (var row in cells) {
        if (index < row.length) {
          row.removeAt(index);
        }
      }
    }
  }

  double? _parseFirstNumber(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;

    // Prefer extracting a numeric token anywhere in the string.
    // Examples handled:
    // - "R 350" => 350
    // - "R {{350}}" => 350
    // - "2 Weeks" => 2
    // - "1,500.00" => 1500
    final match = RegExp(r'-?\d+(?:[\.,]\d+)?').firstMatch(v);
    if (match == null) return null;

    final token = match.group(0)!.replaceAll(',', '.');
    // If token contained thousands separators like 1,500.00, above replacement
    // could yield 1.500.00 which isn't parseable. Try a more conservative cleanup.
    final cleaned = token.contains('.')
        ? token.replaceAll(RegExp(r'\.(?=.*\.)'), '')
        : token;
    return double.tryParse(cleaned);
  }

  double _parseQuantity(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 0.0;

    final n = _parseFirstNumber(v) ?? 0.0;
    final lower = v.toLowerCase();

    // Content library commonly expresses effort as "X Weeks" but rates are day-based.
    // Interpret weeks as business days (1 week = 5 days).
    if (lower.contains('week') || RegExp(r'\bwk\b').hasMatch(lower)) {
      return n * 5.0;
    }

    return n;
  }

  int? _findHeaderIndex(List<String> headers, List<String> needles) {
    if (headers.isEmpty) return null;
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().trim();
      for (final n in needles) {
        if (h == n || h.contains(n)) return i;
      }
    }
    return null;
  }

  int _fallbackIndex(int? index, int fallback) {
    return index ?? fallback;
  }

  int getPriceQuantityColumnIndex() {
    final headers = cells.isNotEmpty ? cells[0] : <String>[];
    return _fallbackIndex(
      _findHeaderIndex(headers, ['quantity', 'qty', 'qnty', 'units']),
      2,
    );
  }

  int getPriceUnitPriceColumnIndex() {
    final headers = cells.isNotEmpty ? cells[0] : <String>[];
    return _fallbackIndex(
      _findHeaderIndex(headers, ['unit price', 'price', 'rate', 'unit cost']),
      3,
    );
  }

  int getPriceTotalColumnIndex() {
    final headers = cells.isNotEmpty ? cells[0] : <String>[];
    return _fallbackIndex(
      _findHeaderIndex(headers, ['total', 'amount', 'line total']),
      4,
    );
  }

  int getResolvedPriceTotalColumnIndex() {
    final base = getPriceTotalColumnIndex();
    if (cells.length < 2) return base;
    return _resolveNumericColumnIndex(cells[1], base);
  }

  int _resolveNumericColumnIndex(List<String> row, int preferredIndex) {
    if (preferredIndex < 0) return preferredIndex;
    if (preferredIndex >= row.length) return preferredIndex;

    final preferred = row[preferredIndex].trim();
    final preferredNumber = _parseFirstNumber(preferred);

    if (preferredNumber != null) {
      return preferredIndex;
    }

    // Common library-table pattern: a placeholder/label column followed by the numeric column.
    if (preferredIndex + 1 < row.length) {
      final next = row[preferredIndex + 1].trim();
      if (_parseFirstNumber(next) != null) {
        return preferredIndex + 1;
      }
    }

    return preferredIndex;
  }

  void recalculatePriceRowTotal(int rowIndex) {
    if (type != 'price') return;
    if (cells.isEmpty || rowIndex <= 0 || rowIndex >= cells.length) return;

    final qtyCol = getPriceQuantityColumnIndex();
    final unitCol = getPriceUnitPriceColumnIndex();
    final totalCol = getPriceTotalColumnIndex();

    final row = cells[rowIndex];
    if (row.isEmpty) return;

    final resolvedUnitCol = unitCol < row.length
        ? _resolveNumericColumnIndex(row, unitCol)
        : unitCol;
    final resolvedTotalCol = totalCol < row.length
        ? _resolveNumericColumnIndex(row, totalCol)
        : totalCol;

    if (row.length <= resolvedTotalCol) return;

    final qty = qtyCol < row.length ? _parseQuantity(row[qtyCol]) : 0.0;
    final unit = resolvedUnitCol < row.length
        ? (_parseFirstNumber(row[resolvedUnitCol]) ?? 0.0)
        : 0.0;

    row[resolvedTotalCol] = (qty * unit).toStringAsFixed(2);
  }

  double getSubtotal() {
    if (type != 'price' || cells.length < 2) return 0.0;

    final headers = cells.isNotEmpty ? cells[0] : <String>[];
    final qtyCol = _fallbackIndex(
      _findHeaderIndex(headers, ['quantity', 'qty', 'qnty', 'units']),
      2,
    );
    final unitCol = _fallbackIndex(
      _findHeaderIndex(headers, ['unit price', 'price', 'rate', 'unit cost']),
      3,
    );
    final totalCol = _fallbackIndex(
      _findHeaderIndex(headers, ['total', 'amount', 'line total']),
      4,
    );

    double subtotal = 0.0;
    for (var i = 1; i < cells.length; i++) {
      final row = cells[i];

      double rowTotal = 0.0;
      if (totalCol < row.length) {
        rowTotal = _parseFirstNumber(row[totalCol]) ?? 0.0;
      }

      if (rowTotal == 0.0) {
        final qty = qtyCol < row.length ? _parseQuantity(row[qtyCol]) : 0.0;
        final unit = unitCol < row.length
            ? (_parseFirstNumber(row[unitCol]) ?? 0.0)
            : 0.0;
        rowTotal = qty * unit;
      }

      subtotal += rowTotal;
    }

    return subtotal;
  }

  double getVAT() {
    return getSubtotal() * vatRate;
  }

  double getTotal() {
    return getSubtotal() + getVAT();
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'cells': cells,
        'vatRate': vatRate,
      };

  factory DocumentTable.fromJson(Map<String, dynamic> json) => DocumentTable(
        type: json['type'] as String? ?? 'text',
        cells: (json['cells'] as List<dynamic>?)
            ?.map((row) =>
                (row as List<dynamic>).map((cell) => cell.toString()).toList())
            .toList(),
        vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.15,
      );
}
