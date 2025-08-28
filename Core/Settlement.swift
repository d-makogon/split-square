import Foundation

struct TransferSuggestion: Identifiable, Hashable {
    var id: String { from + "->" + to + ":\(amount)" }
    let from: ID
    let to: ID
    let amount: Decimal
}

func computeBalances(
    groupCurrency: String,
    members: [Member],
    expenses: [Expense],
    payments: [Payment]
) -> [ID: Decimal] {
    var bal = Dictionary(uniqueKeysWithValues: members.map { ($0.id, Decimal.zero) })

    for e in expenses {
        let total = e.amountInGroupCurrency
        bal[e.payerId, default: .zero] += total

        switch e.splitMode {
        case .equal:
            let ids = e.includedMemberIds
            guard !ids.isEmpty else { continue }
            let shareRaw = total / Decimal(ids.count)
            let share = rounded(shareRaw, currencyCode: groupCurrency)
            for id in ids { bal[id, default: .zero] -= share }
        case .manual:
            guard let shares = e.manualShares else { continue }
            for (id, v) in shares {
                bal[id, default: .zero] -= rounded(v, currencyCode: groupCurrency)
            }
        }
    }

    for p in payments {
        let total = p.amountInGroupCurrency
        bal[p.recipientId, default: .zero] += total
        for (payerId, amt) in p.contributions {
            bal[payerId, default: .zero] -= rounded(amt, currencyCode: groupCurrency)
        }
    }
    for (k, v) in bal {
        let r = rounded(v, currencyCode: groupCurrency)
        bal[k] = r == 0 ? 0 : r
    }
    return bal
}

func minimizeTransfers(balances: [ID: Decimal], currencyCode: String) -> [TransferSuggestion] {
    var debtors: [(ID, Decimal)] = []
    var creditors: [(ID, Decimal)] = []
    for (id, bal) in balances {
        if bal < 0 { debtors.append((id, -bal)) }
        else if bal > 0 { creditors.append((id, bal)) }
    }
    debtors.sort { $0.1 > $1.1 }
    creditors.sort { $0.1 > $1.1 }

    var i = 0, j = 0
    var res: [TransferSuggestion] = []

    while i < debtors.count && j < creditors.count {
        let (debtor, dAmt) = debtors[i]
        let (creditor, cAmt) = creditors[j]
        let x = min(dAmt, cAmt)
        let xr = rounded(x, currencyCode: currencyCode)
        if xr > 0 {
            res.append(.init(from: debtor, to: creditor, amount: xr))
        }
        let nd = dAmt - xr
        let nc = cAmt - xr
        if nd <= 0 { i += 1 } else { debtors[i].1 = nd }
        if nc <= 0 { j += 1 } else { creditors[j].1 = nc }
    }
    return res
}
