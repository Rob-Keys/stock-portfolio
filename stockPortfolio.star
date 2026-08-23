"""
Applet: Stock Portfolio
Summary: Track the value of a stock portfolio
Description: Shows the current value and daily movement of up to five stock positions.
Author: Rob Keys
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

QUOTE_URL = "https://query2.finance.yahoo.com/v8/finance/chart/"
QUOTE_CACHE_SECONDS = 900
MAX_POSITIONS = 5

POSITIVE_COLOR = "#21f39a"
NEGATIVE_COLOR = "#ff5364"
MUTED_COLOR = "#8b9bb4"
WHITE = "#ffffff"


def is_valid_number(value):
    if value == None:
        return False

    value = str(value).strip()
    if value == "":
        return False

    decimal_count = 0
    for character in value.elems():
        if character == ".":
            decimal_count += 1
        elif character not in "0123456789":
            return False

    return decimal_count <= 1 and value != "."


def parse_shares(value):
    if not is_valid_number(value):
        return 0.0
    return float(str(value).strip())


def fetch_quote(symbol):
    response = http.get(
        QUOTE_URL + symbol,
        params = {
            "range": "2d",
            "interval": "1d",
            "events": "div,splits",
        },
        ttl_seconds = QUOTE_CACHE_SECONDS,
    )

    if response.status_code != 200:
        print("Quote request for %s failed with status %d" % (symbol, response.status_code))
        return None

    payload = response.json()
    chart = payload.get("chart", {})
    results = chart.get("result", [])
    if not results:
        print("No quote data returned for %s" % symbol)
        return None

    result = results[0]
    meta = result.get("meta", {})
    price = meta.get("regularMarketPrice")
    previous_close = meta.get("chartPreviousClose")

    # Some symbols do not include chartPreviousClose, so fall back to the
    # previous daily close in the chart response.
    quote_indicators = result.get("indicators", {}).get("quote", [])
    closes = []
    if quote_indicators:
        closes = quote_indicators[0].get("close", [])

    if price == None and closes:
        price = closes[len(closes) - 1]
    if previous_close == None and len(closes) > 1:
        previous_close = closes[len(closes) - 2]

    if price == None or previous_close == None or previous_close == 0:
        print("Incomplete quote data returned for %s" % symbol)
        return None

    change = float(price) - float(previous_close)
    return {
        "price": float(price),
        "change": change,
        "percent": (change / float(previous_close)) * 100,
    }


def format_compact_currency(amount):
    sign = "-" if amount < 0 else ""
    absolute = abs(amount)

    if absolute >= 1000000:
        return sign + "$" + ("%.1f" % (absolute / 1000000)) + "m"
    if absolute >= 1000:
        return sign + "$" + ("%.1f" % (absolute / 1000)) + "k"
    return sign + "$" + ("%.0f" % absolute)


def format_signed_currency(amount):
    if amount > 0:
        return "+" + format_compact_currency(amount)
    return format_compact_currency(amount)


def format_percent(percent):
    if percent > 0:
        return "+" + ("%.1f" % percent) + "%"
    return ("%.1f" % percent) + "%"


def summary_text(mode, value, change, percent):
    if mode == "change":
        return format_signed_currency(change)
    if mode == "percent":
        return format_percent(percent)
    if mode == "value_change":
        return format_compact_currency(value) + " " + format_signed_currency(change)
    if mode == "value_percent":
        return format_compact_currency(value) + " " + format_percent(percent)
    return format_compact_currency(value)


def message_view(message, detail = ""):
    children = [
        render.Text(message, font = "6x10", color = NEGATIVE_COLOR),
    ]
    if detail != "":
        children.append(render.Text(detail, font = "tom-thumb", color = MUTED_COLOR))

    return render.Root(
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = children,
        ),
    )


def main(config):
    mode = config.get("summary_mode", "value")
    positions = []

    for index in range(1, MAX_POSITIONS + 1):
        symbol_default = "AAPL" if index == 1 else ""
        shares_default = "1" if index == 1 else ""
        symbol = str(config.get("symbol_%d" % index, symbol_default)).strip().upper()
        shares = parse_shares(config.get("shares_%d" % index, shares_default))
        if symbol != "" and shares > 0:
            positions.append({
                "symbol": symbol,
                "shares": shares,
            })

    if not positions:
        return message_view("ADD A POSITION", "SET SYMBOL + SHARES")

    quote_cache = {}
    holdings = []
    failed_symbols = []

    for position in positions:
        symbol = position["symbol"]
        if symbol in quote_cache:
            quote = quote_cache[symbol]
        else:
            quote = fetch_quote(symbol)
            quote_cache[symbol] = quote

        if quote == None:
            failed_symbols.append(symbol)
            continue

        value = quote["price"] * position["shares"]
        change = quote["change"] * position["shares"]
        holdings.append({
            "symbol": symbol,
            "value": value,
            "change": change,
            "percent": quote["percent"],
        })

    if not holdings:
        return message_view("QUOTE ERROR", "CHECK SYMBOLS")

    total_value = 0.0
    total_change = 0.0
    ticker_parts = []
    for holding in holdings:
        total_value += holding["value"]
        total_change += holding["change"]
        ticker_parts.append(
            "%s %s %s" % (
                holding["symbol"],
                format_compact_currency(holding["value"]),
                format_percent(holding["percent"]),
            ),
        )

    previous_value = total_value - total_change
    total_percent = 0.0
    if previous_value != 0:
        total_percent = (total_change / previous_value) * 100

    summary_color = POSITIVE_COLOR if total_change >= 0 else NEGATIVE_COLOR
    ticker_text = " | ".join(ticker_parts)
    if failed_symbols:
        ticker_text += " | ERR " + ",".join(failed_symbols)

    return render.Root(
        child = render.Column(
            expanded = True,
            main_align = "space_around",
            cross_align = "center",
            children = [
                render.Row(
                    expanded = True,
                    main_align = "center",
                    cross_align = "center",
                    children = [
                        render.Text("PORT ", font = "tom-thumb", color = MUTED_COLOR),
                        render.Text(
                            summary_text(mode, total_value, total_change, total_percent),
                            font = "6x10",
                            color = summary_color,
                        ),
                    ],
                ),
                render.Marquee(
                    width = 64,
                    child = render.Text(ticker_text, font = "tom-thumb", color = WHITE),
                    offset_start = 8,
                    offset_end = 8,
                ),
            ],
        ),
    )


def get_schema():
    summary_options = [
        schema.Option(display = "Total value", value = "value"),
        schema.Option(display = "Dollar change", value = "change"),
        schema.Option(display = "Percent change", value = "percent"),
        schema.Option(display = "Value + dollar change", value = "value_change"),
        schema.Option(display = "Value + percent change", value = "value_percent"),
    ]

    fields = [
        schema.Dropdown(
            id = "summary_mode",
            name = "Portfolio summary",
            desc = "Choose what the main portfolio line displays",
            icon = "chartLine",
            default = "value",
            options = summary_options,
        ),
    ]

    for index in range(1, MAX_POSITIONS + 1):
        symbol_default = ""
        shares_default = ""
        if index == 1:
            symbol_default = "AAPL"
            shares_default = "1"

        fields.append(
            schema.Text(
                id = "symbol_%d" % index,
                name = "Position %d symbol" % index,
                desc = "Stock or ETF ticker, for example AAPL",
                icon = "tag",
                default = symbol_default,
            ),
        )
        fields.append(
            schema.Text(
                id = "shares_%d" % index,
                name = "Position %d shares" % index,
                desc = "Number of shares held; fractional shares are supported",
                icon = "hashtag",
                default = shares_default,
            ),
        )

    return schema.Schema(
        version = "1",
        fields = fields,
    )
