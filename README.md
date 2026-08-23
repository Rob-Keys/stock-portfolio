# Stock Portfolio

Stock Portfolio is a Tidbyt applet for tracking the market value and daily movement of real stock and ETF positions.

Configure up to five positions with a ticker symbol and the number of shares held. The app calculates a share-weighted portfolio total and shows a scrolling ticker for each holding with its current position value and daily percentage move.

The main portfolio line can be configured to show:

- Total value
- Dollar change
- Percent change
- Total value and dollar change
- Total value and percent change

Quotes are retrieved from Yahoo Finance's chart endpoint and cached for 15 minutes. No API key is required. The app uses the current market quote when available, with the previous close as the comparison point.

The change figures are daily market movement versus the previous close; they are not unrealized gain or loss versus your purchase price.

## Configuration

Enter a symbol such as `AAPL`, `MSFT`, or `VOO` and the number of shares held for each position. Leave unused position fields blank. Fractional shares are supported.
