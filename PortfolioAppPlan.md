# Portfolio Fundamentals App Plan

## Product Direction

Build an App Store-quality SwiftUI app for iOS, iPadOS, and macOS that helps users understand the fundamentals, risk, and allocation behind their portfolio.

Initial scope:
- US-only securities
- Chase CSV import first
- Manual account and holding entry
- Manual 401(k) support
- Mutual funds
- Cash positions
- No options, crypto, or international securities in the first release

## API Key Strategy

For development, store the Finnhub key locally in `.env`.

For App Store distribution, do not embed a shared Finnhub key in the app bundle. A shipped app can be inspected, so any bundled key should be treated as public.

Preferred App Store approach:
- User-supplied API key. The app should ask each user to enter their own Finnhub API key during onboarding or in Settings.
- Store the key in Keychain, not SwiftData, UserDefaults, plain files, or source code.
- Validate the key immediately with a lightweight Finnhub request before enabling live market data features.
- Show clear setup guidance with a link to Finnhub's API key page.
- Allow the user to update, remove, or revalidate the key from Settings.

Possible later option:
- Add a backend proxy only if the app needs a more consumer-polished experience, shared paid data access, stronger caching, or usage controls.

## Finnhub Usage

Finnhub should be used for:
- Ticker validation through symbol lookup and supported stock symbols
- Current quote data
- Company profile
- Sector and industry metadata
- Basic financial metrics such as beta, valuation, dividend yield, and profitability metrics
- Fundamental statement data where available

Potential gap:
- Sharpe ratio, volatility, and correlation require historical return data. We need to confirm whether the current Finnhub key has access to the required historical candle endpoints or add a second historical price source.

## Portfolio Input Model

Accounts:
- Taxable brokerage
- Traditional IRA
- Roth IRA
- 401(k)
- HSA
- Cash/manual account

Holdings:
- Account
- Symbol
- Security name
- Asset class
- Quantity
- Current price
- Market value
- Cost basis
- Purchase date or lot date when available
- Security type: stock, ETF, mutual fund, cash
- Sector/industry when applicable

Import MVP:
- Chase CSV import
- Column mapping when the CSV format is ambiguous
- Validation preview before saving
- Manual correction for unmatched tickers
- Cash rows preserved as cash positions

### Chase Positions CSV Notes

The Chase positions export includes a wide position-level schema with enough data for the first portfolio analytics release.

Useful fields:
- `Asset Class`
- `Asset Strategy`
- `Description`
- `Ticker`
- `CUSIP`
- `ISIN`
- `Quantity`
- `Base CCY`
- `Price`
- `Pricing Date`
- `Value`
- `Cost`
- `Unit Cost`
- `Unrealized G/L Amt.`
- `Unrealized Gain/Loss (%)`
- `Acquisition Date`
- `Est. Annual Income`
- `Dividend Yield`
- `Amount invested`
- `7-day average yield`
- `Acct Type`
- `Accounting Method`

Importer behavior:
- Treat this as a position-level import, not guaranteed lot-level import.
- Stop parsing real holdings when `Asset Class` equals `FOOTNOTES`.
- Ignore trailing disclosure rows after the footnotes marker.
- Preserve Chase-provided asset class and strategy as imported metadata.
- Use `Ticker` first for market data lookup.
- Use `CUSIP` and `ISIN` as secondary identifiers for ambiguous or blank tickers.
- Preserve rows with blank tickers if they represent cash or money market positions.
- Parse numeric fields that may contain commas, currency formatting, blanks, or negative values.
- Parse Chase dates in `MM/dd/yyyy` and `MM/dd/yyyy HH:mm:ss` formats.
- Show a validation preview before import with row status: ready, needs ticker review, cash/manual, or ignored footnote.

Observed Chase quirks:
- The sample export has 71 columns.
- The file contains real positions followed by footnote/disclaimer rows.
- Some rows have blank tickers, CUSIPs, or ISINs.
- `Acct Type` may describe cash/accounting treatment rather than the user's named account, so the app should still ask which app account this CSV belongs to during import.

## Initial Analytics

Release 1 analytics:
- Total portfolio value
- Value by account
- Unrealized gain/loss
- Position concentration
- Asset class allocation
- Sector allocation
- Cash allocation
- Portfolio beta
- Dividend yield estimate

Release 2 analytics:
- Sharpe ratio
- Volatility
- Drawdown
- Correlation clustering
- Return attribution
- Benchmark comparison

## SwiftUI Architecture

Recommended architecture:
- SwiftUI shared app for iOS, iPadOS, and macOS
- SwiftData for local persistence
- Keychain for local secrets
- iCloud/CloudKit sync after local model stabilizes
- URLSession-based Finnhub client
- Import pipeline separated from portfolio analytics

Core modules:
- Accounts
- Holdings
- Imports
- MarketData
- Analytics
- Settings

## Open Questions

- Do Chase exports include lot-level purchase data in a separate export, or only this position-level cost basis file?
- Should mutual funds be valued from Finnhub when available, manually entered, or supported through a second data provider if Finnhub coverage is limited?
