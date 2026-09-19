import concurrent.futures
import datetime
import json
import pathlib
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).parent
BASE = 'https://data-api.binance.vision'
CHECKS = [
    ('catalog', '/api/v3/exchangeInfo', {'permissions': 'SPOT', 'symbolStatus': 'TRADING', 'showPermissionSets': 'false'}),
    ('tickers', '/api/v3/ticker/24hr', {'symbols': json.dumps(['BTCUSDT', 'ETHUSDT', 'SOLUSDT'], separators=(',', ':'))}),
    ('btc_1h', '/api/v3/klines', {'symbol': 'BTCUSDT', 'interval': '1m', 'limit': 61}),
    ('eth_24h', '/api/v3/klines', {'symbol': 'ETHUSDT', 'interval': '5m', 'limit': 289}),
    ('sol_7d', '/api/v3/klines', {'symbol': 'SOLUSDT', 'interval': '1h', 'limit': 169}),
    ('invalid_symbol', '/api/v3/klines', {'symbol': 'NOT_A_SYMBOL', 'interval': '1m', 'limit': 1}),
]

def probe(item):
    name, path, params = item
    url = BASE + path + '?' + urllib.parse.urlencode(params)
    result = {'check': name, 'url': url, 'checked_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    try:
        request = urllib.request.Request(url, headers={'User-Agent': 'DockMagic-Research/1.0', 'Accept': 'application/json'})
        with urllib.request.urlopen(request, timeout=25) as response:
            payload = json.load(response)
            result['http_status'] = response.status
            result['weight_headers'] = {k: v for k, v in response.headers.items() if k.lower().startswith('x-mbx-used-weight')}
        (ROOT / (name + '.json')).write_text(json.dumps(payload, ensure_ascii=False, indent=2))
        if name == 'catalog':
            symbols = payload['symbols']
            result.update({
                'symbols_count': len(symbols),
                'usdt_symbols_count': sum(s['quoteAsset'] == 'USDT' for s in symbols),
                'rate_limits': payload['rateLimits'],
                'btc_metadata': next((s for s in symbols if s['symbol'] == 'BTCUSDT'), None),
            })
        elif name == 'tickers':
            result['symbols'] = [p['symbol'] for p in payload]
            result['fields'] = list(payload[0])
        else:
            times = [p[0] for p in payload]
            result.update({
                'count': len(payload), 'row_width': len(payload[0]),
                'first_open_time': times[0], 'last_open_time': times[-1],
                'unique_sorted': times == sorted(set(times)),
                'first_row': payload[0], 'last_row': payload[-1],
                'ohlc_valid': all(float(p[3]) <= min(float(p[1]), float(p[4])) <= max(float(p[1]), float(p[4])) <= float(p[2]) for p in payload),
            })
    except urllib.error.HTTPError as error:
        result.update({'http_status': error.code, 'error_body': error.read(1000).decode(errors='replace')})
    except Exception as error:
        result['error'] = str(error)
    return result

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    results = list(pool.map(probe, CHECKS))
(ROOT / 'rest-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
for result in results:
    print(json.dumps({k: v for k, v in result.items() if k not in ['btc_metadata', 'first_row', 'last_row']}, ensure_ascii=False))
