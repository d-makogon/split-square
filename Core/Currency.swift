import Foundation

enum CurrencyUtil {
    static let allCurrencyCodes: [String] = Locale.commonISOCurrencyCodes.sorted()

    static func minorUnits(for code: String) -> Int {
        switch code {
        case "JPY": return 0
        case "KWD", "BHD", "JOD", "IQD", "TND", "LYD", "OMR": return 3
        default: return 2
        }
    }
}

func rounded(_ value: Decimal, currencyCode: String) -> Decimal {
    var v = value
    var res = Decimal()
    NSDecimalRound(&res, &v, CurrencyUtil.minorUnits(for: currencyCode), .plain)
    return res
}
