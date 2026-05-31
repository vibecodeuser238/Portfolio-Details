import Foundation

struct ChaseCSVImporter {
    enum ImportError: LocalizedError {
        case unreadableFile
        case missingHeaders

        var errorDescription: String? {
            switch self {
            case .unreadableFile: "The CSV file could not be read."
            case .missingHeaders: "This does not look like a Chase positions CSV."
            }
        }
    }

    func preview(data: Data, account: PortfolioAccount) throws -> [ImportPreviewRow] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw ImportError.unreadableFile
        }
        let rows = parseCSV(text)
        guard let headers = rows.first, headers.contains("Asset Class"), headers.contains("Ticker") else {
            throw ImportError.missingHeaders
        }

        var previewRows: [ImportPreviewRow] = []
        for (index, columns) in rows.dropFirst().enumerated() {
            let rowNumber = index + 2
            let row = Dictionary(uniqueKeysWithValues: headers.enumerated().map { offset, header in
                (header, offset < columns.count ? columns[offset] : "")
            })
            let assetClass = row.value("Asset Class")
            if assetClass.uppercased() == "FOOTNOTES" {
                previewRows.append(ImportPreviewRow(rowNumber: rowNumber, status: .ignored, message: "Footnotes begin here. Later rows are ignored."))
                break
            }
            guard !assetClass.isEmpty || !row.value("Description").isEmpty || !row.value("Ticker").isEmpty else {
                continue
            }

            let holding = Holding(
                accountID: account.id,
                symbol: normalizeSymbol(row.value("Ticker")),
                description: row.value("Description"),
                cusip: row.optional("CUSIP"),
                isin: row.optional("ISIN"),
                assetClass: assetClass,
                assetStrategy: row.value("Asset Strategy"),
                securityType: securityType(assetClass: assetClass, description: row.value("Description"), symbol: row.value("Ticker")),
                quantity: decimal(row.value("Quantity")),
                price: decimal(row.value("Price")),
                marketValue: decimal(row.value("Value")),
                costBasis: decimal(row.value("Cost")),
                unrealizedGainLoss: decimal(row.value("Unrealized G/L Amt.")),
                dividendYield: decimalOptional(row.value("Dividend Yield")),
                estimatedAnnualIncome: decimalOptional(row.value("Est. Annual Income")),
                pricingDate: date(row.value("Pricing Date")),
                acquisitionDate: date(row.value("Acquisition Date"))
            )

            let status: ImportPreviewRow.Status
            let message: String
            if holding.securityType == .cash || holding.securityType == .moneyMarket {
                status = .cashOrManual
                message = "Imported as cash or money market."
            } else if holding.symbol.isEmpty {
                status = .needsReview
                message = "Missing ticker. CUSIP or ISIN may be needed."
            } else {
                status = .ready
                message = "Ready to import."
            }

            previewRows.append(ImportPreviewRow(rowNumber: rowNumber, status: status, holding: holding, message: message))
        }
        return previewRows
    }

    private func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if insideQuotes, let next = iterator.next() {
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        insideQuotes = false
                        if next == "," {
                            row.append(field)
                            field = ""
                        } else if next == "\n" {
                            row.append(field)
                            rows.append(row)
                            row = []
                            field = ""
                        } else if next != "\r" {
                            field.append(next)
                        }
                    }
                } else {
                    insideQuotes.toggle()
                }
            } else if character == ",", !insideQuotes {
                row.append(field)
                field = ""
            } else if character == "\n", !insideQuotes {
                row.append(field.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows.map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
    }

    private func decimal(_ value: String) -> Decimal {
        decimalOptional(value) ?? 0
    }

    private func decimalOptional(_ value: String) -> Decimal? {
        var clean = value
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        var isNegative = false
        if clean.hasPrefix("("), clean.hasSuffix(")") {
            isNegative = true
            clean.removeFirst()
            clean.removeLast()
        }
        guard var decimal = Decimal(string: clean) else { return nil }
        if isNegative { decimal *= -1 }
        return decimal
    }

    private func date(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["MM/dd/yyyy HH:mm:ss", "MM/dd/yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private func normalizeSymbol(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func securityType(assetClass: String, description: String, symbol: String) -> SecurityType {
        let combined = "\(assetClass) \(description) \(symbol)".lowercased()
        if combined.contains("cash") { return .cash }
        if combined.contains("money market") { return .moneyMarket }
        if combined.contains("mutual") || symbol.count == 5 && symbol.hasSuffix("X") { return .mutualFund }
        if combined.contains("etf") || combined.contains("exchange traded") { return .etf }
        if combined.contains("equity") { return .stock }
        return .unknown
    }
}

private extension Dictionary where Key == String, Value == String {
    func value(_ key: String) -> String {
        self[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func optional(_ key: String) -> String? {
        let value = value(key)
        return value.isEmpty ? nil : value
    }
}

